import crypto from 'crypto';
import { Db } from '../../database/index.js';
import { sendPush } from '../../services/pushService.js';
import { publishChange } from '../../services/liveUpdates.js';
import { roadRoute } from '../../services/roadRoutes.js';

export const HOLD_HOURS = 24;
export const ORDER_DEADLINE_HOURS = 24;
export const REVIEW_WINDOW_DAYS = 7;
export const LAWYER_RESPONSE_SECONDS = 120;
/// Choosing an offer does not hold the lawyer: whoever finishes first gets them. The client has 3 minutes to pay
/// (owner decision 2026-11-09)
export const PAYMENT_MINUTES = 3;
/// The lawyer and the client must really meet, so arrival is accepted within 50 meters only
export const ARRIVAL_RADIUS_KM = 0.05;
/// Each side shares its newest point at most this often on the way to the meeting
export const LIVE_POSITION_SECONDS = 4;
export const ARRIVAL_REMINDER_MINUTES = 5;
/// A client who does not answer «wait or cancel» gets the money back after this (owner decision 2026-11-06)
export const CLIENT_REPLY_MINUTES = 5;
/// The margin on top of the road time grows with the trip: 10 minutes up to a 20 minute road, 15 up to an hour,
/// 20 beyond. The road time already has live traffic, so the margin is for parking and finding the door (2026-11-09)
export function arrivalMargin(roadMinutes: number): number {
  return roadMinutes <= 20 ? 10 : roadMinutes <= 60 ? 15 : 20;
}
const FALLBACK_TRAVEL_MINUTES = 60;
const ROAD_FACTOR = 1.4;
const FALLBACK_SPEED_KMH = 30;
const APPROXIMATE_GRID_DEGREES = 0.01;
const STRIKE_LIMIT = 3;
const STRIKE_WINDOW_DAYS = 30;
const SUSPENSION_DAYS = 7;
const FALLBACK_PROBLEM = 'مشكلة قانونية أخرى';

/// Exact places stay private until payment, so public positions move to a coarse grid
export function approximateCoordinate(value: number): number {
  return Math.round(value / APPROXIMATE_GRID_DEGREES) * APPROXIMATE_GRID_DEGREES;
}

/// What a notification opens when tapped: an order, a ticket, or nothing
export interface NotifyLink {
  orderId?: string;
  ticketId?: string;
  requestId?: string;
  consultationId?: string;
}

/// Worth knowing, but nothing to do right now: it stays inside the app, with no sound and no device notification
const QUIET_TITLES = new Set([
  'تسوية الطلب', 'المحامي أجّل المهمة', 'قيّم المحامي', 'تم التحويل', 'أتعابك جاهزة', 'تقييم جديد',
  'الموكل مستنيك', 'أتعابك اتجمدت', 'مراجعة على طلب', 'نتيجة بلاغك', 'اتلغى إنذار',
]);

export async function notify(db: Db, userId: string, title: string, body: string, link?: string | NotifyLink) {
  const { orderId, ticketId, requestId, consultationId } = typeof link === 'string'
    ? { orderId: link, ticketId: undefined, requestId: undefined, consultationId: undefined }
    : (link ?? {});
  // One line per order or request: the newest step replaces the older ones
  if (orderId || requestId) {
    await db.query(
      `DELETE FROM notifications WHERE user_id = $1
         AND (($2::uuid IS NOT NULL AND order_id = $2::uuid) OR ($3::uuid IS NOT NULL AND request_id = $3::uuid))`,
      [userId, orderId ?? null, requestId ?? null]
    );
  }
  await db.query(
    'INSERT INTO notifications (user_id, title, body, order_id, ticket_id, request_id, consultation_id) VALUES ($1, $2, $3, $4, $5, $6, $7)',
    [userId, title, body, orderId ?? null, ticketId ?? null, requestId ?? null, consultationId ?? null]
  );
  const quiet = QUIET_TITLES.has(title);

  // A request to act goes away once the order has moved past it
  if (orderId) {
    await db.query(
      `DELETE FROM notifications n USING service_orders o
       WHERE n.order_id = $1 AND o.id = n.order_id AND (
         (n.title = 'طلب جديد' AND o.status <> 'PENDING')
         OR (n.title = 'المحامي وافق' AND o.status <> 'ACCEPTED')
         OR (n.title = 'الموكل دفع' AND (o.status <> 'ACTIVE' OR o.arrived_at IS NOT NULL))
       )`,
      [orderId]
    );
  }

  await publishChange(
    db, userId, !quiet,
    orderId ? 'orders' : requestId ? 'requests' : ticketId ? 'support' : consultationId ? 'consultations' : 'notifications',
    orderId ?? requestId ?? ticketId ?? consultationId ?? null
  );

  // The order never waits for the phone
  if (!quiet) void sendPush(userId, title, body, { orderId, ticketId, requestId, consultationId });
}

