import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query } from '../../database/index.js';

export const PAGE_LIMIT = 100;
const SEARCH_LIMIT = 6;

/// Orders and tickets of one account, shown next to it wherever the control page lists it
export function userStats(id: string, prefix: string) {
  return `(SELECT COUNT(*)::int FROM service_orders x WHERE x.client_id = ${id} OR x.lawyer_id = ${id}) AS ${prefix}_orders,
          (SELECT COUNT(*) FROM support_tickets st JOIN service_orders so ON so.id = st.order_id
              WHERE st.user_id <> ${id} AND (so.client_id = ${id} OR so.lawyer_id = ${id}))::int AS ${prefix}_against,
          (SELECT COUNT(*) FROM support_tickets st WHERE st.user_id = ${id})::int AS ${prefix}_filed`;
}

/// The control page's front: counts, the one search box, and every review
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
        (SELECT COUNT(*)::int FROM consultations WHERE status IN ('PAID', 'CONTACTING')) AS waiting_consultations,
        (SELECT COUNT(*)::int FROM support_tickets WHERE status = 'OPEN') AS open_tickets,
        (SELECT COUNT(*)::int FROM reviews WHERE reported_at IS NOT NULL AND is_hidden = FALSE) AS reported_reviews,
        (SELECT COUNT(*)::int FROM service_orders WHERE payout_status = 'FROZEN') AS frozen_orders,
        (SELECT COALESCE(SUM(price), 0) FROM service_orders WHERE status = 'COMPLETED') AS completed_value,
        (SELECT COUNT(*)::int FROM lawyer_profiles WHERE urgent_status = 'APPROVED') AS service_lawyers,
        (SELECT COUNT(*)::int FROM service_orders) AS total_orders,
        (SELECT COUNT(*)::int FROM service_orders WHERE status = 'CANCELLED') AS cancelled_orders,
        (SELECT COALESCE(SUM(amount), 0) FROM payments) AS total_paid,
        (SELECT COALESCE(SUM(payout_amount), 0) FROM service_orders WHERE payout_status = 'FROZEN') AS frozen_value,
        (SELECT COUNT(*)::int FROM reviews) AS total_reviews,
        (SELECT COALESCE(AVG(rating), 0) FROM reviews) AS average_rating
    `);
    return reply.send({ success: true, data: res.rows[0] });
  });

  // GET /api/v1/admin/search?q= - One search over accounts, orders and tickets for the top header
  fastify.get('/search', async (request: FastifyRequest, reply: FastifyReply) => {
    const q = ((request.query as { q?: string }).q ?? '').trim().slice(0, 100);
    if (q.length < 2) return reply.send({ success: true, data: { users: [], orders: [], tickets: [] } });
    const pattern = `%${q.replace(/[\\%_]/g, '\\$&')}%`;

    const [users, orders, tickets] = await Promise.all([
      query(
        `SELECT u.id, u.role, u.phone, COALESCE(lp.full_name, u.full_name, u.phone) AS name
         FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
         WHERE u.role IN ('client', 'lawyer')
           AND (COALESCE(lp.full_name, u.full_name, '') ILIKE $1 OR u.phone ILIKE $1 OR u.email ILIKE $1)
         ORDER BY u.created_at DESC LIMIT $2`, [pattern, SEARCH_LIMIT]),
      query(
        `SELECT o.id, o.order_number, o.status, COALESCE(c.full_name, c.phone) AS client_name, lp.full_name AS lawyer_name
         FROM service_orders o
         JOIN users c ON c.id = o.client_id
         LEFT JOIN lawyer_profiles lp ON lp.user_id = o.lawyer_id
         WHERE o.order_number ILIKE $1 OR COALESCE(c.full_name, '') ILIKE $1 OR c.phone ILIKE $1 OR COALESCE(lp.full_name, '') ILIKE $1
         ORDER BY o.created_at DESC LIMIT $2`, [pattern, SEARCH_LIMIT]),
      query(
        `SELECT t.id, t.reference, t.title, t.status
         FROM support_tickets t
         WHERE t.reference ILIKE $1 OR t.title ILIKE $1
         ORDER BY t.created_at DESC LIMIT $2`, [pattern, SEARCH_LIMIT]),
    ]);
    return reply.send({ success: true, data: { users: users.rows, orders: orders.rows, tickets: tickets.rows } });
  });

  // GET /api/v1/admin/reviews
  fastify.get('/reviews', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at, r.is_hidden, o.order_number, o.id AS order_id,
              lp.full_name AS lawyer_name, lp.user_id AS lawyer_id,
              COALESCE(c.full_name, c.phone) AS client_name, c.phone AS client_phone, o.client_id, r.reported_at, r.report_reason
       FROM reviews r
       JOIN service_orders o ON o.id = r.order_id
       JOIN lawyer_profiles lp ON lp.user_id = r.lawyer_id
       JOIN users c ON c.id = o.client_id
       ORDER BY r.created_at DESC LIMIT $1`,
      [PAGE_LIMIT]
    );
    return reply.send({ success: true, data: res.rows });
  });
}
