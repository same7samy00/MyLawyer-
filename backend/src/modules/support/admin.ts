import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { notify } from '../lifecycle/service.js';
import { adjustBalance } from '../lifecycle/settlement.js';
import { sanitizeText } from '../../utils/security.js';
import { HttpError, UUID_PATTERN } from '../../utils/http.js';
import { addMessage, readTicketForm, ticketMessages } from './service.js';

/// The control page side of support: lists, replies, internal notes, and closing
export async function registerAdminSupport(fastify: FastifyInstance) {
  const handle = async (reply: FastifyReply, work: () => Promise<{ data?: unknown; message?: string }>) =>
    reply.send({ success: true, ...await work() });

  // GET /api/v1/admin/support?role=client|lawyer - Every ticket, or one side only, waiting ones first
  fastify.get('/support', async (request: FastifyRequest, reply: FastifyReply) => {
    const { role } = (request.query || {}) as { role?: string };
    const res = await query(
      `SELECT t.id, t.reference, t.category, t.title, t.status, t.created_at, t.updated_at, t.closed_at,
              u.id AS user_id, u.role AS user_role, u.phone AS user_phone, COALESCE(lp.full_name, u.full_name, u.phone) AS user_name,
              o.id AS order_id, o.order_number, o.payout_status,
              (SELECT m.body FROM ticket_messages m WHERE m.ticket_id = t.id AND m.author = 'USER' ORDER BY m.created_at LIMIT 1) AS first_message
       FROM support_tickets t
       JOIN users u ON u.id = t.user_id
       LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
       LEFT JOIN service_orders o ON o.id = t.order_id
       WHERE ($1::text IS NULL OR u.role::text = $1)
       ORDER BY t.created_at DESC
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
        `SELECT o.id, o.order_number, o.status, o.payout_status, o.payout_amount, o.price, o.arrived_at, o.completed_at,
                COALESCE(c.full_name, c.phone) AS client_name, c.phone AS client_phone, o.client_id,
                lp.full_name AS lawyer_name, l.phone AS lawyer_phone, o.lawyer_id,
                c.profile_photo_path AS client_photo, COALESCE(lp.profile_photo_path, l.profile_photo_path) AS lawyer_photo
         FROM service_orders o
         JOIN users c ON c.id = o.client_id
         JOIN users l ON l.id = o.lawyer_id
         LEFT JOIN lawyer_profiles lp ON lp.user_id = o.lawyer_id
         WHERE o.id = $1`,
        [ticket.order_id]
      );
      order = orderRes.rows[0] ?? null;
    }

    return reply.send({
      success: true,
      data: { ...ticket, order, messages: await ticketMessages(dbPool, ticket.id, true) },
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
        if (!ticket) throw new HttpError(404, 'التذكرة غير موجودة');
        if (ticket.status === 'CLOSED') throw new HttpError(409, 'التذكرة مغلقة');
        await addMessage(db, ticket.id, 'ADMIN', adminId, fields.body ?? '', images);
        await db.query(`UPDATE support_tickets SET status = 'OPEN' WHERE id = $1`, [ticket.id]);
        await notify(db, ticket.user_id, 'رد من الدعم الفني', `على تذكرة ${ticket.reference}`, { ticketId: ticket.id });
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
      if (!ticket) throw new HttpError(404, 'التذكرة غير موجودة');
      await addMessage(dbPool, ticket.id, 'NOTE', adminId, body.body ?? '', []);
      return { message: 'تم حفظ الملاحظة' };
    });
  });

  // POST /api/v1/admin/support/:id/transfer - Moves an amount between the order's two sides at once
  fastify.post('/support/:id/transfer', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { from?: string; amount?: number; reason?: string };
    const amount = Math.round(Number(body.amount) * 100) / 100;
    const reason = sanitizeText(body.reason || '', 500).trim();
    return handle(reply, () => withTransaction(async (db) => {
      if (body.from !== 'lawyer' && body.from !== 'client') throw new HttpError(400, 'اتجاه التحويل غير صالح');
      if (!Number.isFinite(amount) || amount <= 0 || amount > 100000) throw new HttpError(400, 'أدخل مبلغًا صحيحًا، والحد الأقصى للعملية الواحدة 100,000 ج.م');
      if (reason.length < 5) throw new HttpError(400, 'اكتب سبب الحركة');

      const ticket = (await db.query('SELECT * FROM support_tickets WHERE id::text = $1 FOR UPDATE', [id])).rows[0];
      if (!ticket) throw new HttpError(404, 'التذكرة غير موجودة');
      if (ticket.status === 'CLOSED') throw new HttpError(409, 'التذكرة مغلقة');
      const order = ticket.order_id ? (await db.query('SELECT id, client_id, lawyer_id FROM service_orders WHERE id = $1', [ticket.order_id])).rows[0] : null;
      if (!order) throw new HttpError(400, 'التحويل متاح للتذاكر المرتبطة بطلب فقط');

      const lawyer = { id: order.lawyer_id, role: 'lawyer' };
      const client = { id: order.client_id, role: 'client' };
      const [sender, receiver] = body.from === 'lawyer' ? [lawyer, client] : [client, lawyer];
      await adjustBalance(db, sender, -amount, reason, order.id, adminId);
      await adjustBalance(db, receiver, amount, reason, order.id, adminId);
      return { message: 'تم تنفيذ التحويل' };
    }));
  });

  // POST /api/v1/admin/support/:id/close - Only an admin closes a ticket; money decisions live on the order page
  fastify.post('/support/:id/close', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { body?: string };
    return handle(reply, () => withTransaction(async (db) => {
      const ticket = (await db.query('SELECT * FROM support_tickets WHERE id::text = $1 FOR UPDATE', [id])).rows[0];
      if (!ticket) throw new HttpError(404, 'التذكرة غير موجودة');
      if (ticket.status === 'CLOSED') throw new HttpError(409, 'التذكرة مغلقة بالفعل');

      if (body.body && body.body.trim()) await addMessage(db, ticket.id, 'ADMIN', adminId, body.body, []);
      await db.query(`UPDATE support_tickets SET status = 'CLOSED', closed_at = NOW(), closed_by = $2, updated_at = NOW() WHERE id = $1`, [ticket.id, adminId]);
      await notify(db, ticket.user_id, 'تذكرتك اتقفلت', `تذكرة ${ticket.reference}`, { ticketId: ticket.id });
      return { message: 'تم إغلاق التذكرة' };
    }));
  });
}
