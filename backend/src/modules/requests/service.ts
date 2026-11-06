import pg from 'pg';
import { Db, dbPool, withTransaction } from '../../database/index.js';
import { HAS_OPEN_ORDER, notify } from '../lifecycle/service.js';
import { publishChange } from '../../services/liveUpdates.js';

export const ROUND_SECONDS = 120;
/// After the offers round, the client has this long to choose before the request is cancelled
export const CHOOSE_MINUTES = 5;
const LAWYERS_PER_ROUND = 10;
/// Rounds that move by themselves when nobody offers: the nearest 10, then the 10 after them.
/// After that the client presses «بحث جديد», which goes back to the nearest 10, and so on (owner decision 2026-11-06)
const AUTO_ROUNDS = 2;
/// The service and its map reach this far from the client
export const SEARCH_RADIUS_KM = 50;
const KM_PER_DEGREE = 111.32;

/// A lawyer who can take new work right now
export const LAWYER_CAN_WORK = (profile: string, user: string) => `
  ${profile}.approval_status = 'approved' AND ${user}.status = 'active' AND ${profile}.is_available = TRUE
  AND ${profile}.suspended_until IS NULL AND ${profile}.urgent_status = 'APPROVED'
  AND NOT ${HAS_OPEN_ORDER('lawyer_id', `${user}.id`)}`;

/// The offers a client can still choose from
export const LIVE_OFFERS = `
  FROM request_offers ro
  JOIN users u ON u.id = ro.lawyer_id
  JOIN lawyer_profiles lp ON lp.user_id = ro.lawyer_id
  WHERE ro.withdrawn_at IS NULL AND ${LAWYER_CAN_WORK('lp', 'u')}`;

export interface PriceRange {
  problemType: string;
  minPrice: number;
  maxPrice: number;
  commissionPercent: number;
  taxPercent: number;
}

/// The limits the owner sets in the control page for each problem
export async function priceRangeFor(db: Db, problemType: string | null): Promise<PriceRange> {
  const fallback = 'مشكلة قانونية أخرى';
  const res = await db.query(
    `SELECT problem_type, min_price, max_price, commission_percent FROM problem_prices
     WHERE problem_type = $1 OR problem_type = $2
     ORDER BY problem_type = $1 DESC LIMIT 1`,
    [problemType ?? fallback, fallback]
  );
  if (res.rows.length === 0) throw new Error('No price range is configured');
  const settings = await db.query('SELECT tax_percent FROM platform_settings LIMIT 1');
  const row = res.rows[0];
  return {
    problemType: row.problem_type,
    minPrice: Number(row.min_price),
    maxPrice: Number(row.max_price),
    commissionPercent: Number(row.commission_percent),
    taxPercent: Number(settings.rows[0]?.tax_percent ?? 0),
  };
}

