import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { notify } from '../lifecycle/service.js';
import { applySettlement, evaluateSettlement, SettlementOutcome } from '../lifecycle/settlement.js';
import { addMessage, readTicketForm, TicketError, ticketMessages } from './service.js';

const UUID_PATTERN = /^[0-9a-f-]{36}$/i;
const OUTCOMES = ['REFUND', 'LAWYER', 'SPLIT'];

/// The control page side of support: lists, replies, internal notes, and closing
export async function registerAdminSupport(fastify: FastifyInstance) {
  const handle = async (reply: FastifyReply, work: () => Promise<{ data?: unknown; message?: string }>) => {
    try {
      const result = await work();
      return reply.send({ success: true, ...result });
    } catch (err) {
      if (err instanceof TicketError) return reply.status(err.status).send({ success: false, error: err.message });
      throw err;
    }
  };

  // GET /api/v1/admin/support?role=client|lawyer - Every ticket of one side, waiting ones first
  fastify.get('/support', async (request: FastifyRequest, reply: FastifyReply) => {
    const { role } = (request.query || {}) as { role?: string };
    const res = await query(
      `SELECT t.id, t.reference, t.category, t.title, t.status, t.created_at, t.updated_at, t.closed_at,
              u.id AS user_id, u.phone AS user_phone, COALESCE(lp.full_name, u.full_name, u.phone) AS user_name,
              o.id AS order_id, o.order_number, o.payout_status,
              (SELECT m.body FROM ticket_messages m WHERE m.ticket_id = t.id AND m.author = 'USER' ORDER BY m.created_at LIMIT 1) AS first_message
       FROM support_tickets t
       JOIN users u ON u.id = t.user_id
       LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
       LEFT JOIN service_orders o ON o.id = t.order_id
       WHERE ($1::text IS NULL OR u.role::text = $1)
       ORDER BY CASE t.status WHEN 'UNDER_REVIEW' THEN 0 WHEN 'OPEN' THEN 1 ELSE 2 END, t.updated_at ASC
       LIMIT 500`,
      [role === 'client' || role === 'lawyer' ? role : null]
    );
    return reply.send({ success: true, data: res.rows });
  });

  // GET /api/v1/admin/support/:id - The ticket, all its messages and notes, and the order behind it
  fastify.get('/support/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    const res = await query(
      `SELECT t.*, u.role AS user_role, u.phone AS user_phone, u.email AS user_email,
              COALESCE(lp.full_name, u.full_name, u.phone) AS user_name, closer.email AS closed_by_email
       FROM support_tickets t
       JOIN users u ON u.id = t.user_id
       LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
       LEFT JOIN users closer ON closer.id = t.closed_by
       WHERE t.id = $1`,
      [id]
    );
    const ticket = res.rows[0];
    if (!ticket) return reply.status(404).send({ success: false, error: 'التذكرة غير موجودة' });

    let order = null;
    if (ticket.order_id) {
      const orderRes = await query(
        `SELECT o.id, o.order_number, o.status, o.payout_status, o.price, o.arrived_at, o.completed_at,
                COALESCE(c.full_name, c.phone) AS client_name, c.phone AS client_phone, o.client_id,
                lp.full_name AS lawyer_name, l.phone AS lawyer_phone, o.lawyer_id
         FROM service_orders o
         JOIN users c ON c.id = o.client_id
         JOIN users l ON l.id = o.lawyer_id
         LEFT JOIN lawyer_profiles lp ON lp.user_id = o.lawyer_id
         WHERE o.id = $1`,
        [ticket.order_id]
      );
      order = orderRes.rows[0] ?? null;
    }

    // A money decision is needed only while the fees are frozen for this ticket
    const needsDecision = ticket.category === 'MONEY' && ticket.status !== 'CLOSED' && order?.payout_status === 'FROZEN';
    let suggestion = null;
    if (needsDecision) {
      const full = await query('SELECT * FROM service_orders WHERE id = $1', [order.id]);
      suggestion = await evaluateSettlement(dbPool, full.rows[0]);
    }

    return reply.send({
      success: true,
      data: { ...ticket, order, needsDecision, suggestion, messages: await ticketMessages(dbPool, ticket.id, true) },
    });
  });

  // POST /api/v1/admin/support/:id/reply - A reply the sender sees; the first one opens the ticket
  fastify.post('/support/:id/reply', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    return handle(reply, async () => {
      const { fields, images } = await readTicketForm(request);
      return withTransaction(async (db) => {
        const ticket = (await db.query('SELECT * FROM support_tickets WHERE id::text = $1 FOR UPDATE', [id])).rows[0];
        if (!ticket) throw new TicketError(404, 'التذكرة غير موجودة');
        if (ticket.status === 'CLOSED') throw new TicketError(409, 'التذكرة مقفولة');
        await addMessage(db, ticket.id, 'ADMIN', adminId, fields.body ?? '', images);
        await db.query(`UPDATE support_tickets SET status = 'OPEN' WHERE id = $1`, [ticket.id]);
        await notify(db, ticket.user_id, 'رد الدعم الفني', `الإدارة ردت على تذكرتك ${ticket.reference}`, ticket.order_id ?? undefined);
        return { message: 'تم إرسال الرد' };
      });
    });
  });

  // POST /api/v1/admin/support/:id/note - An internal note only the admins see
  fastify.post('/support/:id/note', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { body?: string };
    return handle(reply, async () => {
      const ticket = (await query('SELECT id FROM support_tickets WHERE id::text = $1', [id])).rows[0];
      if (!ticket) throw new TicketError(404, 'التذكرة غير موجودة');
      await addMessage(dbPool, ticket.id, 'NOTE', adminId, body.body ?? '', []);
      return { message: 'تم حفظ الملاحظة' };
    });
  });

  // POST /api/v1/admin/support/:id/close - Only an admin closes a ticket; frozen fees need a money decision first
  fastify.post('/support/:id/close', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { outcome?: string; body?: string };
    return handle(reply, () => withTransaction(async (db) => {
      const ticket = (await db.query('SELECT * FROM support_tickets WHERE id::text = $1 FOR UPDATE', [id])).rows[0];
      if (!ticket) throw new TicketError(404, 'التذكرة غير موجودة');
      if (ticket.status === 'CLOSED') throw new TicketError(409, 'التذكرة مقفولة من قبل');

      if (ticket.category === 'MONEY' && ticket.order_id) {
        const order = (await db.query('SELECT * FROM service_orders WHERE id = $1 FOR UPDATE', [ticket.order_id])).rows[0];
        const otherMoneyTicket = await db.query(
          `SELECT 1 FROM support_tickets WHERE order_id = $1 AND id <> $2 AND status <> 'CLOSED' AND category = 'MONEY'`,
          [ticket.order_id, ticket.id]
        );
        if (order?.payout_status === 'FROZEN' && otherMoneyTicket.rows.length === 0) {
          if (!body.outcome || !OUTCOMES.includes(body.outcome)) {
            throw new TicketError(400, 'الأتعاب متوقفة على التذكرة دي، اختار الفلوس رايحة فين قبل القفل');
          }
          await applySettlement(db, order, body.outcome as SettlementOutcome, adminId, `قرار تذكرة ${ticket.reference}`);
        }
      }

      if (body.body && body.body.trim()) await addMessage(db, ticket.id, 'ADMIN', adminId, body.body, []);
      await db.query(`UPDATE support_tickets SET status = 'CLOSED', closed_at = NOW(), closed_by = $2, updated_at = NOW() WHERE id = $1`, [ticket.id, adminId]);
      await notify(db, ticket.user_id, 'التذكرة اتقفلت', `الإدارة قفلت تذكرتك ${ticket.reference}، ولو عندك مشكلة جديدة افتح تذكرة جديدة`, ticket.order_id ?? undefined);
      return { message: 'تم قفل التذكرة' };
    }));
  });
}
