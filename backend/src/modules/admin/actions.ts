import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query } from '../../database/index.js';

export type AdminAction = 'ACCOUNT_SUSPEND' | 'ACCOUNT_ACTIVATE' | 'PRICE_UPDATE' | 'COMMISSION_UPDATE' | 'TAX_UPDATE' | 'LAWYER_APPROVE' | 'LAWYER_REJECT' | 'REVIEW_HIDE' | 'REVIEW_KEEP' | 'CONSULTATION_SETTINGS';

/// One line in the decisions log: who decided what, and on whom
export async function logAdminAction(actorId: string, action: AdminAction, label: string | null, details: string | null, targetUserId: string | null = null) {
  await query(
    'INSERT INTO admin_actions (action, target_label, target_user_id, details, created_by) VALUES ($1, $2, $3, $4, $5)',
    [action, label, targetUserId, details, actorId]
  );
}

export async function registerAdminActions(fastify: FastifyInstance) {
  // GET /api/v1/admin/actions - The latest decisions taken on the control page
  fastify.get('/actions', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT x.id, x.action, x.target_label, x.target_user_id, x.details, x.created_at, a.email AS created_by
       FROM admin_actions x LEFT JOIN users a ON a.id = x.created_by
       ORDER BY x.created_at DESC LIMIT 200`
    );
    return reply.send({ success: true, data: res.rows });
  });
}
