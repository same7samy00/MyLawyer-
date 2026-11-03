import crypto from 'crypto';
import { Db } from '../../database/index.js';
import { sendPush } from '../../services/pushService.js';

export const HOLD_HOURS = 24;
export const ORDER_DEADLINE_HOURS = 24;
export const REVIEW_WINDOW_DAYS = 7;
export const LAWYER_RESPONSE_SECONDS = 120;
export const PAYMENT_MINUTES = 10;
/// The lawyer and the client must really meet, so arrival is accepted within 50 meters only
export const ARRIVAL_RADIUS_KM = 0.05;
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
}

export async function notify(db: Db, userId: string, title: string, body: string, link?: string | NotifyLink) {
  const { orderId, ticketId } = typeof link === 'string' ? { orderId: link, ticketId: undefined } : (link ?? {});
  await db.query(
    'INSERT INTO notifications (user_id, title, body, order_id, ticket_id) VALUES ($1, $2, $3, $4, $5)',
    [userId, title, body, orderId ?? null, ticketId ?? null]
  );

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

  // The order never waits for the phone
  void sendPush(userId, title, body, { orderId, ticketId });
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

/// True while the lawyer has an order waiting, unpaid, or in progress.
export async function lawyerHasOpenOrder(db: Db, lawyerId: string, exceptOrderId?: string): Promise<boolean> {
  const res = await db.query(
    `SELECT 1 FROM service_orders
     WHERE lawyer_id = $1 AND status IN ('PENDING', 'ACCEPTED', 'ACTIVE')
       AND ($2::uuid IS NULL OR id <> $2::uuid)
     LIMIT 1`,
    [lawyerId, exceptOrderId ?? null]
  );
  return res.rows.length > 0;
}

/// Records a strike, and repeated strikes of one kind suspend the lawyer for a week.
export async function addLawyerStrike(db: Db, lawyerId: string, orderId: string, kind: 'WITHDRAWAL' | 'COMPLAINT') {
  await db.query('INSERT INTO lawyer_strikes (lawyer_id, order_id, kind) VALUES ($1, $2, $3)', [lawyerId, orderId, kind]);

  const countRes = await db.query(
    `SELECT COUNT(*)::int AS total FROM lawyer_strikes
     WHERE lawyer_id = $1 AND kind = $2 AND created_at > NOW() - make_interval(days => $3)`,
    [lawyerId, kind, STRIKE_WINDOW_DAYS]
  );

  if (countRes.rows[0].total >= STRIKE_LIMIT) {
    await db.query(
      `UPDATE lawyer_profiles
       SET suspended_until = NOW() + make_interval(days => $1), is_available = FALSE, availability_off_reason = 'SUSPENDED'
       WHERE user_id = $2`,
      [SUSPENSION_DAYS, lawyerId]
    );
    await notify(db, lawyerId, 'حسابك اتوقف أسبوع', 'بسبب تكرار المخالفات');
  }
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
