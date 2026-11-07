import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query } from '../../database/index.js';
import { AuthenticatedUser, requireAuth } from '../../utils/http.js';

export async function notificationRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());

  // POST /api/v1/notifications/device-token - Phone that receives push notifications
  fastify.post('/device-token', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as { token?: string; platform?: string };
    const token = body.token?.trim();

    if (!token || token.length > 4096) {
      return reply.status(400).send({ success: false, error: 'رمز الجهاز غير صالح' });
    }

    await query(
      `INSERT INTO device_tokens (token, user_id, platform) VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, updated_at = NOW()`,
      [token, userId, body.platform === 'ios' ? 'ios' : 'android']
    );

    return reply.send({ success: true });
  });

  // POST /api/v1/notifications/device-token/remove - Stop notifications on this phone
  fastify.post('/device-token/remove', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as { token?: string };

    await query('DELETE FROM device_tokens WHERE token = $1 AND user_id = $2', [body.token ?? '', userId]);
    return reply.send({ success: true });
  });

  // GET /api/v1/notifications - Latest notifications for the current user
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const res = await query(
      `SELECT id, title, body, order_id, ticket_id, request_id, consultation_id, read_at, created_at
       FROM notifications WHERE user_id = $1
       ORDER BY created_at DESC LIMIT 50`,
      [userId]
    );

    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        id: row.id,
        title: row.title,
        body: row.body,
        orderId: row.order_id,
        ticketId: row.ticket_id,
        requestId: row.request_id,
        consultationId: row.consultation_id,
        isRead: row.read_at !== null,
        createdAt: row.created_at,
      })),
    });
  });

  // GET /api/v1/notifications/summary - Badge counts
  fastify.get('/summary', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const unreadRes = await query(
      'SELECT COUNT(*)::int AS total FROM notifications WHERE user_id = $1 AND read_at IS NULL',
      [userId]
    );
    const ordersRes = await query(
      `SELECT COUNT(*)::int AS total FROM service_orders
       WHERE ${role === 'lawyer' ? "lawyer_id = $1 AND status = 'PENDING'" : "client_id = $1 AND status IN ('ACCEPTED', 'ACTIVE')"}`,
      [userId]
    );

    // A request waiting for this lawyer's price counts like a new order
    const requestsRes = role === 'lawyer'
      ? await query(
          `SELECT COUNT(*)::int AS total FROM request_recipients rr
           JOIN service_requests r ON r.id = rr.request_id
           WHERE rr.lawyer_id = $1 AND r.status = 'OPEN' AND rr.round = r.round AND r.round_deadline > NOW()
             AND NOT EXISTS (SELECT 1 FROM request_offers ro WHERE ro.request_id = r.id AND ro.lawyer_id = $1 AND ro.withdrawn_at IS NULL)`,
          [userId]
        )
      : null;

    const availabilityRes = role === 'lawyer'
      ? await query('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [userId])
      : null;

    return reply.send({
      success: true,
      data: {
        unread: unreadRes.rows[0].total,
        pendingOrders: ordersRes.rows[0].total + (requestsRes?.rows[0].total ?? 0),
        isAvailable: availabilityRes?.rows[0]?.is_available,
      },
    });
  });

  // POST /api/v1/notifications/read - Marks one notification, or those of the order or ticket a push opened
  fastify.post('/read', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as { id?: string; orderId?: string; ticketId?: string; requestId?: string; consultationId?: string };
    if (!body.id && !body.orderId && !body.ticketId && !body.requestId && !body.consultationId) return reply.status(400).send({ success: false, error: 'الإشعار غير محدد' });
    await query(
      `UPDATE notifications SET read_at = NOW()
       WHERE user_id = $1 AND read_at IS NULL
         AND (id::text = $2 OR order_id::text = $3 OR ticket_id::text = $4 OR request_id::text = $5 OR consultation_id::text = $6)`,
      [userId, body.id ?? null, body.orderId ?? null, body.ticketId ?? null, body.requestId ?? null, body.consultationId ?? null]
    );
    return reply.send({ success: true });
  });

  // POST /api/v1/notifications/read-all
  fastify.post('/read-all', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    await query('UPDATE notifications SET read_at = NOW() WHERE user_id = $1 AND read_at IS NULL', [userId]);
    return reply.send({ success: true });
  });
}
