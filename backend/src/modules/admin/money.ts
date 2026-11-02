import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query } from '../../database/index.js';

const LIST_LIMIT = 200;
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/// The money page: what is frozen, every balance movement, and the freeze history
export async function registerAdminMoney(fastify: FastifyInstance) {
  // GET /api/v1/admin/money?from=YYYY-MM-DD&to=YYYY-MM-DD
  fastify.get('/money', async (request: FastifyRequest, reply: FastifyReply) => {
    const { from, to } = request.query as { from?: string; to?: string };
    if ((from && !DAY_PATTERN.test(from)) || (to && !DAY_PATTERN.test(to))) {
      return reply.status(400).send({ success: false, error: 'التاريخ غير صالح' });
    }
    // Days follow Cairo time, and an empty side leaves the range open
    const range = (column: string) => `
      ($1::date IS NULL OR ${column} >= ($1::date::timestamp AT TIME ZONE 'Africa/Cairo'))
      AND ($2::date IS NULL OR ${column} < (($2::date + 1)::timestamp AT TIME ZONE 'Africa/Cairo'))`;
    const days = [from || null, to || null];

    const movementsSql = `
      SELECT c.id, 'client' AS account_role, c.client_id AS user_id, c.amount, c.reason, c.created_at, c.order_id, c.created_by
      FROM client_credits c WHERE ${range('c.created_at')}
      UNION ALL
      SELECT j.id, 'lawyer', j.lawyer_id, j.amount, j.reason, j.created_at, j.order_id, j.created_by
      FROM lawyer_adjustments j WHERE ${range('j.created_at')}`;

    const [totals, frozen, movements, events] = await Promise.all([
      query(
        `SELECT
           (SELECT COALESCE(SUM(payout_amount), 0) FROM service_orders WHERE payout_status = 'FROZEN') AS frozen,
           (SELECT COALESCE(SUM(payout_amount), 0) FROM service_orders WHERE payout_status = 'HELD') AS held,
           COALESCE(SUM(m.amount) FILTER (WHERE m.amount > 0), 0) AS added,
           COALESCE(-SUM(m.amount) FILTER (WHERE m.amount < 0), 0) AS deducted
         FROM (${movementsSql}) m`, days),
      query(
        `SELECT o.id AS order_id, o.order_number, o.payout_amount,
                lp.full_name AS lawyer_name, COALESCE(c.full_name, c.phone) AS client_name,
                e.reason, e.created_at AS frozen_at,
                t.id AS ticket_id, t.reference AS ticket_reference
         FROM service_orders o
         JOIN users c ON c.id = o.client_id
         LEFT JOIN lawyer_profiles lp ON lp.user_id = o.lawyer_id
         LEFT JOIN LATERAL (
           SELECT reason, created_at FROM payout_events
           WHERE order_id = o.id AND action = 'FREEZE' ORDER BY created_at DESC LIMIT 1
         ) e ON TRUE
         LEFT JOIN LATERAL (
           SELECT id, reference FROM support_tickets
           WHERE order_id = o.id AND status <> 'CLOSED' ORDER BY created_at DESC LIMIT 1
         ) t ON TRUE
         WHERE o.payout_status = 'FROZEN'
         ORDER BY e.created_at ASC NULLS FIRST LIMIT $1`, [LIST_LIMIT]),
      query(
        `SELECT m.id, m.account_role, m.user_id, m.amount, m.reason, m.created_at, m.order_id, o.order_number,
                COALESCE(lp.full_name, u.full_name, u.phone) AS account_name, a.email AS created_by
         FROM (${movementsSql}) m
         JOIN users u ON u.id = m.user_id
         LEFT JOIN lawyer_profiles lp ON lp.user_id = m.user_id
         LEFT JOIN service_orders o ON o.id = m.order_id
         LEFT JOIN users a ON a.id = m.created_by
         ORDER BY m.created_at DESC LIMIT ${LIST_LIMIT}`, days),
      query(
        `SELECT e.id, e.action, e.amount, e.reason, e.created_at, e.order_id, o.order_number, a.email AS created_by
         FROM payout_events e
         JOIN service_orders o ON o.id = e.order_id
         LEFT JOIN users a ON a.id = e.created_by
         WHERE ${range('e.created_at')}
         ORDER BY e.created_at DESC LIMIT ${LIST_LIMIT}`, days),
    ]);

    return reply.send({
      success: true,
      data: { totals: totals.rows[0], frozen: frozen.rows, movements: movements.rows, events: events.rows },
    });
  });
}
