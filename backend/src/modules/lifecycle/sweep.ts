import { dbPool, withTransaction } from '../../database/index.js';
import { ARRIVAL_REMINDER_MINUTES, CLIENT_REPLY_MINUTES, notify, REVIEW_WINDOW_DAYS } from './service.js';
import { applySettlement, liftUserSuspensions } from './settlement.js';
import { advanceRequests, releaseChoice } from '../requests/service.js';
import { sendWake } from '../../services/pushService.js';

/// An available lawyer's phone says «still here» every 3 minutes. After 5 quiet minutes the server wakes it with a
/// silent push, after 7 a second one, and after 8 with no answer the lawyer is turned off (owner decision 2026-11-09)
const FIRST_WAKE_MINUTES = 5;
const SECOND_WAKE_MINUTES = 7;
const LOCATION_SILENCE_MINUTES = 8;

/// A choice left a whole day unpaid goes away, and the client is back on the same offers
async function closeUnpaidOrders() {
  const due = await dbPool.query(`SELECT id FROM service_orders WHERE status = 'ACCEPTED' AND payment_deadline <= NOW()`);
  for (const { id } of due.rows) {
    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT id, client_id, lawyer_id FROM service_orders WHERE id = $1 AND status = 'ACCEPTED' AND payment_deadline <= NOW() FOR UPDATE`, [id]);
      if (locked.rows[0]) await releaseChoice(client, locked.rows[0], false);
    });
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

/// Silent pushes that make a quiet phone send its place, before anyone is turned off
async function wakeQuietLawyers() {
  const res = await dbPool.query(
    `UPDATE lawyer_profiles lp SET wake_count = lp.wake_count + 1, last_wake_at = NOW()
     WHERE lp.is_available = TRUE
       AND ((lp.wake_count = 0 AND COALESCE(lp.last_location_updated_at, lp.last_active_at, lp.updated_at) <= NOW() - make_interval(mins => $1))
         OR (lp.wake_count = 1 AND COALESCE(lp.last_location_updated_at, lp.last_active_at, lp.updated_at) <= NOW() - make_interval(mins => $2)))
     RETURNING lp.user_id`,
    [FIRST_WAKE_MINUTES, SECOND_WAKE_MINUTES]
  );
  for (const lawyer of res.rows) await sendWake(lawyer.user_id);
}

/// Eight quiet minutes and two unanswered wakes mean the phone is really off or offline.
/// A lawyer with an open task is free to close it.
async function hideSilentLawyers() {
  const res = await dbPool.query(
    `UPDATE lawyer_profiles lp SET is_available = FALSE, availability_off_reason = 'NO_LOCATION'
     WHERE lp.is_available = TRUE AND lp.wake_count >= 2 AND lp.last_wake_at <= NOW() - INTERVAL '1 minute'
       AND COALESCE(lp.last_location_updated_at, lp.last_active_at, lp.updated_at) <= NOW() - make_interval(mins => $1)
       AND NOT EXISTS (
         SELECT 1 FROM service_orders o
         WHERE o.lawyer_id = lp.user_id AND o.status IN ('PENDING', 'ACCEPTED', 'ACTIVE')
       )
     RETURNING lp.user_id`,
    [LOCATION_SILENCE_MINUTES]
  );

  for (const lawyer of res.rows) {
    await notify(dbPool, lawyer.user_id, 'خرجت من الخدمة', 'افتح التطبيق عشان ترجع متاح');
  }
}

/// Notifications are a short history, older lines go after 30 days. Checked once an hour
let lastCleanup = 0;
async function removeOldNotifications() {
  if (Date.now() - lastCleanup < 3_600_000) return;
  lastCleanup = Date.now();
  await dbPool.query(`DELETE FROM notifications WHERE created_at < NOW() - INTERVAL '30 days'`);
  // An app away longer than two days reloads everything instead of reading old changes
  await dbPool.query(`DELETE FROM change_log WHERE created_at < NOW() - INTERVAL '2 days'`);
}

async function sendArrivalReminders() {
  const res = await dbPool.query(
    `UPDATE service_orders SET arrival_reminder_sent = TRUE
     WHERE status = 'ACTIVE' AND arrived_at IS NULL AND arrival_reminder_sent = FALSE
       AND arrival_deadline <= NOW() + make_interval(mins => $1)
     RETURNING id, lawyer_id`,
    [ARRIVAL_REMINDER_MINUTES]
  );

  for (const order of res.rows) {
    await notify(dbPool, order.lawyer_id, 'مهلة الوصول قربت تخلص', 'لو وصلت، دوس «وصلت»', order.id);
  }
}

async function askClientAboutDelay() {
  const res = await dbPool.query(
    `UPDATE service_orders SET delay_notified_at = NOW()
     WHERE status = 'ACTIVE' AND arrived_at IS NULL AND delay_notified_at IS NULL AND arrival_deadline <= NOW()
     RETURNING id, client_id`
  );

  for (const order of res.rows) {
    await notify(dbPool, order.client_id, 'المحامي اتأخر', 'تحب تستنى ولا تلغي وترجع فلوسك؟ لو ما ردتش خلال 5 دقايق فلوسك هترجعلك', order.id);
  }
}

/// Without an arrival the money goes back: five minutes after an unanswered question, or at the 24-hour deadline.
/// After an arrival nothing moves by itself, the money stays held until the task ends or the admin decides.
async function refundUnreachedOrders() {
  const unreached = await dbPool.query(
    `SELECT o.id FROM service_orders o
     WHERE o.status = 'ACTIVE' AND o.arrived_at IS NULL
       AND (o.expires_at <= NOW()
            OR (o.client_keeps_waiting = FALSE AND o.delay_notified_at <= NOW() - make_interval(mins => $1)))
       AND NOT EXISTS (SELECT 1 FROM support_tickets st WHERE st.order_id = o.id AND st.status <> 'CLOSED')`,
    [CLIENT_REPLY_MINUTES]
  );

  for (const order of unreached.rows) {
    await withTransaction(async (client) => {
      const fresh = await client.query(
        `SELECT * FROM service_orders WHERE id = $1 AND status = 'ACTIVE' AND arrived_at IS NULL FOR UPDATE`,
        [order.id]
      );
      if (fresh.rows.length === 0) return;
      await applySettlement(client, fresh.rows[0], 'REFUND', null, 'المحامي ما سجلش وصوله في المهلة');
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
  await advanceRequests();
  await closeUnpaidOrders();
  await liftSuspensions();
  await liftUserSuspensions(dbPool);
  await wakeQuietLawyers();
  await hideSilentLawyers();
  await removeOldNotifications();
  await sendArrivalReminders();
  await askClientAboutDelay();
  await refundUnreachedOrders();
  await releaseHeldPayouts();
  await sendReviewReminders();
}
