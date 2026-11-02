import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query } from '../../database/index.js';
import { notify } from '../lifecycle/service.js';
import { sanitizeText } from '../../utils/security.js';

const PAGE_LIMIT = 100;

/// Orders and complaints of one account, shown next to it wherever the control page lists it
export function userStats(id: string, prefix: string) {
  return `(SELECT COUNT(*)::int FROM service_orders x WHERE x.client_id = ${id} OR x.lawyer_id = ${id}) AS ${prefix}_orders,
          ((SELECT COUNT(*) FROM complaints x WHERE x.lawyer_id = ${id})
            + (SELECT COUNT(*) FROM lawyer_reports x WHERE x.client_id = ${id}))::int AS ${prefix}_against,
          ((SELECT COUNT(*) FROM complaints x WHERE x.client_id = ${id})
            + (SELECT COUNT(*) FROM lawyer_reports x WHERE x.lawyer_id = ${id}))::int AS ${prefix}_filed`;
}
const UUID_PATTERN = /^[0-9a-f-]{36}$/i;

/// Read side of the control page: accounts, orders, and everything linked to them
export async function registerAdminDirectory(fastify: FastifyInstance) {
  // GET /api/v1/admin/overview
  fastify.get('/overview', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(`
      SELECT
        (SELECT COUNT(*)::int FROM users WHERE role = 'client') AS clients,
        (SELECT COUNT(*)::int FROM users WHERE role = 'lawyer') AS lawyers,
        (SELECT COUNT(*)::int FROM lawyer_profiles WHERE is_available) AS available_lawyers,
        (SELECT COUNT(*)::int FROM lawyer_profiles WHERE urgent_status = 'PENDING') AS pending_lawyers,
        (SELECT COUNT(*)::int FROM service_orders WHERE status IN ('PENDING', 'ACCEPTED', 'ACTIVE')) AS open_orders,
        (SELECT COUNT(*)::int FROM service_orders WHERE status = 'COMPLETED') AS completed_orders,
        (SELECT COUNT(*)::int FROM complaints WHERE status = 'OPEN') AS open_complaints,
        (SELECT COUNT(*)::int FROM order_appeals WHERE status = 'OPEN') AS open_appeals,
        (SELECT COALESCE(SUM(price), 0) FROM service_orders WHERE status = 'COMPLETED') AS completed_value
    `);
    return reply.send({ success: true, data: res.rows[0] });
  });

  // GET /api/v1/admin/users?role=lawyer&q=
  fastify.get('/users', async (request: FastifyRequest, reply: FastifyReply) => {
    const { role, q } = request.query as { role?: string; q?: string };
    const search = `%${(q ?? '').trim()}%`;

    const res = await query(
      `SELECT u.id, u.role, u.status, u.phone, u.email, u.created_at, u.warnings_count,
              COALESCE(lp.full_name, u.full_name) AS full_name,
              lp.specialty, lp.syndicate_number, lp.rating, lp.reviews_count, lp.is_available, lp.urgent_status,
              (SELECT COUNT(*)::int FROM service_orders o WHERE o.client_id = u.id OR o.lawyer_id = u.id) AS orders_count,
              ${userStats('u.id', 'user')}
       FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
       WHERE u.role = $1
         AND (COALESCE(lp.full_name, u.full_name, '') ILIKE $2 OR u.phone ILIKE $2 OR u.email ILIKE $2 OR COALESCE(lp.syndicate_number, '') ILIKE $2)
       ORDER BY u.created_at DESC LIMIT $3`,
      [role === 'lawyer' ? 'lawyer' : 'client', search, PAGE_LIMIT]
    );
    return reply.send({ success: true, data: res.rows });
  });

  // GET /api/v1/admin/users/:id - Full profile
  fastify.get('/users/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });

    const userRes = await query(
      `SELECT u.id, u.role, u.status, u.phone, u.email, u.created_at, u.warnings_count,
              COALESCE(lp.full_name, u.full_name) AS full_name,
              COALESCE(lp.profile_photo_path, u.profile_photo_path) AS photo,
              lp.specialty, lp.bio, lp.syndicate_number, lp.rating, lp.reviews_count, lp.is_available,
              lp.availability_off_reason, lp.urgent_status, lp.last_location_updated_at, lp.suspended_until,
              ${userStats('u.id', 'user')}
       FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
       WHERE u.id = $1`,
      [id]
    );
    if (userRes.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });

    const [orders, reviews, complaints, strikes, credits] = await Promise.all([
      query(
        `SELECT id, order_number, status, price, problem_type, created_at FROM service_orders
         WHERE client_id = $1 OR lawyer_id = $1 ORDER BY created_at DESC LIMIT $2`,
        [id, PAGE_LIMIT]
      ),
      query(
        `SELECT r.rating, r.comment, r.created_at, r.is_hidden, o.order_number, o.id AS order_id
         FROM reviews r JOIN service_orders o ON o.id = r.order_id
         WHERE r.lawyer_id = $1 OR r.client_id = $1 ORDER BY r.created_at DESC LIMIT $2`,
        [id, PAGE_LIMIT]
      ),
      query(
        `SELECT c.reason, c.status, c.resolution, c.created_at, o.order_number, o.id AS order_id
         FROM complaints c JOIN service_orders o ON o.id = c.order_id
         WHERE c.lawyer_id = $1 OR c.client_id = $1 ORDER BY c.created_at DESC LIMIT $2`,
        [id, PAGE_LIMIT]
      ),
      query('SELECT kind, created_at FROM lawyer_strikes WHERE lawyer_id = $1 ORDER BY created_at DESC LIMIT $2', [id, PAGE_LIMIT]),
      query('SELECT amount, reason, created_at FROM client_credits WHERE client_id = $1 ORDER BY created_at DESC LIMIT $2', [id, PAGE_LIMIT]),
    ]);

    return reply.send({
      success: true,
      data: {
        user: userRes.rows[0],
        orders: orders.rows,
        reviews: reviews.rows,
        complaints: complaints.rows,
        strikes: strikes.rows,
        credits: credits.rows,
      },
    });
  });

  // POST /api/v1/admin/users/:id/status
  fastify.post('/users/:id/status', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const { suspend } = (request.body || {}) as { suspend?: boolean };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });

    const res = await query(
      `UPDATE users SET status = $1::user_status, updated_at = NOW() WHERE id = $2 AND role <> 'admin' RETURNING id`,
      [suspend ? 'suspended' : 'active', id]
    );
    if (res.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });

    if (suspend) {
      await query(`UPDATE lawyer_profiles SET is_available = FALSE, availability_off_reason = 'SUSPENDED' WHERE user_id = $1`, [id]);
    }
    await notify(
      dbPool,
      id,
      suspend ? 'تم إيقاف حسابك' : 'تم تفعيل حسابك',
      suspend ? 'تواصل مع الدعم لمعرفة التفاصيل' : 'تقدر تستخدم التطبيق دلوقتي'
    );
    return reply.send({ success: true, message: suspend ? 'تم إيقاف الحساب' : 'تم تفعيل الحساب' });
  });

  // GET /api/v1/admin/orders?q=&status=
  fastify.get('/orders', async (request: FastifyRequest, reply: FastifyReply) => {
    const { q, status } = request.query as { q?: string; status?: string };
    const search = `%${(q ?? '').trim()}%`;

    const res = await query(
      `SELECT o.id, o.order_number, o.status, o.price, o.problem_type, o.created_at,
              COALESCE(c.full_name, 'موكل') AS client_name, c.id AS client_id,
              lp.full_name AS lawyer_name, lp.user_id AS lawyer_id,
              ${userStats('o.client_id', 'client')}, ${userStats('o.lawyer_id', 'lawyer')}
       FROM service_orders o
       JOIN users c ON c.id = o.client_id
       JOIN lawyer_profiles lp ON lp.user_id = o.lawyer_id
       WHERE ($1::text = '' OR o.status = $1)
         AND (o.order_number ILIKE $2 OR COALESCE(c.full_name, '') ILIKE $2 OR c.phone ILIKE $2
              OR lp.full_name ILIKE $2 OR COALESCE(o.problem_type, '') ILIKE $2)
       ORDER BY o.created_at DESC LIMIT $3`,
      [sanitizeText(status ?? '', 30), search, PAGE_LIMIT]
    );
    return reply.send({ success: true, data: res.rows });
  });

  // GET /api/v1/admin/orders/:id - The whole life of an order
  fastify.get('/orders/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });

    const orderRes = await query(
      `SELECT o.*, COALESCE(c.full_name, 'موكل') AS client_name, c.phone AS client_phone, c.email AS client_email, l.email AS lawyer_email,
              lp.full_name AS lawyer_name, l.phone AS lawyer_phone,
              ${userStats('o.client_id', 'client')}, ${userStats('o.lawyer_id', 'lawyer')}
       FROM service_orders o
       JOIN users c ON c.id = o.client_id
       JOIN users l ON l.id = o.lawyer_id
       JOIN lawyer_profiles lp ON lp.user_id = o.lawyer_id
       WHERE o.id = $1`,
      [id]
    );
    if (orderRes.rows.length === 0) return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });

    const [logs, complaints, appeals, reviews] = await Promise.all([
      query('SELECT old_status, new_status, note, created_at FROM order_status_logs WHERE order_id = $1 ORDER BY created_at ASC', [id]),
      query('SELECT reason, status, resolution, refund_amount, admin_note, created_at FROM complaints WHERE order_id = $1 ORDER BY created_at DESC', [id]),
      query('SELECT reason, status, admin_note, created_at FROM order_appeals WHERE order_id = $1', [id]),
      query('SELECT rating, comment, created_at FROM reviews WHERE order_id = $1', [id]),
    ]);

    const { completion_code: _hidden, ...order } = orderRes.rows[0];
    return reply.send({
      success: true,
      data: { order, logs: logs.rows, complaints: complaints.rows, appeals: appeals.rows, reviews: reviews.rows },
    });
  });

  // GET /api/v1/admin/reports - Open reports the lawyers filed about clients
  fastify.get('/reports', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT r.id, r.reason, r.created_at, o.id AS order_id, o.order_number, o.status AS order_status, o.price,
              lp.full_name AS lawyer_name, l.phone AS lawyer_phone, l.email AS lawyer_email, r.lawyer_id,
              COALESCE(c.full_name, 'موكل') AS client_name, c.phone AS client_phone, c.email AS client_email, r.client_id,
              ${userStats('r.client_id', 'client')}, ${userStats('r.lawyer_id', 'lawyer')}
       FROM lawyer_reports r
       JOIN service_orders o ON o.id = r.order_id
       JOIN users l ON l.id = r.lawyer_id
       JOIN lawyer_profiles lp ON lp.user_id = r.lawyer_id
       JOIN users c ON c.id = r.client_id
       WHERE r.status = 'OPEN'
       ORDER BY r.created_at ASC LIMIT $1`,
      [PAGE_LIMIT]
    );
    return reply.send({ success: true, data: res.rows });
  });

  // GET /api/v1/admin/reviews
  fastify.get('/reviews', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at, r.is_hidden, o.order_number, o.id AS order_id,
              lp.full_name AS lawyer_name, lp.user_id AS lawyer_id
       FROM reviews r
       JOIN service_orders o ON o.id = r.order_id
       JOIN lawyer_profiles lp ON lp.user_id = r.lawyer_id
       ORDER BY r.created_at DESC LIMIT $1`,
      [PAGE_LIMIT]
    );
    return reply.send({ success: true, data: res.rows });
  });
}
