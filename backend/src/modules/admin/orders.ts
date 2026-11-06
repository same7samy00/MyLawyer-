import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { notify } from '../lifecycle/service.js';
import { sanitizeText } from '../../utils/security.js';
import { UUID_PATTERN } from '../../utils/http.js';
import { applySettlement, evaluateSettlement, logPayoutEvent, SettlementOutcome } from '../lifecycle/settlement.js';
import { PAGE_LIMIT, userStats } from './directory.js';

/// Orders on the control page: the list, one order's life, settlement and frozen fees
export async function registerAdminOrders(fastify: FastifyInstance) {
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
              c.profile_photo_path AS client_photo, COALESCE(lp.profile_photo_path, l.profile_photo_path) AS lawyer_photo,
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

    const [offers, logs, tickets, reviews, movements, events, payments] = await Promise.all([
      query(`SELECT ro.lawyer_id, ro.price, ro.lawyer_amount, ro.withdrawn_at, ro.created_at, lp.full_name AS lawyer_name
             FROM service_requests r
             JOIN request_offers ro ON ro.request_id = r.id
             JOIN lawyer_profiles lp ON lp.user_id = ro.lawyer_id
             WHERE r.order_id = $1 ORDER BY ro.created_at ASC`, [id]),
      query(`SELECT l.old_status, l.new_status, l.note, l.created_at, u.role AS actor_role
             FROM order_status_logs l LEFT JOIN users u ON u.id = l.changed_by_user_id
             WHERE l.order_id = $1 ORDER BY l.created_at ASC`, [id]),
      query(`SELECT t.id, t.reference, t.title, t.category, t.status, t.created_at, u.role AS user_role
             FROM support_tickets t JOIN users u ON u.id = t.user_id WHERE t.order_id = $1 ORDER BY t.created_at DESC`, [id]),
      query('SELECT rating, comment, created_at FROM reviews WHERE order_id = $1', [id]),
      query(
        `SELECT m.amount, m.reason, m.created_at, m.account_role, COALESCE(lp.full_name, u.full_name, u.phone) AS account_name, a.email AS created_by
         FROM (
           SELECT client_id AS user_id, 'client' AS account_role, amount, reason, created_at, created_by FROM client_credits WHERE order_id = $1
           UNION ALL
           SELECT lawyer_id, 'lawyer', amount, reason, created_at, created_by FROM lawyer_adjustments WHERE order_id = $1
         ) m
         JOIN users u ON u.id = m.user_id
         LEFT JOIN lawyer_profiles lp ON lp.user_id = m.user_id
         LEFT JOIN users a ON a.id = m.created_by
         ORDER BY m.created_at DESC`, [id]),
      query(
        `SELECT e.action, e.amount, e.reason, e.created_at, a.email AS created_by
         FROM payout_events e LEFT JOIN users a ON a.id = e.created_by
         WHERE e.order_id = $1 ORDER BY e.created_at DESC`, [id]),
      query('SELECT reference, amount, method, paid_at FROM payments WHERE order_id = $1', [id]),
    ]);

    const { completion_code: _hidden, ...order } = orderRes.rows[0];
    return reply.send({
      success: true,
      data: { order, offers: offers.rows, logs: logs.rows, tickets: tickets.rows, reviews: reviews.rows, movements: movements.rows, events: events.rows, payment: payments.rows[0] ?? null },
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
    if (body.outcome && !['REFUND', 'LAWYER'].includes(body.outcome)) {
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

  // POST /api/v1/admin/orders/:id/freeze - Stops or releases one order's fees
  fastify.post('/orders/:id/freeze', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const freeze = Boolean(((request.body || {}) as { freeze?: boolean }).freeze);
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });

    const res = freeze
      ? await query(`UPDATE service_orders SET payout_status = 'FROZEN' WHERE id = $1 AND payout_status IN ('HELD', 'AVAILABLE') RETURNING lawyer_id, payout_amount`, [id])
      : await query(
        `UPDATE service_orders SET payout_status = CASE WHEN hold_until > NOW() THEN 'HELD' ELSE 'AVAILABLE' END
         WHERE id = $1 AND payout_status = 'FROZEN' RETURNING lawyer_id, payout_amount`, [id]);
    if (res.rows.length === 0) return reply.status(409).send({ success: false, error: 'لا يمكن تنفيذ ذلك على أتعاب هذا الطلب الآن' });

    await logPayoutEvent(dbPool, id, freeze ? 'FREEZE' : 'UNFREEZE', Number(res.rows[0].payout_amount || 0), 'إجراء من الإدارة', adminId);
    await notify(dbPool, res.rows[0].lawyer_id, freeze ? 'أتعابك اتجمدت' : 'التجميد اتفك',
      freeze ? 'أتعاب طلب، لحد قرار الإدارة' : 'أتعاب الطلب رجعتلك', id);
    return reply.send({ success: true, message: freeze ? 'تم تجميد الأتعاب' : 'تم فك تجميد الأتعاب' });
  });

}
