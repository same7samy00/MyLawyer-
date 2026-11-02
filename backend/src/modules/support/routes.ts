import fs from 'fs';
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { notify } from '../lifecycle/service.js';
import {
  addMessage,
  attachmentFile,
  canFreezeFor,
  freezePayout,
  MAX_OPEN_TICKETS,
  readTicketForm,
  TICKET_CATEGORIES,
  TicketCategory,
  TicketError,
  ticketMessages,
} from './service.js';

interface AuthenticatedUser {
  userId: string;
  role: string;
}

const listItem = (row: any) => ({
  id: row.id,
  reference: row.reference,
  category: row.category,
  title: row.title,
  status: row.status,
  orderNumber: row.order_number,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

/// Technical support for clients and lawyers: open a ticket, read the replies, and answer until an admin closes it
export async function supportRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }
  });

  const handle = async (reply: FastifyReply, work: () => Promise<{ status?: number; data: unknown; message?: string }>) => {
    try {
      const result = await work();
      return reply.status(result.status ?? 200).send({ success: true, data: result.data, message: result.message });
    } catch (err) {
      if (err instanceof TicketError) return reply.status(err.status).send({ success: false, error: err.message });
      throw err;
    }
  };

  // GET /api/v1/support/tickets - My tickets, the latest first
  fastify.get('/tickets', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const res = await query(
      `SELECT t.*, o.order_number FROM support_tickets t LEFT JOIN service_orders o ON o.id = t.order_id
       WHERE t.user_id = $1 ORDER BY t.updated_at DESC LIMIT 100`,
      [userId]
    );
    return reply.send({ success: true, data: res.rows.map(listItem) });
  });

  // POST /api/v1/support/tickets - A new ticket: category, title, text, an optional order, and up to 5 images
  fastify.post('/tickets', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    return handle(reply, async () => {
      if (role !== 'client' && role !== 'lawyer') throw new TicketError(403, 'الدعم الفني للموكلين والمحامين');
      const { fields, images } = await readTicketForm(request);

      const category = fields.category as TicketCategory;
      if (!TICKET_CATEGORIES.includes(category)) throw new TicketError(400, 'اختار نوع المشكلة');
      const title = sanitizeText(fields.title ?? '', 120);
      if (title.length < 3) throw new TicketError(400, 'اكتب عنوان للمشكلة');
      if (sanitizeText(fields.body ?? '', 4000).length < 10) throw new TicketError(400, 'اكتب تفاصيل المشكلة في 10 أحرف على الأقل');

      return withTransaction(async (db) => {
        // One sender at a time, so the open tickets count stays right
        await db.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
        const open = await db.query(`SELECT COUNT(*)::int AS count FROM support_tickets WHERE user_id = $1 AND status <> 'CLOSED'`, [userId]);
        if (open.rows[0].count >= MAX_OPEN_TICKETS) {
          throw new TicketError(409, `عندك ${MAX_OPEN_TICKETS} تذاكر مفتوحة، استنى لما واحدة منهم تتقفل`);
        }

        let order: any = null;
        if (fields.orderId) {
          const orderRes = await db.query(
            `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND (client_id = $2 OR lawyer_id = $2) FOR UPDATE`,
            [fields.orderId, userId]
          );
          order = orderRes.rows[0];
          if (!order) throw new TicketError(404, 'الطلب غير موجود');
          const sameOrder = await db.query(`SELECT 1 FROM support_tickets WHERE order_id = $1 AND user_id = $2 AND status <> 'CLOSED'`, [order.id, userId]);
          if (sameOrder.rows.length > 0) throw new TicketError(409, 'عندك تذكرة مفتوحة على الطلب ده، كمل فيها');
        }
        if (category === 'ORDER' && !order) throw new TicketError(400, 'اختار الطلب اللي فيه المشكلة');

        const ticket = await db.query(
          'INSERT INTO support_tickets (user_id, category, title, order_id) VALUES ($1, $2, $3, $4) RETURNING *',
          [userId, category, title, order?.id ?? null]
        );
        const row = ticket.rows[0];
        await addMessage(db, row.id, 'USER', userId, fields.body ?? '', images);

        // A money problem on a running or just finished task holds the fees until the admin decides
        if (category === 'MONEY' && order && canFreezeFor(order)) {
          await freezePayout(db, order);
          const other = order.client_id === userId ? order.lawyer_id : order.client_id;
          await notify(db, other, 'مراجعة على طلب', `فيه مشكلة في الفلوس على طلب ${order.order_number}، والإدارة بتراجعها`, order.id);
        }

        return {
          status: 201,
          data: listItem({ ...row, order_number: order?.order_number ?? null }),
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
      `SELECT t.*, o.order_number FROM support_tickets t LEFT JOIN service_orders o ON o.id = t.order_id
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
        if (!ticket) throw new TicketError(404, 'التذكرة غير موجودة');
        if (ticket.status === 'CLOSED') throw new TicketError(409, 'التذكرة دي اتقفلت، لو عندك مشكلة جديدة افتح تذكرة جديدة');
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
