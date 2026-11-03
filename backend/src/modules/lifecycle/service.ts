import crypto from 'crypto';
import pg from 'pg';
import { dbPool, withTransaction } from '../../database/index.js';
import { sendPush } from '../../services/pushService.js';

type Db = pg.Pool | pg.PoolClient;

export const HOLD_HOURS = 24;
export const ORDER_DEADLINE_HOURS = 24;
export const REVIEW_WINDOW_DAYS = 7;
export const LAWYER_RESPONSE_SECONDS = 120;
export const PAYMENT_MINUTES = 10;
/// The lawyer and the client must really meet, so arrival is accepted within 50 meters only
export const ARRIVAL_RADIUS_KM = 0.05;
const MAX_MISSED_ORDERS = 2;
const LOCATION_SILENCE_MINUTES = 65;
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

async function closeUnansweredOrders() {
  const res = await dbPool.query(
    `UPDATE service_orders SET status = 'NO_RESPONSE'
     WHERE status = 'PENDING' AND response_deadline <= NOW()
     RETURNING id, client_id, lawyer_id`
  );

  for (const order of res.rows) {
    await dbPool.query(
      `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note) VALUES ($1, NULL, 'PENDING', 'NO_RESPONSE', 'انتهت مهلة رد المحامي دون رد')`,
      [order.id]
    );
    await notify(dbPool, order.client_id, 'المحامي ما ردش', 'اختار محامي تاني', order.id);

    const missed = await dbPool.query(
      `UPDATE lawyer_profiles SET missed_orders = missed_orders + 1
       WHERE user_id = $1 RETURNING missed_orders`,
      [order.lawyer_id]
    );

    if (missed.rows[0]?.missed_orders >= MAX_MISSED_ORDERS) {
      await dbPool.query(
        `UPDATE lawyer_profiles SET is_available = FALSE, availability_off_reason = 'MISSED', missed_orders = 0 WHERE user_id = $1`,
        [order.lawyer_id]
      );
      await notify(dbPool, order.lawyer_id, 'اتحولت لغير متاح', 'ما رديتش على طلبين. فعّل حالتك لما تكون جاهز', order.id);
    } else {
      await notify(dbPool, order.lawyer_id, 'فاتك طلب', 'لو فاتك طلب كمان هتتحول لغير متاح', order.id);
    }
  }
}

async function closeUnpaidOrders() {
  const res = await dbPool.query(
    `UPDATE service_orders SET status = 'PAYMENT_EXPIRED'
     WHERE status = 'ACCEPTED' AND payment_deadline <= NOW()
     RETURNING id, client_id, lawyer_id`
  );

  for (const order of res.rows) {
    await dbPool.query(
      `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note) VALUES ($1, NULL, 'ACCEPTED', 'PAYMENT_EXPIRED', 'انتهت مهلة الدفع دون دفع')`,
      [order.id]
    );
    await notify(dbPool, order.client_id, 'انتهت مهلة الدفع', 'الطلب اتلغى، وتقدر تبدأ طلب جديد', order.id);
    await notify(dbPool, order.lawyer_id, 'الموكل ما دفعش', 'الطلب اتلغى، وتقدر تستقبل طلبات جديدة', order.id);
  }
}

async function liftSuspensions() {
  const res = await dbPool.query(
    `UPDATE lawyer_profiles SET suspended_until = NULL
     WHERE suspended_until <= NOW() RETURNING user_id`
  );

  for (const lawyer of res.rows) {
    await notify(dbPool, lawyer.user_id, 'انتهى الإيقاف', 'فعّل حالتك عشان تستقبل طلبات');
  }
}

/// Two missed half-hour updates mean the phone is off the network
async function hideSilentLawyers() {
  const res = await dbPool.query(
    `UPDATE lawyer_profiles lp SET is_available = FALSE, availability_off_reason = 'NO_LOCATION'
     WHERE lp.is_available = TRUE
       AND COALESCE(lp.last_location_updated_at, lp.last_active_at, lp.updated_at) <= NOW() - make_interval(mins => $1)
       AND NOT EXISTS (
         SELECT 1 FROM service_orders o
         WHERE o.lawyer_id = lp.user_id AND o.status IN ('PENDING', 'ACCEPTED', 'ACTIVE')
       )
     RETURNING lp.user_id`,
    [LOCATION_SILENCE_MINUTES]
  );

  for (const lawyer of res.rows) {
    await notify(dbPool, lawyer.user_id, 'اتحولت لغير متاح', 'موقعك ما اتحدثش من ساعة. افتح التطبيق وفعّل حالتك');
  }
}