export async function addClientCredit(db: Db, clientId: string, orderId: string, amount: number, reason: string) {
  await db.query(
    'INSERT INTO client_credits (client_id, order_id, amount, reason) VALUES ($1, $2, $3, $4)',
    [clientId, orderId, amount, reason]
  );
}

export interface ClientQuote {
  price: number;
  commissionPercent: number;
  taxPercent: number;
  lawyerAmount: number;
}

/// The price includes tax, and the platform share comes from what remains after it
export function lawyerShare(amount: number, commissionPercent: number, taxPercent = 0): number {
  const afterTax = amount * (100 - taxPercent) / 100;
  return Math.round(afterTax * (100 - commissionPercent)) / 100;
}

/// Picks a random whole price inside the problem's range and keeps it for this client.
/// A stored price stays while it is inside the range, otherwise a new one is picked.
export async function resolveClientQuote(db: Db, clientId: string, problemType: string | null): Promise<ClientQuote> {
  const rangeRes = await db.query(
    `SELECT problem_type, min_price, max_price, commission_percent FROM problem_prices
     WHERE problem_type = $1 OR problem_type = $2
     ORDER BY problem_type = $1 DESC LIMIT 1`,
    [problemType ?? FALLBACK_PROBLEM, FALLBACK_PROBLEM]
  );

  if (rangeRes.rows.length === 0) {
    throw new Error('No price range is configured');
  }

  const range = rangeRes.rows[0];
  const min = Number(range.min_price);
  const max = Number(range.max_price);
  const commissionPercent = Number(range.commission_percent);
  const settingsRes = await db.query('SELECT tax_percent FROM platform_settings LIMIT 1');
  const taxPercent = Number(settingsRes.rows[0]?.tax_percent ?? 0);
  const quote = (price: number) => ({
    price,
    commissionPercent,
    taxPercent,
    lawyerAmount: lawyerShare(price, commissionPercent, taxPercent),
  });

  const storedRes = await db.query(
    'SELECT price FROM client_problem_prices WHERE client_id = $1 AND problem_type = $2',
    [clientId, range.problem_type]
  );

  if (storedRes.rows.length > 0) {
    const stored = Number(storedRes.rows[0].price);
    if (stored >= min && stored <= max) return quote(stored);
  }

  const low = Math.ceil(min);
  const high = Math.floor(max);
  const price = high >= low ? crypto.randomInt(low, high + 1) : min;

  await db.query(
    `INSERT INTO client_problem_prices (client_id, problem_type, price) VALUES ($1, $2, $3)
     ON CONFLICT (client_id, problem_type) DO UPDATE SET price = EXCLUDED.price, created_at = NOW()`,
    [clientId, range.problem_type, price]
  );

  return quote(price);
}

/// Road time with live traffic plus the margin. A routing failure must never stop a payment, so it falls back to an estimate.
export async function arrivalMinutes(from: { lat: number; lon: number } | null, to: { lat: number; lon: number }): Promise<number> {
  if (!from) return FALLBACK_TRAVEL_MINUTES + arrivalMargin(FALLBACK_TRAVEL_MINUTES);
  const road = await roadRoute(from, to);
  if (road) {
    const minutes = Math.ceil(road.durationSeconds / 60);
    return minutes + arrivalMargin(minutes);
  }
  const latKm = (to.lat - from.lat) * 111;
  const lonKm = (to.lon - from.lon) * 111 * Math.cos((from.lat * Math.PI) / 180);
  const roadKm = Math.hypot(latKm, lonKm) * ROAD_FACTOR;
  const minutes = Math.ceil((roadKm / FALLBACK_SPEED_KMH) * 60);
  return minutes + arrivalMargin(minutes);
}

/// SQL condition on one order row: waiting, unpaid, or in progress. A postponed task leaves both sides free.
/// The one place that says what an open order is, for the lawyer and the client alike.
export const IS_OPEN_ORDER = (order: string) =>
  `${order}.status IN ('PENDING', 'ACCEPTED', 'ACTIVE') AND ${order}.postponed_at IS NULL`;

/// SQL condition on one order row: the lawyer is taken by it. A chosen but unpaid order does not hold the lawyer
export const HOLDS_LAWYER = (order: string) =>
  `${order}.status IN ('PENDING', 'ACTIVE') AND ${order}.postponed_at IS NULL`;

/// SQL condition: this person has an open order, as the lawyer (paid or waiting for their answer) or as the client
export const HAS_OPEN_ORDER = (side: 'lawyer_id' | 'client_id', person: string) =>
  `EXISTS (SELECT 1 FROM service_orders busy WHERE busy.${side} = ${person} AND ${side === 'lawyer_id' ? HOLDS_LAWYER('busy') : IS_OPEN_ORDER('busy')})`;

