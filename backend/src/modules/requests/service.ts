import pg from 'pg';
import { Db, dbPool, withTransaction } from '../../database/index.js';
import { HAS_OPEN_ORDER, notify } from '../lifecycle/service.js';
import { publishChange } from '../../services/liveUpdates.js';

/// Each call lasts one minute, then the next call goes out by itself, even when offers already came (owner decision 2026-11-09)
export const ROUND_SECONDS = 60;
/// After the calls end with offers in hand, the client has this long to choose before the request is cancelled
export const CHOOSE_MINUTES = 5;
const LAWYERS_PER_ROUND = 10;
/// The three calls reach further each time: up to 10 km, then 25, then 50. At most 30 lawyers get one request
const ROUND_RADII_KM = [10, 25, 50];
export const AUTO_ROUNDS = ROUND_RADII_KM.length;
/// The service and its map reach this far from the client
export const SEARCH_RADIUS_KM = ROUND_RADII_KM[ROUND_RADII_KM.length - 1];
const KM_PER_DEGREE = 111.32;

/// When the automatic calls end. After «بحث جديد» past the third call it is the current call's end
export function callsEnd(request: any): Date {
  const left = Math.max(0, AUTO_ROUNDS - Number(request.round));
  return new Date(new Date(request.round_deadline).getTime() + left * ROUND_SECONDS * 1000);
}

/// When the client must have chosen, counted from the end of the calls
export function chooseEnd(request: any): Date {
  return new Date(callsEnd(request).getTime() + CHOOSE_MINUTES * 60000);
}

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

/// Sends the request to the nearest 10 not asked yet inside this call's distance, and returns how many got it.
/// With [again], when nobody new is left, the nearest 10 who have not sent a price are asked once more («بحث جديد»).
/// A lawyer whose price is already with the client is never asked again.
export async function sendRound(db: Db, request: any, round: number, again = false): Promise<number> {
  const radius = ROUND_RADII_KM[Math.min(round, AUTO_ROUNDS) - 1];
  const lat = Number(request.client_latitude);
  const lon = Number(request.client_longitude);
  // A box around the client first, so the distance is worked out only for lawyers who could be inside the circle
  const latSpan = radius / KM_PER_DEGREE;
  const lonSpan = radius / (KM_PER_DEGREE * Math.cos((lat * Math.PI) / 180));
  const pick = (skipAsked: boolean) => db.query(
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
         ${skipAsked ? 'AND NOT EXISTS (SELECT 1 FROM request_recipients rr WHERE rr.request_id = $3 AND rr.lawyer_id = u.id)' : ''}
     ) nearest
     WHERE distance_km <= $6::float8
     ORDER BY distance_km ASC
     LIMIT ${LAWYERS_PER_ROUND}`,
    [lat, lon, request.id, latSpan, lonSpan, radius]
  );
  let res = await pick(true);
  if (res.rows.length === 0 && again) res = await pick(false);

  for (const lawyer of res.rows) {
    // Asked again later, the lawyer sees the request as new
    await db.query(
      `INSERT INTO request_recipients (request_id, lawyer_id, round, distance_km) VALUES ($1, $2, $3, $4)
       ON CONFLICT (request_id, lawyer_id) DO UPDATE SET round = EXCLUDED.round, distance_km = EXCLUDED.distance_km`,
      [request.id, lawyer.id, round, lawyer.distance_km]
    );
    await notify(db, lawyer.id, 'طلب جديد', `${request.problem_type || request.service_title}. ابعت سعرك دلوقتي`, { requestId: request.id });
  }
  return res.rows.length;
}

/// The next automatic call that finds lawyers. A call with nobody new inside its distance is skipped right away.
/// Returns the call number, or 0 when no lawyer is left inside 50 km.
export async function sendNextCall(db: Db, request: any, from: number): Promise<number> {
  for (let round = from; round <= AUTO_ROUNDS; round++) {
    if (await sendRound(db, request, round) > 0) return round;
  }
  return 0;
}

async function closeRequest(db: pg.PoolClient, request: any, status: string, title: string, body: string) {
  await db.query('UPDATE service_requests SET status = $1 WHERE id = $2', [status, request.id]);
  await notify(db, request.client_id, title, body, { requestId: request.id });
}

/// Every minute the next call goes out, offers or not. After the calls a request with no offers closes,
/// and one with offers waits 5 minutes for the client to choose
export async function advanceRequests() {
  const due = await dbPool.query(`SELECT id FROM service_requests WHERE status = 'OPEN' AND round_deadline <= NOW()`);

  for (const { id } of due.rows) {
    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT * FROM service_requests WHERE id = $1 AND status = 'OPEN' AND round_deadline <= NOW() FOR UPDATE`, [id]);
      const request = locked.rows[0];
      if (!request) return;

      if (request.round < AUTO_ROUNDS) {
        const next = await sendNextCall(client, request, request.round + 1);
        if (next > 0) {
          await client.query(
            `UPDATE service_requests SET round = $1, round_deadline = NOW() + make_interval(secs => $2) WHERE id = $3`,
            [next, ROUND_SECONDS, id]
          );
          return;
        }
        // Nobody else inside 50 km: the calls end now, and the 5 minutes to choose start from here
        await client.query(`UPDATE service_requests SET round = $1, round_deadline = NOW() WHERE id = $2`, [AUTO_ROUNDS, id]);
        request.round = AUTO_ROUNDS;
        request.round_deadline = new Date();
      }

      const live = await client.query(`SELECT 1 ${LIVE_OFFERS} AND ro.request_id = $1 LIMIT 1`, [id]);
      if (live.rows.length > 0) {
        if (chooseEnd(request).getTime() > Date.now()) return;
        await closeRequest(client, request, 'EXPIRED', 'الطلب اتلغى', 'ما اخترتش عرض في الوقت المحدد. تقدر تطلب تاني');
        const offered = await client.query('SELECT lawyer_id FROM request_offers WHERE request_id = $1 AND withdrawn_at IS NULL', [id]);
        for (const row of offered.rows) await publishChange(client, row.lawyer_id, false, 'requests', id);
        return;
      }

      // No offers after the calls: the request closes right away, so nothing waits on the server.
      // The app keeps «بحث جديد», which sends a new request to the nearest lawyers
      await closeRequest(client, request, 'NO_OFFERS', 'محدش بعت عرض', 'مفيش محامي قريب منك دلوقتي، جرّب بعد شوية أو دوس «بحث جديد»');
      const asked = await client.query('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id]);
      for (const row of asked.rows) await publishChange(client, row.lawyer_id, false, 'requests', id);
    });
  }
}

