import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import pg from 'pg';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { isValidEgyptianPhone } from '../../utils/security.js';
import { notify } from '../lifecycle/service.js';

type Db = pg.Pool | pg.PoolClient;

export const MIN_TRANSFER = 100;
export const DAILY_TRANSFER_LIMIT = 10000;

interface AuthenticatedUser {
  userId: string;
  role: string;
}

class TransferError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

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

async function addToLedger(db: Db, user: { id: string; role: string }, amount: number, reason: string) {
  if (user.role === 'lawyer') {
    await db.query('INSERT INTO lawyer_adjustments (lawyer_id, amount, reason, created_by) VALUES ($1, $2, $3, $1)', [user.id, amount, reason]);
  } else {
    await db.query('INSERT INTO client_credits (client_id, amount, reason, created_by) VALUES ($1, $2, $3, $1)', [user.id, amount, reason]);
  }
}

/// Only the first name and the first letter of the next one, enough to confirm the person
function shortName(fullName: string): string {
  const parts = String(fullName || '').trim().split(/\s+/);
  return parts.length > 1 ? `${parts[0]} ${parts[1].charAt(0)}.` : parts[0] || '';
}

async function findRecipient(db: Db, phone: string, senderId: string) {
  if (!isValidEgyptianPhone(phone)) throw new TransferError(400, 'اكتب رقم موبايل صحيح');
  const res = await db.query(
    `SELECT u.id, u.role, u.status, COALESCE(lp.full_name, u.full_name) AS full_name
     FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
     WHERE u.phone = $1 AND u.role IN ('client', 'lawyer')`,
    [phone.trim()]
  );
  const recipient = res.rows[0];
  if (!recipient || recipient.status !== 'active') throw new TransferError(404, 'مفيش حساب مفعّل بالرقم ده');
  if (recipient.id === senderId) throw new TransferError(400, 'مينفعش تحوّل لنفسك');
  return recipient;
}

export async function walletRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }
  });

  const handle = async (reply: FastifyReply, work: () => Promise<unknown>) => {
    try {
      return reply.send({ success: true, data: await work() });
    } catch (err) {
      if (err instanceof TransferError) return reply.status(err.status).send({ success: false, error: err.message });
      throw err;
    }
  };

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
        throw new TransferError(400, 'اكتب المبلغ صح');
      }
      if (amount < MIN_TRANSFER) throw new TransferError(400, `أقل مبلغ للتحويل ${MIN_TRANSFER} ج.م`);

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
        throw new TransferError(400, `أقصى تحويل ${DAILY_TRANSFER_LIMIT} ج.م في اليوم، والمتاح لك دلوقتي ${Math.max(0, remaining)} ج.م`);
      }

      if (amount > await spendableBalance(db, userId, role)) throw new TransferError(400, 'رصيدك مش كفاية');

      const transfer = await db.query(
        'INSERT INTO wallet_transfers (sender_id, recipient_id, amount) VALUES ($1, $2, $3) RETURNING id, reference, created_at',
        [userId, recipient.id, amount]
      );
      const reference = transfer.rows[0].reference;
      await addToLedger(db, { id: userId, role }, -amount, `تحويل ${reference} إلى ${shortName(recipient.full_name)}`);
      await addToLedger(db, recipient, amount, `تحويل ${reference} من ${senderName}`);
      await notify(db, userId, 'تم التحويل', `حوّلت ${amount} ج.م إلى ${shortName(recipient.full_name)}، رقم التحويل ${reference}`);
      await notify(db, recipient.id, 'وصلك تحويل', `وصلك ${amount} ج.م من ${senderName}، رقم التحويل ${reference}`);

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
