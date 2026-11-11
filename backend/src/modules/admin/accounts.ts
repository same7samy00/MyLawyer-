import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query } from '../../database/index.js';
import { notify, revokeLawyerStrike } from '../lifecycle/service.js';
import { sanitizeText } from '../../utils/security.js';
import { UUID_PATTERN } from '../../utils/http.js';
import { logAdminAction } from './actions.js';
import { forgetActive } from '../../services/fastMemory.js';
import { addWarning, adjustBalance, revokeWarning } from '../lifecycle/settlement.js';
import { PAGE_LIMIT, userStats } from './directory.js';

/// Accounts on the control page: profiles, suspension, balance, warnings and strikes
export async function registerAdminAccounts(fastify: FastifyInstance) {
  // GET /api/v1/admin/users?role=lawyer&q=
  fastify.get('/users', async (request: FastifyRequest, reply: FastifyReply) => {
    const { role, q } = request.query as { role?: string; q?: string };
    const search = `%${(q ?? '').trim()}%`;

    const res = await query(
      `SELECT u.id, u.role, u.status, u.phone, u.email, u.created_at, u.warnings_count, u.is_review_account,
              COALESCE(lp.full_name, u.full_name) AS full_name,
              COALESCE(lp.profile_photo_path, u.profile_photo_path) AS photo,
              lp.experience_years, lp.syndicate_number, lp.rating, lp.reviews_count, lp.is_available, lp.urgent_status,
              u.suspended_until AS account_suspended_until, lp.suspended_until,
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
      `SELECT u.id, u.role, u.status, u.phone, u.email, u.created_at, u.warnings_count, u.is_review_account, u.suspended_until AS account_suspended_until,
              COALESCE(lp.full_name, u.full_name) AS full_name,
              COALESCE(lp.profile_photo_path, u.profile_photo_path) AS photo,
              lp.experience_years, lp.syndicate_number, lp.rating, lp.reviews_count, lp.is_available,
              lp.availability_off_reason, lp.urgent_status, lp.last_location_updated_at, lp.suspended_until,
              card.id AS card_id, card.mime_type AS card_mime,
              ${userStats('u.id', 'user')}
       FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
       LEFT JOIN LATERAL (
         SELECT id, mime_type FROM lawyer_documents d
         WHERE d.lawyer_profile_id = lp.id AND d.document_type = 'syndicate_card' AND d.is_current
         ORDER BY uploaded_at DESC LIMIT 1
       ) card ON TRUE
       WHERE u.id = $1`,
      [id]
    );
    if (userRes.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });

    const [orders, reviews, tickets, strikes, credits, warnings, adjustments, wallet, payments] = await Promise.all([
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
      query(
        `SELECT s.id, s.kind, s.created_at, s.revoked_at, o.order_number
         FROM lawyer_strikes s LEFT JOIN service_orders o ON o.id = s.order_id
         WHERE s.lawyer_id = $1 ORDER BY s.created_at DESC LIMIT $2`, [id, PAGE_LIMIT]),
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
      query(
        `SELECT p.reference, p.amount, p.method, p.paid_at, p.order_id, o.order_number, o.status AS order_status, o.payout_status
         FROM payments p JOIN service_orders o ON o.id = p.order_id
         WHERE p.client_id = $1 ORDER BY p.paid_at DESC LIMIT $2`, [id, PAGE_LIMIT]),
    ]);

    return reply.send({
      success: true,
      data: {
        user: userRes.rows[0],
        orders: orders.rows,
        reviews: reviews.rows,
        tickets: tickets.rows,
        strikes: strikes.rows,
        payments: payments.rows,
        credits: credits.rows,
        warnings: warnings.rows,
        adjustments: adjustments.rows,
        wallet: wallet.rows[0],
      },
    });
  });

  // POST /api/v1/admin/users/:id/status
  fastify.post('/users/:id/status', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const { suspend } = (request.body || {}) as { suspend?: boolean };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    // Google's reviewers sign in with this account: suspending it gets the app refused
    const review = await query('SELECT is_review_account FROM users WHERE id = $1', [id]);
    if (suspend && review.rows[0]?.is_review_account) return reply.status(409).send({ success: false, error: 'ده حساب مراجعة جوجل، وإيقافه بيخلي جوجل ترفض التطبيق' });

    const res = await query(
      `UPDATE users SET status = $1::user_status, suspended_until = NULL, updated_at = NOW() WHERE id = $2 AND role <> 'admin' RETURNING id, COALESCE(full_name, phone) AS label`,
      [suspend ? 'suspended' : 'active', id]
    );
    if (res.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });

    // The suspension holds from the very next request
    if (suspend) await forgetActive(id);
    await logAdminAction(adminId, suspend ? 'ACCOUNT_SUSPEND' : 'ACCOUNT_ACTIVATE', res.rows[0].label, null, id);

    if (suspend) {
      await query(`UPDATE lawyer_profiles SET is_available = FALSE, availability_off_reason = 'SUSPENDED' WHERE user_id = $1`, [id]);
    } else {
      await query(
        `UPDATE lawyer_profiles SET suspended_until = NULL,
           availability_off_reason = CASE WHEN availability_off_reason = 'SUSPENDED' THEN NULL ELSE availability_off_reason END
         WHERE user_id = $1`,
        [id]
      );
    }
    await notify(
      dbPool,
      id,
      suspend ? 'حسابك اتوقف' : 'حسابك اتفعّل',
      suspend ? 'كلم الدعم الفني لمعرفة السبب' : 'تقدر تستخدم التطبيق'
    );
    return reply.send({ success: true, message: suspend ? 'تم إيقاف الحساب' : 'تم تفعيل الحساب' });
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
      return reply.status(400).send({ success: false, error: 'أدخل مبلغًا صحيحًا غير الصفر، والحد الأقصى للعملية الواحدة 100,000 ج.م' });
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
    const body = (request.body || {}) as { reason?: string; orderNumber?: string };
    const reason = sanitizeText(body.reason || '', 500).trim();
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    if (reason.length < 5) return reply.status(400).send({ success: false, error: 'اكتب سبب الإنذار' });

    const userRes = await query(`SELECT id FROM users WHERE id = $1 AND role IN ('client', 'lawyer')`, [id]);
    if (userRes.rows.length === 0) return reply.status(404).send({ success: false, error: 'الحساب غير موجود' });

    let orderId: string | null = null;
    if (body.orderNumber) {
      const orderRes = await query('SELECT id FROM service_orders WHERE order_number = $1 AND (client_id = $2 OR lawyer_id = $2)', [String(body.orderNumber).trim(), id]);
      if (orderRes.rows.length === 0) return reply.status(400).send({ success: false, error: 'رقم الطلب غير مرتبط بهذا الحساب' });
      orderId = orderRes.rows[0].id;
    }

    await addWarning(dbPool, id, reason, orderId, adminId);
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

  // POST /api/v1/admin/strikes/:id/revoke - Cancels a lawyer's strike, and its suspension if it no longer applies
  fastify.post('/strikes/:id/revoke', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    const done = await revokeLawyerStrike(dbPool, id, adminId);
    if (!done) return reply.status(404).send({ success: false, error: 'المخالفة غير موجودة أو أُلغيت من قبل' });
    return reply.send({ success: true, message: 'تم إلغاء المخالفة' });
  });

}
