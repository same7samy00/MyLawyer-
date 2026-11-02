import pg from 'pg';
import { addClientCredit, lawyerShare, notify } from './service.js';

type Db = pg.Pool | pg.PoolClient;

export const CANCEL_MINUTES = 5;
export const COMPLAINT_HOURS = 24;
const WARNING_LIMIT = 3;
const WARNING_WINDOW_DAYS = 30;
const SUSPENSION_DAYS = 7;
const CONFIRMED_COMPLAINTS_LIMIT = 3;

export type SettlementOutcome = 'REFUND' | 'LAWYER' | 'SPLIT';

export interface Settlement {
  outcome: SettlementOutcome;
  clientAmount: number;
  lawyerArrived: boolean;
  codeEntered: boolean;
  clientWarnings: number;
  lawyerWarnings: number;
  reason: string;
}

async function activeWarnings(db: Db, userId: string): Promise<number> {
  const res = await db.query('SELECT COUNT(*)::int AS total FROM account_warnings WHERE user_id = $1 AND revoked_at IS NULL', [userId]);
  return res.rows[0].total;
}

/// Who gets the money depends on two facts the app records: the arrival and the completion code
export async function evaluateSettlement(db: Db, order: any): Promise<Settlement> {
  const lawyerArrived = Boolean(order.arrived_at);
  // The order reaches COMPLETED only through the client's code
  const codeEntered = order.status === 'COMPLETED';
  const [clientWarnings, lawyerWarnings] = await Promise.all([activeWarnings(db, order.client_id), activeWarnings(db, order.lawyer_id)]);
  const price = Number(order.price);
  const base = { lawyerArrived, codeEntered, clientWarnings, lawyerWarnings };

  if (!lawyerArrived) {
    return { ...base, outcome: 'REFUND', clientAmount: price, reason: 'لم يسجل المحامي وصوله، فيُرد المبلغ كاملًا إلى الموكل.' };
  }
  if (codeEntered) {
    return { ...base, outcome: 'LAWYER', clientAmount: 0, reason: 'وصل المحامي وأُدخل كود الإنهاء، فتُصرف الأتعاب كاملة للمحامي.' };
  }
  if (clientWarnings >= CONFIRMED_COMPLAINTS_LIMIT && lawyerWarnings < CONFIRMED_COMPLAINTS_LIMIT) {
    return { ...base, outcome: 'LAWYER', clientAmount: 0, reason: 'وصل المحامي ولم يُدخل الكود، وعلى الموكل 3 إنذارات أو أكثر، فتُصرف الأتعاب كاملة للمحامي.' };
  }
  if (lawyerWarnings >= CONFIRMED_COMPLAINTS_LIMIT && clientWarnings < CONFIRMED_COMPLAINTS_LIMIT) {
    return { ...base, outcome: 'REFUND', clientAmount: price, reason: 'وصل المحامي ولم يُدخل الكود، وعلى المحامي 3 إنذارات أو أكثر، فيُرد المبلغ كاملًا إلى الموكل.' };
  }
  return { ...base, outcome: 'SPLIT', clientAmount: Math.round(price * 50) / 100, reason: 'وصل المحامي ولم يُدخل الكود، فيُقسم المبلغ مناصفة بين الطرفين.' };
}

export function outcomeAmount(outcome: SettlementOutcome, price: number): number {
  if (outcome === 'REFUND') return price;
  if (outcome === 'SPLIT') return Math.round(price * 50) / 100;
  return 0;
}

const OUTCOME_LABELS: Record<SettlementOutcome, string> = {
  REFUND: 'رد المبلغ للموكل',
  LAWYER: 'صرف الأتعاب للمحامي',
  SPLIT: 'تقسيم المبلغ مناصفة',
};

