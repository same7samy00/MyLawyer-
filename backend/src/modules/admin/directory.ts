import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { notify } from '../lifecycle/service.js';
import { sanitizeText } from '../../utils/security.js';
import { addWarning, adjustBalance, applySettlement, evaluateSettlement, revokeWarning, SettlementOutcome } from '../lifecycle/settlement.js';

const PAGE_LIMIT = 100;

/// Orders and tickets of one account, shown next to it wherever the control page lists it
export function userStats(id: string, prefix: string) {
  return `(SELECT COUNT(*)::int FROM service_orders x WHERE x.client_id = ${id} OR x.lawyer_id = ${id}) AS ${prefix}_orders,
          (SELECT COUNT(*) FROM support_tickets st JOIN service_orders so ON so.id = st.order_id
              WHERE st.user_id <> ${id} AND (so.client_id = ${id} OR so.lawyer_id = ${id}))::int AS ${prefix}_against,
          (SELECT COUNT(*) FROM support_tickets st WHERE st.user_id = ${id})::int AS ${prefix}_filed`;
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
        (SELECT COUNT(*)::int FROM support_tickets WHERE status = 'UNDER_REVIEW') AS waiting_tickets,
        (SELECT COUNT(*)::int FROM support_tickets WHERE status = 'OPEN') AS open_tickets,
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

    const [orders, reviews, tickets, strikes, credits, warnings, adjustments, wallet] = await Promise.all([
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
        `SELECT t.id, t.reference, t.title, t.category, t.status, t.created_at, o.order_number
         FROM support_tickets t LEFT JOIN service_orders o ON o.id = t.order_id
         WHERE t.user_id = $1 ORDER BY t.created_at DESC LIMIT $2`,
        [id, PAGE_LIMIT]
      ),
      query('SELECT kind, created_at FROM lawyer_strikes WHERE lawyer_id = $1 ORDER BY created_at DESC LIMIT $2', [id, PAGE_LIMIT]),
      query(
        `SELECT c.amount, c.reason, c.created_at, o.order_number, a.email AS created_by
         FROM client_credits c LEFT JOIN service_orders o ON o.id = c.order_id LEFT JOIN users a ON a.id = c.created_by
         WHERE c.client_id = $1 ORDER BY c.created_at DESC LIMIT $2`, [id, PAGE_LIMIT]),
      query(
        `SELECT w.id, w.reason, w.created_at, w.revoked_at, o.order_number, a.email AS created_by
         FROM account_warnings w LEFT JOIN service_orders o ON o.id = w.order_id LEFT JOIN users a ON a.id = w.created_by
         WHERE w.user_id = $1 ORDER BY w.created_at DESC LIMIT $2`, [id, PAGE_LIMIT]),
      query(
        `SELECT j.amount, j.reason, j.created_at, o.order_number, a.email AS created_by
         FROM lawyer_adjustments j LEFT JOIN service_orders o ON o.id = j.order_id LEFT JOIN users a ON a.id = j.created_by
         WHERE j.lawyer_id = $1 ORDER BY j.created_at DESC LIMIT $2`, [id, PAGE_LIMIT]),
      query(
        `SELECT
           (SELECT COALESCE(SUM(amount), 0) FROM client_credits WHERE client_id = $1) AS client_balance,
           (SELECT COALESCE(SUM(payout_amount), 0) FROM service_orders WHERE lawyer_id = $1 AND payout_status = 'HELD') AS held,
           (SELECT COALESCE(SUM(payout_amount), 0) FROM service_orders WHERE lawyer_id = $1 AND payout_status = 'FROZEN') AS frozen,
           (SELECT COALESCE(SUM(payout_amount), 0) FROM service_orders WHERE lawyer_id = $1 AND payout_status = 'AVAILABLE')
             + (SELECT COALESCE(SUM(amount), 0) FROM lawyer_adjustments WHERE lawyer_id = $1) AS available`, [id]),
    ]);

    return reply.send({
      success: true,
      data: {
        user: userRes.rows[0],
        orders: orders.rows,
        reviews: reviews.rows,
        tickets: tickets.rows,
        strikes: strikes.rows,
        credits: credits.rows,
        warnings: warnings.rows,
        adjustments: adjustments.rows,
        wallet: wallet.rows[0],
      },
    });
  });

  // POST /api/v1/admin/users/:id/status
  fastify.post('/users/:id/status', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const { suspend } = (request.body || {}) as { suspend?: boolean };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });

    const res = await query(
      `UPDATE users SET status = $1::user_status, suspended_until = NULL, updated_at = NOW() WHERE id = $2 AND role <> 'admin' RETURNING id`,
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

    const [logs, tickets, appeals, reviews] = await Promise.all([
      query('SELECT old_status, new_status, note, created_at FROM order_status_logs WHERE order_id = $1 ORDER BY created_at ASC', [id]),
      query(`SELECT t.id, t.reference, t.title, t.category, t.status, t.created_at, u.role AS user_role
             FROM support_tickets t JOIN users u ON u.id = t.user_id WHERE t.order_id = $1 ORDER BY t.created_at DESC`, [id]),
      query('SELECT reason, status, admin_note, created_at FROM order_appeals WHERE order_id = $1', [id]),
      query('SELECT rating, comment, created_at FROM reviews WHERE order_id = $1', [id]),
    ]);

    const { completion_code: _hidden, ...order } = orderRes.rows[0];
    return reply.send({
      success: true,
      data: { order, logs: logs.rows, tickets: tickets.rows, appeals: appeals.rows, reviews: reviews.rows },
    });
  });

  // GET /api/v1/admin/orders/:id/settlement - The fixed decision for an order and the facts behind it
  fastify.get('/orders/:id/settlement', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    const res = await query('SELECT * FROM service_orders WHERE id = $1', [id]);
    if (res.rows.length === 0) return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });

    const order = res.rows[0];
    const settlement = await evaluateSettlement(dbPool, order);
    return reply.send({
      success: true,
      data: { ...settlement, price: Number(order.price), status: order.status, payoutStatus: order.payout_status, open: order.status === 'ACTIVE' || ['HELD', 'FROZEN'].includes(order.payout_status) },
    });
  });

  // POST /api/v1/admin/orders/:id/settle - Applies the fixed decision, or another one the admin chose
  fastify.post('/orders/:id/settle', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { outcome?: string; note?: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    if (body.outcome && !['REFUND', 'LAWYER', 'SPLIT'].includes(body.outcome)) {
      return reply.status(400).send({ success: false, error: 'القرار غير صالح' });
    }

    const result = await withTransaction(async (client) => {
      const res = await client.query('SELECT * FROM service_orders WHERE id = $1 FOR UPDATE', [id]);
      const order = res.rows[0];
      if (!order || !['ACTIVE', 'COMPLETED', 'EXPIRED'].includes(order.status) || order.payout_status === 'REFUNDED') return null;
      if (order.status === 'COMPLETED' && order.payout_status !== 'HELD' && order.payout_status !== 'FROZEN') return null;
      const outcome = (body.outcome as SettlementOutcome) || (await evaluateSettlement(client, order)).outcome;
      return applySettlement(client, order, outcome, adminId, body.note ? sanitizeText(body.note, 1000) : '');
    });
    if (!result) return reply.status(409).send({ success: false, error: 'تمت تسوية هذا الطلب من قبل' });
    return reply.send({ success: true, message: 'تم تنفيذ القرار', data: result });
  });

  // POST /api/v1/admin/users/:id/balance - Adds to or deducts from a balance with a reason
  fastify.post('/users/:id/balance', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { amount?: number; reason?: string; orderNumber?: string };
    const amount = Math.round(Number(body.amount) * 100) / 100;
    const reason = sanitizeText(body.reason || '', 500).trim();

    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    if (!Number.isFinite(amount) || amount === 0 || Math.abs(amount) > 100000) {
      return reply.status(400).send({ success: false, error: 'أدخل مبلغًا صحيحًا غير الصفر' });
    }
    if (reason.length < 5) return reply.status(400).send({ success: false, error: 'اكتب سبب الحركة' });

    const userRes = await query(`SELECT id, role FROM users WHERE id = $1 AND role IN ('client', 'lawyer')`, [id]);
    if (userRes.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });

    let orderId: string | null = null;
    if (body.orderNumber) {
      const orderRes = await query('SELECT id FROM service_orders WHERE order_number = $1 AND (client_id = $2 OR lawyer_id = $2)', [body.orderNumber.trim(), id]);
      if (orderRes.rows.length === 0) return reply.status(400).send({ success: false, error: 'رقم الطلب غير مرتبط بهذا الحساب' });
      orderId = orderRes.rows[0].id;
    }

    await adjustBalance(dbPool, userRes.rows[0], amount, reason, orderId, adminId);
    return reply.send({ success: true, message: amount > 0 ? 'تمت إضافة المبلغ' : 'تم خصم المبلغ' });
  });

  // POST /api/v1/admin/users/:id/warnings - A manual warning with its reason
  fastify.post('/users/:id/warnings', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const reason = sanitizeText(((request.body || {}) as { reason?: string }).reason || '', 500).trim();
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    if (reason.length < 5) return reply.status(400).send({ success: false, error: 'اكتب سبب الإنذار' });

    const userRes = await query(`SELECT id FROM users WHERE id = $1 AND role IN ('client', 'lawyer')`, [id]);
    if (userRes.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });
    await addWarning(dbPool, id, reason, null, adminId);
    return reply.send({ success: true, message: 'تم توجيه الإنذار' });
  });

  // POST /api/v1/admin/warnings/:id/revoke
  fastify.post('/warnings/:id/revoke', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    const done = await revokeWarning(dbPool, id, adminId);
    if (!done) return reply.status(404).send({ success: false, error: 'الإنذار غير موجود أو أُلغي من قبل' });
    return reply.send({ success: true, message: 'تم إلغاء الإنذار' });
  });

  // POST /api/v1/admin/orders/:id/freeze - Stops or releases one order's fees
  fastify.post('/orders/:id/freeze', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const freeze = Boolean(((request.body || {}) as { freeze?: boolean }).freeze);
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });

    const res = freeze
      ? await query(`UPDATE service_orders SET payout_status = 'FROZEN' WHERE id = $1 AND payout_status IN ('HELD', 'AVAILABLE') RETURNING lawyer_id`, [id])
      : await query(
        `UPDATE service_orders SET payout_status = CASE WHEN hold_until > NOW() THEN 'HELD' ELSE 'AVAILABLE' END
         WHERE id = $1 AND payout_status = 'FROZEN' RETURNING lawyer_id`, [id]);
    if (res.rows.length === 0) return reply.status(409).send({ success: false, error: 'لا يمكن تنفيذ ذلك على أتعاب هذا الطلب الآن' });

    await notify(dbPool, res.rows[0].lawyer_id, freeze ? 'تجميد أتعاب' : 'فك تجميد الأتعاب',
      freeze ? 'الإدارة جمدت أتعاب طلب لحين المراجعة' : 'الإدارة فكت تجميد أتعاب طلب', id);
    return reply.send({ success: true, message: freeze ? 'تم تجميد الأتعاب' : 'تم فك تجميد الأتعاب' });
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
