import { dbPool, withTransaction } from '../../database/index.js';
import { ARRIVAL_REMINDER_MINUTES, CLIENT_REPLY_HOURS, notify, REVIEW_WINDOW_DAYS } from './service.js';
import { applySettlement, liftUserSuspensions } from './settlement.js';
import { advanceRequests } from '../requests/service.js';

const MAX_MISSED_ORDERS = 2;
const LOCATION_SILENCE_MINUTES = 10;

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

/// An available lawyer updates every minute, so ten silent minutes mean the app is closed.
/// A lawyer with an open task is free to close it.
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
    await notify(dbPool, lawyer.user_id, 'خرجت من الخدمة', 'افتح التطبيق عشان ترجع متاح');
  }
}

async function sendDeadlineReminders() {
  const reminders = [
    { column: 'reminder_first_sent', hoursLeft: 12, body: 'باقي 12 ساعة. لو وصلت، دوس «وصلت»' },
    { column: 'reminder_second_sent', hoursLeft: 4, body: 'باقي 4 ساعات. لو ما وصلتش المبلغ هيرجع للموكل' },
  ];

  for (const reminder of reminders) {
    const res = await dbPool.query(
      `UPDATE service_orders SET ${reminder.column} = TRUE
       WHERE status = 'ACTIVE' AND arrived_at IS NULL AND ${reminder.column} = FALSE
         AND expires_at <= NOW() + make_interval(hours => $1)
       RETURNING id, lawyer_id`,
      [reminder.hoursLeft]
    );

    for (const order of res.rows) {
      await notify(dbPool, order.lawyer_id, 'تذكير بالوصول', reminder.body, order.id);
    }
  }
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
    await notify(dbPool, order.client_id, 'المحامي اتأخر', 'تحب تستنى ولا تلغي وترجع فلوسك؟', order.id);
  }
}

/// Without an arrival the money goes back: two hours after an unanswered question, or at the 24-hour deadline.
/// After an arrival nothing moves by itself, the money stays held until the task ends or the admin decides.
async function refundUnreachedOrders() {
  const unreached = await dbPool.query(
    `SELECT o.id FROM service_orders o
     WHERE o.status = 'ACTIVE' AND o.arrived_at IS NULL
       AND (o.expires_at <= NOW()
            OR (o.client_keeps_waiting = FALSE AND o.delay_notified_at <= NOW() - make_interval(hours => $1)))
       AND NOT EXISTS (SELECT 1 FROM support_tickets st WHERE st.order_id = o.id AND st.status <> 'CLOSED')`,
    [CLIENT_REPLY_HOURS]
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
  await closeUnansweredOrders();
  await advanceRequests();
  await closeUnpaidOrders();
  await liftSuspensions();
  await liftUserSuspensions(dbPool);
  await hideSilentLawyers();
  await sendDeadlineReminders();
  await sendArrivalReminders();
  await askClientAboutDelay();
  await refundUnreachedOrders();
  await releaseHeldPayouts();
  await sendReviewReminders();
}
