import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { Db, dbPool, query, withTransaction } from '../../database/index.js';
import { AuthenticatedUser, HttpError, requireAuth } from '../../utils/http.js';
import { isValidEgyptianPhone, shortName } from '../../utils/security.js';
import { notify } from '../lifecycle/service.js';

export const MIN_TRANSFER = 100;
export const DAILY_TRANSFER_LIMIT = 10000;

/// What the account can spend now: the client's credits, or the lawyer's available earnings
export async function spendableBalance(db: Db, userId: string, role: string): Promise<number> {
  const res = role === 'lawyer'
    ? await db.query(
        `SELECT COALESCE((SELECT SUM(payout_amount) FROM service_orders WHERE lawyer_id = $1 AND payout_status = 'AVAILABLE'), 0)
              + COALESCE((SELECT SUM(amount) FROM lawyer_adjustments WHERE lawyer_id = $1), 0) AS balance`,
        [userId]
      )
    : await db.query('SELECT COALESCE(SUM(amount), 0) AS balance FROM client_credits WHERE client_id = $1', [userId]);
  return Number(res.rows[0].balance);
}

/// What the account can transfer: only withdrawable money. All of a lawyer's available earnings,
/// and for a client only what reached them by transfer, since refunds stay in the app and are spent first
export async function transferableBalance(db: Db, userId: string, role: string): Promise<number> {
  const balance = await spendableBalance(db, userId, role);
  if (role === 'lawyer') return Math.max(0, balance);
  const res = await db.query(
    `SELECT COALESCE((SELECT SUM(amount) FROM wallet_transfers WHERE recipient_id = $1), 0)
          - COALESCE((SELECT SUM(amount) FROM wallet_transfers WHERE sender_id = $1), 0) AS received`,
    [userId]
  );
  return Math.max(0, Math.min(balance, Number(res.rows[0].received)));
}

async function addToLedger(db: Db, user: { id: string; role: string }, amount: number, reason: string) {
  if (user.role === 'lawyer') {
    await db.query('INSERT INTO lawyer_adjustments (lawyer_id, amount, reason, created_by) VALUES ($1, $2, $3, $1)', [user.id, amount, reason]);
  } else {
    await db.query('INSERT INTO client_credits (client_id, amount, reason, created_by) VALUES ($1, $2, $3, $1)', [user.id, amount, reason]);
  }
}

async function findRecipient(db: Db, phone: string, senderId: string) {
  if (!isValidEgyptianPhone(phone)) throw new HttpError(400, 'اكتب رقم موبايل صحيح');
  const res = await db.query(
    `SELECT u.id, u.role, u.status, COALESCE(lp.full_name, u.full_name) AS full_name
     FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
     WHERE u.phone = $1 AND u.role IN ('client', 'lawyer')`,
    [phone.trim()]
  );
  const recipient = res.rows[0];
  if (!recipient || recipient.status !== 'active') throw new HttpError(404, 'مفيش حساب مفعّل بالرقم ده');
  if (recipient.id === senderId) throw new HttpError(400, 'مينفعش تحوّل لنفسك');
  return recipient;
}

export async function walletRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());

  const handle = async (reply: FastifyReply, work: () => Promise<unknown>) => reply.send({ success: true, data: await work() });

  // GET /api/v1/wallet/recipient?phone= - Confirm who receives before sending
  fastify.get('/recipient', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { phone } = (request.query || {}) as { phone?: string };
    return handle(reply, async () => {
      const recipient = await findRecipient(dbPool, String(phone ?? ''), userId);
      return { name: shortName(recipient.full_name), role: recipient.role };
    });
  });

  // GET /api/v1/wallet/limits - The transfer limits and what is left today
  fastify.get('/limits', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    return handle(reply, async () => {
      const sent = await query(
        `SELECT COALESCE(SUM(amount), 0) AS total FROM wallet_transfers WHERE sender_id = $1 AND created_at > NOW() - INTERVAL '24 hours'`,
        [userId]
      );
      return {
        minimum: MIN_TRANSFER,
        dailyLimit: DAILY_TRANSFER_LIMIT,
        remainingToday: Math.max(0, DAILY_TRANSFER_LIMIT - Number(sent.rows[0].total)),
        balance: await spendableBalance(dbPool, userId, role),
        transferable: await transferableBalance(dbPool, userId, role),
      };
    });
  });

  // POST /api/v1/wallet/transfer - Send money from my balance to another account by phone
  fastify.post('/transfer', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as { phone?: string; amount?: number | string };
    const amount = Number(body.amount);

    return handle(reply, () => withTransaction(async (db) => {
      if (!Number.isFinite(amount) || Math.round(amount * 100) !== amount * 100) {
        throw new HttpError(400, 'اكتب المبلغ صح');
      }
      if (amount < MIN_TRANSFER) throw new HttpError(400, `أقل مبلغ للتحويل ${MIN_TRANSFER} ج.م`);

      const recipient = await findRecipient(db, String(body.phone ?? ''), userId);

      // One transfer at a time per sender, so the balance and the limit stay right
      const sender = await db.query('SELECT id, role, COALESCE(full_name, phone) AS name FROM users WHERE id = $1 FOR UPDATE', [userId]);
      const senderName = shortName(sender.rows[0].name);

      const sent = await db.query(
        `SELECT COALESCE(SUM(amount), 0) AS total FROM wallet_transfers WHERE sender_id = $1 AND created_at > NOW() - INTERVAL '24 hours'`,
        [userId]
      );
      const remaining = DAILY_TRANSFER_LIMIT - Number(sent.rows[0].total);
      if (amount > remaining) {
        throw new HttpError(400, `أقصى تحويل ${DAILY_TRANSFER_LIMIT} ج.م في اليوم، والمتاح لك دلوقتي ${Math.max(0, remaining)} ج.م`);
      }

      if (amount > await spendableBalance(db, userId, role)) throw new HttpError(400, 'رصيدك مش كفاية');
      const transferable = await transferableBalance(db, userId, role);
      if (amount > transferable) {
        throw new HttpError(400, `بيتحول بس الرصيد المتاح للسحب، والمبالغ المرتجعة ما بتتحولش. المتاح للتحويل ${transferable} ج.م`);
      }

      const transfer = await db.query(
        'INSERT INTO wallet_transfers (sender_id, recipient_id, amount) VALUES ($1, $2, $3) RETURNING id, reference, created_at',
        [userId, recipient.id, amount]
      );
      const reference = transfer.rows[0].reference;
      await addToLedger(db, { id: userId, role }, -amount, `تحويل ${reference} إلى ${shortName(recipient.full_name)}`);
      await addToLedger(db, recipient, amount, `تحويل ${reference} من ${senderName}`);
      await notify(db, userId, 'تم التحويل', `${amount} ج.م إلى ${shortName(recipient.full_name)}. رقم ${reference}`);
      await notify(db, recipient.id, 'وصلك تحويل', `${amount} ج.م من ${senderName}. رقم ${reference}`);

      return {
        id: transfer.rows[0].id,
        reference,
        amount,
        recipientName: shortName(recipient.full_name),
        balance: await spendableBalance(db, userId, role),
      };
    }));
  });
}