/// True while the lawyer has an open order, other than the one given
export async function lawyerHasOpenOrder(db: Db, lawyerId: string, exceptOrderId?: string): Promise<boolean> {
  const res = await db.query(
    `SELECT 1 FROM service_orders o
     WHERE o.lawyer_id = $1 AND ${HOLDS_LAWYER('o')}
       AND ($2::uuid IS NULL OR o.id <> $2::uuid)
     LIMIT 1`,
    [lawyerId, exceptOrderId ?? null]
  );
  return res.rows.length > 0;
}

const STRIKE_LABELS: Record<string, string> = { WITHDRAWAL: 'اعتذار بعد الدفع', COMPLAINT: 'شكوى' };

/// Records a strike and tells the lawyer from the first one. Repeated strikes of one kind suspend the lawyer for a week.
export async function addLawyerStrike(db: Db, lawyerId: string, orderId: string, kind: 'WITHDRAWAL' | 'COMPLAINT') {
  await db.query('INSERT INTO lawyer_strikes (lawyer_id, order_id, kind) VALUES ($1, $2, $3)', [lawyerId, orderId, kind]);

  const countRes = await db.query(
    `SELECT COUNT(*)::int AS total FROM lawyer_strikes
     WHERE lawyer_id = $1 AND kind = $2 AND revoked_at IS NULL AND created_at > NOW() - make_interval(days => $3)`,
    [lawyerId, kind, STRIKE_WINDOW_DAYS]
  );
  const total = countRes.rows[0].total;

  if (total >= STRIKE_LIMIT) {
    await db.query(
      `UPDATE lawyer_profiles
       SET suspended_until = NOW() + make_interval(days => $1), is_available = FALSE, availability_off_reason = 'SUSPENDED'
       WHERE user_id = $2`,
      [SUSPENSION_DAYS, lawyerId]
    );
    await notify(db, lawyerId, 'حسابك اتوقف أسبوع', `بسبب ${STRIKE_LIMIT} مخالفات خلال ${STRIKE_WINDOW_DAYS} يوم`);
    return;
  }
  await notify(
    db,
    lawyerId,
    'اتسجلت عليك مخالفة',
    `${STRIKE_LABELS[kind]}. دي رقم ${total} من ${STRIKE_LIMIT} خلال ${STRIKE_WINDOW_DAYS} يوم، والتالتة بتوقف حسابك أسبوع`
  );
}

/// The admin cancels a strike. If the lawyer no longer reaches the limit, a strike suspension ends too
export async function revokeLawyerStrike(db: Db, strikeId: string, actorId: string): Promise<boolean> {
  const res = await db.query(
    `UPDATE lawyer_strikes SET revoked_at = NOW(), revoked_by = $1 WHERE id = $2 AND revoked_at IS NULL RETURNING lawyer_id, kind`,
    [actorId, strikeId]
  );
  if (res.rows.length === 0) return false;
  const { lawyer_id: lawyerId, kind } = res.rows[0];

  const countRes = await db.query(
    `SELECT COUNT(*)::int AS total FROM lawyer_strikes
     WHERE lawyer_id = $1 AND kind = $2 AND revoked_at IS NULL AND created_at > NOW() - make_interval(days => $3)`,
    [lawyerId, kind, STRIKE_WINDOW_DAYS]
  );
  let lifted = false;
  if (countRes.rows[0].total < STRIKE_LIMIT) {
    const liftRes = await db.query(
      `UPDATE lawyer_profiles SET suspended_until = NULL,
         availability_off_reason = CASE WHEN availability_off_reason = 'SUSPENDED' THEN NULL ELSE availability_off_reason END
       WHERE user_id = $1 AND suspended_until IS NOT NULL RETURNING user_id`,
      [lawyerId]
    );
    lifted = liftRes.rows.length > 0;
  }
  await notify(db, lawyerId, 'اتلغت مخالفة', lifted ? 'الإيقاف اتشال، فعّل «متاح» لما تكون جاهز' : 'الإدارة لغت مخالفة من على حسابك');
  return true;
}

/// Rebuilds a lawyer's public rating from published, visible reviews.
export async function refreshLawyerRating(db: Db, lawyerId: string) {
  await db.query(
    `UPDATE lawyer_profiles lp
     SET rating = stats.average, reviews_count = stats.total
     FROM (
       SELECT COALESCE(ROUND(AVG(rating), 2), 0) AS average, COUNT(*)::int AS total
       FROM reviews
       WHERE lawyer_id = $1 AND published_at IS NOT NULL AND is_hidden = FALSE
     ) stats
     WHERE lp.user_id = $1`,
    [lawyerId]
  );
}