async function sendDeadlineReminders() {
  const reminders = [
    { column: 'reminder_first_sent', hoursLeft: 12, body: 'باقي 12 ساعة. سجّل وصولك وأنهِ المهمة' },
    { column: 'reminder_second_sent', hoursLeft: 4, body: 'باقي 4 ساعات. لو ما وصلتش المبلغ هيرجع للموكل' },
  ];

  for (const reminder of reminders) {
    const res = await dbPool.query(
      `UPDATE service_orders SET ${reminder.column} = TRUE
       WHERE status = 'ACTIVE' AND ${reminder.column} = FALSE
         AND expires_at <= NOW() + make_interval(hours => $1)
       RETURNING id, lawyer_id`,
      [reminder.hoursLeft]
    );

    for (const order of res.rows) {
      await notify(dbPool, order.lawyer_id, 'تذكير بإنهاء المهمة', reminder.body, order.id);
    }
  }
}

/// When the deadline passes the settlement table decides by itself, unless a money complaint is waiting
async function expireUnfinishedOrders() {
  const { evaluateSettlement, applySettlement } = await import('./settlement.js');
  const expired = await dbPool.query(
    `SELECT o.* FROM service_orders o
     WHERE o.status = 'ACTIVE' AND o.expires_at <= NOW()
       AND NOT EXISTS (SELECT 1 FROM support_tickets st WHERE st.order_id = o.id AND st.status <> 'CLOSED')`
  );

  for (const order of expired.rows) {
    await withTransaction(async (client) => {
      const fresh = await client.query(`SELECT * FROM service_orders WHERE id = $1 AND status = 'ACTIVE' FOR UPDATE`, [order.id]);
      if (fresh.rows.length === 0) return;
      const settlement = await evaluateSettlement(client, fresh.rows[0]);
      await applySettlement(client, fresh.rows[0], settlement.outcome, null, 'انتهت مهلة المهمة');
      // They met, so the client can rate the lawyer like any finished task
      if (fresh.rows[0].arrived_at && settlement.outcome !== 'REFUND') {
        await notify(client, order.client_id, 'انتهت المهمة', 'قيّم المحامي. ولو فيه مشكلة افتح «عندك مشكلة؟»', order.id);
      }
    });
  }
}

/// A day after the task ends, one reminder to rate if the client has not rated yet
async function sendReviewReminders() {
  const res = await dbPool.query(
    `UPDATE service_orders o SET review_reminder_sent = TRUE
     WHERE o.status = 'COMPLETED' AND o.review_reminder_sent = FALSE
       AND o.completed_at <= NOW() - INTERVAL '24 hours'
       AND o.completed_at > NOW() - make_interval(days => $1)
       AND NOT EXISTS (SELECT 1 FROM reviews r WHERE r.order_id = o.id)
     RETURNING o.id, o.client_id, o.order_number`,
    [REVIEW_WINDOW_DAYS]
  );

  for (const order of res.rows) {
    await notify(dbPool, order.client_id, 'قيّم المحامي', `طلب ${order.order_number}`, order.id);
  }
}

async function releaseHeldPayouts() {
  const res = await dbPool.query(
    `UPDATE service_orders SET payout_status = 'AVAILABLE'
     WHERE payout_status = 'HELD' AND hold_until <= NOW()
     RETURNING id, lawyer_id`
  );

  for (const order of res.rows) {
    await dbPool.query(
      `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note) VALUES ($1, NULL, 'COMPLETED', 'COMPLETED', 'أصبحت الأتعاب متاحة للمحامي بعد مرور 24 ساعة')`,
      [order.id]
    );
    await notify(dbPool, order.lawyer_id, 'أتعابك جاهزة', 'تقدر تستخدمها من محفظتك', order.id);
  }
}

/// Time-based steps of the order lifecycle. Each step is safe to run repeatedly.
export async function sweepLifecycle() {
  await closeUnansweredOrders();
  await closeUnpaidOrders();
  await liftSuspensions();
  await (await import('./settlement.js')).liftUserSuspensions(dbPool);
  await hideSilentLawyers();
  await sendDeadlineReminders();
  await expireUnfinishedOrders();
  await releaseHeldPayouts();
  await sendReviewReminders();
}