/// Applies one settlement to an order and closes every open money complaint on it
export async function applySettlement(db: pg.PoolClient, order: any, outcome: SettlementOutcome, actorId: string, note: string) {
  const price = Number(order.price);
  const clientAmount = outcomeAmount(outcome, price);
  const lawyerAmount = lawyerShare(price - clientAmount, Number(order.commission_percent), Number(order.tax_percent));
  const newStatus = lawyerAmount > 0 ? 'COMPLETED' : 'REFUNDED';

  await db.query(
    `UPDATE service_orders
     SET status = $1, payout_status = $2, payout_amount = $3, completion_code = NULL,
         completed_at = COALESCE(completed_at, NOW()), updated_at = NOW()
     WHERE id = $4`,
    [newStatus, lawyerAmount > 0 ? 'AVAILABLE' : 'REFUNDED', lawyerAmount, order.id]
  );
  await db.query(
    `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
     VALUES ($1, $2, $3, $4, $5)`,
    [order.id, actorId, order.status, newStatus, `تسوية الطلب: ${OUTCOME_LABELS[outcome]}`]
  );

  if (clientAmount > 0) {
    await addClientCredit(db, order.client_id, order.id, clientAmount, `تسوية طلب ${order.order_number}: ${OUTCOME_LABELS[outcome]}`);
  }

  await db.query(
    `UPDATE complaints SET status = 'RESOLVED', resolution = $1, refund_amount = $2, admin_note = $3, resolved_by = $4, resolved_at = NOW()
     WHERE order_id = $5 AND status = 'OPEN' AND kind = 'MONEY'`,
    [outcome, clientAmount, note || null, actorId, order.id]
  );
  await db.query(
    `UPDATE lawyer_reports SET status = 'RESOLVED', resolution = $1, admin_note = $2, resolved_by = $3, resolved_at = NOW()
     WHERE order_id = $4 AND status = 'OPEN' AND kind = 'MONEY'`,
    [outcome, note || null, actorId, order.id]
  );

  const clientMessage = clientAmount > 0 ? `تمت تسوية الطلب، وأُضيف ${clientAmount} ج.م إلى رصيدك.` : 'تمت تسوية الطلب، وصُرفت الأتعاب للمحامي.';
  const lawyerMessage = lawyerAmount > 0 ? `تمت تسوية الطلب، وأُضيف ${lawyerAmount} ج.م إلى محفظتك.` : 'تمت تسوية الطلب، ورُد المبلغ إلى الموكل.';
  await notify(db, order.client_id, 'تسوية الطلب', clientMessage, order.id);
  await notify(db, order.lawyer_id, 'تسوية الطلب', lawyerMessage, order.id);
  return { clientAmount, lawyerAmount, outcome };
}

/// Every warning is counted, and 3 in a month suspend the account for a week
export async function addWarning(db: Db, userId: string, reason: string, orderId: string | null, actorId: string | null) {
  await db.query(
    'INSERT INTO account_warnings (user_id, order_id, reason, created_by) VALUES ($1, $2, $3, $4)',
    [userId, orderId, reason, actorId]
  );
  await db.query('UPDATE users SET warnings_count = warnings_count + 1 WHERE id = $1', [userId]);

  const countRes = await db.query(
    `SELECT COUNT(*)::int AS total FROM account_warnings
     WHERE user_id = $1 AND revoked_at IS NULL AND created_at > NOW() - make_interval(days => $2)`,
    [userId, WARNING_WINDOW_DAYS]
  );

  if (countRes.rows[0].total >= WARNING_LIMIT) {
    await db.query(
      `UPDATE users SET status = 'suspended'::user_status, suspended_until = NOW() + make_interval(days => $1), updated_at = NOW()
       WHERE id = $2 AND status = 'active'`,
      [SUSPENSION_DAYS, userId]
    );
    await db.query(`UPDATE lawyer_profiles SET is_available = FALSE, availability_off_reason = 'SUSPENDED' WHERE user_id = $1`, [userId]);
    await notify(db, userId, 'تم إيقاف حسابك مؤقتًا', 'حسابك موقوف لمدة أسبوع بسبب تكرار الإنذارات');
  } else {
    await notify(db, userId, 'إنذار', reason, orderId ?? undefined);
  }
}

export async function revokeWarning(db: Db, warningId: string, actorId: string) {
  const res = await db.query(
    `UPDATE account_warnings SET revoked_at = NOW(), revoked_by = $1 WHERE id = $2 AND revoked_at IS NULL RETURNING user_id`,
    [actorId, warningId]
  );
  if (res.rows.length === 0) return false;
  await db.query('UPDATE users SET warnings_count = GREATEST(warnings_count - 1, 0) WHERE id = $1', [res.rows[0].user_id]);
  await notify(db, res.rows[0].user_id, 'إلغاء إنذار', 'ألغت الإدارة أحد الإنذارات المسجلة على حسابك');
  return true;
}

/// Temporary suspensions end by themselves, an admin suspension stays until the admin lifts it
export async function liftUserSuspensions(db: Db) {
  const res = await db.query(
    `UPDATE users SET status = 'active'::user_status, suspended_until = NULL, updated_at = NOW()
     WHERE status = 'suspended' AND suspended_until IS NOT NULL AND suspended_until <= NOW()
     RETURNING id`
  );
  for (const user of res.rows) {
    await notify(db, user.id, 'انتهى الإيقاف', 'حسابك اشتغل تاني وتقدر تستخدم التطبيق');
  }
}

/// A manual balance change with its reason, the person gets a notification
export async function adjustBalance(db: Db, user: { id: string; role: string }, amount: number, reason: string, orderId: string | null, actorId: string) {
  if (user.role === 'lawyer') {
    await db.query(
      'INSERT INTO lawyer_adjustments (lawyer_id, order_id, amount, reason, created_by) VALUES ($1, $2, $3, $4, $5)',
      [user.id, orderId, amount, reason, actorId]
    );
  } else {
    await db.query(
      'INSERT INTO client_credits (client_id, order_id, amount, reason, created_by) VALUES ($1, $2, $3, $4, $5)',
      [user.id, orderId, amount, reason, actorId]
    );
  }
  const title = amount > 0 ? 'إضافة إلى رصيدك' : 'خصم من رصيدك';
  await notify(db, user.id, title, `${Math.abs(amount)} ج.م: ${reason}`, orderId ?? undefined);
}