/// Sends the request to one group of lawyers within 50 km, and returns how many got it.
/// Odd rounds go to the nearest 10 right now, even rounds to the 10 after them.
/// A lawyer whose price is already with the client is not asked again.
export async function sendRound(db: Db, request: any, round: number): Promise<number> {
  const lat = Number(request.client_latitude);
  const lon = Number(request.client_longitude);
  // A box around the client first, so the distance is worked out only for lawyers who could be inside 50 km
  const latSpan = SEARCH_RADIUS_KM / KM_PER_DEGREE;
  const lonSpan = SEARCH_RADIUS_KM / (KM_PER_DEGREE * Math.cos((lat * Math.PI) / 180));
  const res = await db.query(
    `SELECT id, distance_km FROM (
       SELECT u.id, 6371.0 * acos(least(1.0::float8, greatest(-1.0::float8,
         cos(radians($1::float8)) * cos(radians(lp.latitude::float8)) *
         cos(radians(lp.longitude::float8) - radians($2::float8)) +
         sin(radians($1::float8)) * sin(radians(lp.latitude::float8))))) AS distance_km
       FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id
       WHERE ${LAWYER_CAN_WORK('lp', 'u')} AND lp.latitude IS NOT NULL AND lp.longitude IS NOT NULL
         AND lp.latitude BETWEEN $1::float8 - $4::float8 AND $1::float8 + $4::float8
         AND lp.longitude BETWEEN $2::float8 - $5::float8 AND $2::float8 + $5::float8
         AND NOT EXISTS (SELECT 1 FROM request_offers ro WHERE ro.request_id = $3 AND ro.lawyer_id = u.id AND ro.withdrawn_at IS NULL)
     ) nearest
     WHERE distance_km <= $6::float8
     ORDER BY distance_km ASC
     OFFSET $7 LIMIT ${LAWYERS_PER_ROUND}`,
    [lat, lon, request.id, latSpan, lonSpan, SEARCH_RADIUS_KM, round % 2 === 1 ? 0 : LAWYERS_PER_ROUND]
  );

  for (const lawyer of res.rows) {
    // Asked again in a later round, the lawyer sees the request as new
    await db.query(
      `INSERT INTO request_recipients (request_id, lawyer_id, round, distance_km) VALUES ($1, $2, $3, $4)
       ON CONFLICT (request_id, lawyer_id) DO UPDATE SET round = EXCLUDED.round, distance_km = EXCLUDED.distance_km`,
      [request.id, lawyer.id, round, lawyer.distance_km]
    );
    await notify(db, lawyer.id, 'طلب جديد', `${request.problem_type || request.service_title}. ابعت سعرك خلال دقيقتين`, { requestId: request.id });
  }
  return res.rows.length;
}

async function closeRequest(db: pg.PoolClient, request: any, status: string, title: string, body: string) {
  await db.query('UPDATE service_requests SET status = $1 WHERE id = $2', [status, request.id]);
  await notify(db, request.client_id, title, body, { requestId: request.id });
}

/// A round with no offers moves to the next lawyers, and a request nobody chose closes by itself
export async function advanceRequests() {
  const due = await dbPool.query(`SELECT id FROM service_requests WHERE status = 'OPEN' AND round_deadline <= NOW()`);

  for (const { id } of due.rows) {
    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT * FROM service_requests WHERE id = $1 AND status = 'OPEN' AND round_deadline <= NOW() FOR UPDATE`, [id]);
      const request = locked.rows[0];
      if (!request) return;

      const live = await client.query(`SELECT 1 ${LIVE_OFFERS} AND ro.request_id = $1 LIMIT 1`, [id]);
      if (live.rows.length > 0) {
        const left = await client.query(`SELECT $1::timestamptz + make_interval(mins => $2) > NOW() AS waiting`, [request.round_deadline, CHOOSE_MINUTES]);
        if (!left.rows[0].waiting) {
          await closeRequest(client, request, 'EXPIRED', 'الطلب اتلغى', 'ما اخترتش عرض في الوقت المحدد. تقدر تطلب تاني');
          const offered = await client.query('SELECT lawyer_id FROM request_offers WHERE request_id = $1 AND withdrawn_at IS NULL', [id]);
          for (const row of offered.rows) await publishChange(client, row.lawyer_id, false, 'requests', id);
        }
        return;
      }

      const nextRound = request.round + 1;
      const sent = nextRound <= AUTO_ROUNDS ? await sendRound(client, request, nextRound) : 0;
      if (sent === 0) {
        // Nobody offered after the automatic rounds: the request closes right away, so nothing waits on the server.
        // The app keeps «بحث جديد», which sends a new request to the nearest 10 (owner decision 2026-11-06)
        await closeRequest(client, request, 'NO_OFFERS', 'محدش بعت عرض', 'دوس «بحث جديد» ونبعت طلبك لمحامين تانيين');
        return;
      }
      await client.query(
        `UPDATE service_requests SET round = $1, round_deadline = NOW() + make_interval(secs => $2) WHERE id = $3`,
        [nextRound, ROUND_SECONDS, id]
      );
    });
  }
}