/// A chosen order that was not paid goes away and the client is back on the same offers for 5 minutes.
/// [taken]: the lawyer was paid for by someone else first, so their offer leaves the list too
export async function releaseChoice(db: Db, order: { id: string; client_id: string; lawyer_id: string }, taken: boolean) {
  const note = taken ? 'المحامي اتشغل في طلب تاني قبل الدفع' : 'انتهت مهلة الدفع دون دفع';
  await db.query(`UPDATE service_orders SET status = 'PAYMENT_EXPIRED', updated_at = NOW() WHERE id = $1 AND status = 'ACCEPTED'`, [order.id]);
  await db.query(
    `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note) VALUES ($1, NULL, 'ACCEPTED', 'PAYMENT_EXPIRED', $2)`,
    [order.id, note]
  );
  const reopened = await db.query(
    `UPDATE service_requests SET status = 'OPEN', order_id = NULL, round = $2, round_deadline = NOW()
     WHERE order_id = $1 RETURNING id`,
    [order.id, AUTO_ROUNDS]
  );
  const requestId = reopened.rows[0]?.id as string | undefined;
  if (requestId && taken) {
    await db.query('UPDATE request_offers SET withdrawn_at = NOW() WHERE request_id = $1 AND lawyer_id = $2', [requestId, order.lawyer_id]);
  }
  if (requestId) {
    await notify(db, order.client_id, taken ? 'المحامي اتشغل' : 'انتهت مهلة الدفع', 'اختار محامي تاني من العروض اللي قدامك', { requestId });
  } else {
    await notify(db, order.client_id, 'انتهت مهلة الدفع', 'الطلب اتلغى، وتقدر تبدأ طلب جديد', order.id);
  }
  await publishChange(db, order.lawyer_id, false, 'orders', order.id);
  return requestId;
}
