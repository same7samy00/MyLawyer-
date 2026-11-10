import fs from 'fs';
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { AuthenticatedUser, HttpError, requireAuth } from '../../utils/http.js';
import { notify } from '../lifecycle/service.js';
import { readOnAction } from '../notifications/readOnAction.js';
import {
  addMessage,
  attachmentFile,
  freezePayout,
  MAX_OPEN_TICKETS,
  ORDER_TICKET_WINDOW_HOURS,
  readTicketForm,
  TICKET_CATEGORIES,
  TicketCategory,
  ticketMessages,
} from './service.js';

const listItem = (row: any) => ({
  id: row.id,
  reference: row.reference,
  category: row.category,
  title: row.title,
  status: row.status,
  orderNumber: row.order_number,
  orderId: row.order_id,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
  // The sender waits for the admin after every message, so nothing more goes out until a reply
  awaitingReply: row.status !== 'CLOSED' && row.last_author !== 'ADMIN',
});

/// Technical support for clients and lawyers: open a ticket, read the replies, and answer until an admin closes it
export async function supportRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());
  readOnAction(fastify, 'ticket_id');

  const handle = async (reply: FastifyReply, work: () => Promise<{ status?: number; data: unknown; message?: string }>) => {
    const result = await work();
    return reply.status(result.status ?? 200).send({ success: true, data: result.data, message: result.message });
  };

  // GET /api/v1/support/tickets - My tickets, the latest first
  fastify.get('/tickets', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const res = await query(
      `SELECT t.*, o.order_number, (SELECT m.author FROM ticket_messages m WHERE m.ticket_id = t.id AND m.author <> 'NOTE' ORDER BY m.created_at DESC LIMIT 1) AS last_author FROM support_tickets t LEFT JOIN service_orders o ON o.id = t.order_id
       WHERE t.user_id = $1 ORDER BY t.updated_at DESC LIMIT 100`,
      [userId]
    );
    return reply.send({ success: true, data: res.rows.map(listItem) });
  });

  // POST /api/v1/support/tickets - A new ticket: category, title, text, an optional order, and up to 5 images
  fastify.post('/tickets', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    return handle(reply, async () => {
      if (role !== 'client' && role !== 'lawyer') throw new HttpError(403, 'الدعم الفني للموكلين والمحامين');
      const { fields, images } = await readTicketForm(request);

      const category = fields.category as TicketCategory;
      if (!TICKET_CATEGORIES.includes(category)) throw new HttpError(400, 'اختار نوع المشكلة');
      const title = sanitizeText(fields.title ?? '', 120);
      if (title.length < 3) throw new HttpError(400, 'اكتب عنوان للمشكلة');
      if (sanitizeText(fields.body ?? '', 4000).length < 10) throw new HttpError(400, 'اكتب تفاصيل المشكلة في 10 أحرف على الأقل');

      return withTransaction(async (db) => {
        // One sender at a time, so the open tickets count stays right
        await db.query('SELECT id FROM users WHERE id = $1 FOR NO KEY UPDATE', [userId]);
        const waiting = await db.query(`SELECT reference FROM support_tickets WHERE user_id = $1 AND status = 'UNDER_REVIEW' LIMIT 1`, [userId]);
        if (waiting.rows.length > 0) {
          throw new HttpError(409, `تذكرتك ${waiting.rows[0].reference} لسه تحت المراجعة، استنى رد الإدارة الأول`);
        }
        const open = await db.query(`SELECT COUNT(*)::int AS count FROM support_tickets WHERE user_id = $1 AND status <> 'CLOSED'`, [userId]);
        if (open.rows[0].count >= MAX_OPEN_TICKETS) {
          throw new HttpError(409, `عندك ${MAX_OPEN_TICKETS} تذاكر مفتوحة، استنى لما واحدة منهم تتقفل`);
        }

        let order: any = null;
        if (fields.orderId) {
          const orderRes = await db.query(
            `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND (client_id = $2 OR lawyer_id = $2) FOR UPDATE`,
            [fields.orderId, userId]
          );
          order = orderRes.rows[0];
          if (!order) throw new HttpError(404, 'الطلب غير موجود');
          // A lawyer's ticket would hold the client's refund, so it waits until the lawyer has arrived (owner decision 2026-11-06)
          if (order.lawyer_id === userId && order.status === 'ACTIVE' && !order.arrived_at) {
            throw new HttpError(409, 'تقدر تفتح تذكرة على الطلب ده بعد ما تسجل وصولك');
          }
          if (order.completed_at && Date.now() - new Date(order.completed_at).getTime() >= ORDER_TICKET_WINDOW_HOURS * 3600000) {
            throw new HttpError(409, `مينفعش تفتح تذكرة على طلب بعد ${ORDER_TICKET_WINDOW_HOURS} ساعة من إنهائه`);
          }
          const sameOrder = await db.query(`SELECT 1 FROM support_tickets WHERE order_id = $1 AND user_id = $2 AND status <> 'CLOSED'`, [order.id, userId]);
          if (sameOrder.rows.length > 0) throw new HttpError(409, 'عندك تذكرة مفتوحة على الطلب ده، كمل فيها');
        }
        if (category === 'ORDER' && !order) throw new HttpError(400, 'اختار الطلب اللي فيه المشكلة');

        const ticket = await db.query(
          'INSERT INTO support_tickets (user_id, category, title, order_id) VALUES ($1, $2, $3, $4) RETURNING *',
          [userId, category, title, order?.id ?? null]
        );
        const row = ticket.rows[0];
        await addMessage(db, row.id, 'USER', userId, fields.body ?? '', images);

        if (order) {
          await db.query(
            `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note) VALUES ($1, $2, $3, $3, $4)`,
            [order.id, userId, order.status, `فُتحت تذكرة ${row.reference}`]
          );
          const frozen = await freezePayout(db, order, `تذكرة ${row.reference}`);
          const other = order.client_id === userId ? order.lawyer_id : order.client_id;
          await notify(db, other, 'مراجعة على طلب', `فيه مشكلة على طلب ${order.order_number}، والإدارة بتراجعها`, { orderId: order.id });
          if (frozen) await notify(db, order.lawyer_id, 'أتعابك اتجمدت', `طلب ${order.order_number}، لحد قرار الإدارة`, { orderId: order.id });
        }

        return {
          status: 201,
          data: listItem({ ...row, order_number: order?.order_number ?? null, last_author: 'USER' }),
          message: `استلمنا تذكرتك رقم ${row.reference}، والإدارة هترد عليك`,
        };
      });
    });
  });

  // GET /api/v1/support/tickets/:id - One ticket with its messages
  fastify.get('/tickets/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const res = await query(
      `SELECT t.*, o.order_number, (SELECT m.author FROM ticket_messages m WHERE m.ticket_id = t.id AND m.author <> 'NOTE' ORDER BY m.created_at DESC LIMIT 1) AS last_author FROM support_tickets t LEFT JOIN service_orders o ON o.id = t.order_id
       WHERE (t.id::text = $1 OR t.reference = $1) AND t.user_id = $2`,
      [id, userId]
    );
    const row = res.rows[0];
    if (!row) return reply.status(404).send({ success: false, error: 'التذكرة غير موجودة' });
    return reply.send({ success: true, data: { ...listItem(row), messages: await ticketMessages(dbPool, row.id, false) } });
  });

  // POST /api/v1/support/tickets/:id/messages - Another reply while the ticket is not closed
  fastify.post('/tickets/:id/messages', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    return handle(reply, async () => {
      const { fields, images } = await readTicketForm(request);
      return withTransaction(async (db) => {
        const res = await db.query(
          `SELECT * FROM support_tickets WHERE (id::text = $1 OR reference = $1) AND user_id = $2 FOR UPDATE`,
          [id, userId]
        );
        const ticket = res.rows[0];
        if (!ticket) throw new HttpError(404, 'التذكرة غير موجودة');
        if (ticket.status === 'CLOSED') throw new HttpError(409, 'التذكرة دي اتقفلت، لو عندك مشكلة جديدة افتح تذكرة جديدة');
        const last = await db.query(
          `SELECT author FROM ticket_messages WHERE ticket_id = $1 AND author <> 'NOTE' ORDER BY created_at DESC LIMIT 1`,
          [ticket.id]
        );
        if (last.rows[0]?.author !== 'ADMIN') throw new HttpError(409, 'استنى رد الإدارة الأول، وبعدها تقدر ترد');
        await addMessage(db, ticket.id, 'USER', userId, fields.body ?? '', images);
        return { status: 201, data: { messages: await ticketMessages(db, ticket.id, false) }, message: 'تم إرسال ردك' };
      });
    });
  });

  // GET /api/v1/support/attachments/:id - An image, only for the ticket owner and the admins
  fastify.get('/attachments/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const viewer = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const file = await attachmentFile(dbPool, id, viewer);
    if (!file) return reply.status(404).send({ success: false, error: 'الصورة غير موجودة' });
    reply.header('Cache-Control', 'private, max-age=3600');
    return reply.type(file.mime).send(fs.createReadStream(file.filePath));
  });
}
