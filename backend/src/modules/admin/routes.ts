import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { registerAdminDirectory, userStats } from './directory.js';
import { registerAdminSupport } from '../support/admin.js';
import { sanitizeText } from '../../utils/security.js';
import { addClientCredit, notify, refreshLawyerRating, warnClient } from '../lifecycle/service.js';

export async function adminRoutes(fastify: FastifyInstance) {
  // Strict admin authorization hook
  fastify.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
      const { role } = request.user as { role: string };
      if (role !== 'admin') {
        return reply.status(403).send({ success: false, error: 'غير مصرح: هذه العمليات تتطلب صلاحيات إدارة النظام' });
      }
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول كمسؤول' });
    }
  });

  await registerAdminDirectory(fastify);
  await registerAdminSupport(fastify);

  // GET /api/v1/admin/appeals
  fastify.get('/appeals', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT a.id, a.reference, a.reason, a.created_at, o.id as order_id, o.order_number, o.price, o.service_title,
              lp.full_name as lawyer_name, a.lawyer_id, lu.phone as lawyer_phone, lu.email as lawyer_email,
              ${userStats('a.lawyer_id', 'lawyer')}
       FROM order_appeals a
       JOIN service_orders o ON o.id = a.order_id
       JOIN users lu ON lu.id = a.lawyer_id
       JOIN lawyer_profiles lp ON lp.user_id = a.lawyer_id
       WHERE a.status = 'OPEN' ORDER BY a.created_at ASC`
    );
    return reply.send({ success: true, data: res.rows });
  });

  // POST /api/v1/admin/appeals/:id/resolve - Approval moves the refund back to the lawyer
  fastify.post('/appeals/:id/resolve', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { approve?: boolean; note?: string };

    const appealRes = await query(
      `SELECT a.*, o.price, o.lawyer_amount, o.client_id FROM order_appeals a
       JOIN service_orders o ON o.id = a.order_id
       WHERE a.id::text = $1 AND a.status = 'OPEN'`,
      [id]
    );
    if (appealRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الاعتراض غير موجود أو تم الفصل فيه' });
    }

    const appeal = appealRes.rows[0];
    const approved = body.approve === true;

    await withTransaction(async (client) => {
      await client.query(
        `UPDATE order_appeals SET status = $1, admin_note = $2, resolved_by = $3, resolved_at = NOW() WHERE id = $4`,
        [approved ? 'APPROVED' : 'DENIED', body.note ? sanitizeText(body.note, 1000) : null, adminId, appeal.id]
      );

      if (approved) {
        const price = Number(appeal.price);
        await client.query(
          `UPDATE service_orders
           SET status = 'COMPLETED', completed_at = NOW(), payout_status = 'AVAILABLE', payout_amount = $1
           WHERE id = $2`,
          [Number(appeal.lawyer_amount), appeal.order_id]
        );
        await addClientCredit(client, appeal.client_id, appeal.order_id, -price, 'إلغاء رد بعد مراجعة اعتراض المحامي');
        await notify(client, appeal.client_id, 'تعديل على رصيدك', 'أثبتت الإدارة تنفيذ المهمة وتم خصم المبلغ المرتجع', appeal.order_id);
        await warnClient(client, appeal.client_id);
      }

      await notify(client, appeal.lawyer_id, 'قرار الاعتراض', approved ? 'تم قبول اعتراضك وإضافة الأتعاب' : 'تم رفض اعتراضك', appeal.order_id);
    });

    return reply.send({ success: true, message: 'تم تسجيل القرار' });
  });

  // GET /api/v1/admin/prices
  fastify.get('/prices', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query('SELECT problem_type, min_price, max_price, commission_percent FROM problem_prices ORDER BY problem_type');
    return reply.send({ success: true, data: res.rows });
  });

  // PUT /api/v1/admin/prices
  fastify.put('/prices', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = (request.body || {}) as { problemType?: string; minPrice?: number; maxPrice?: number; commissionPercent?: number };
    const minPrice = Number(body.minPrice);
    const maxPrice = Number(body.maxPrice);
    const commission = Number(body.commissionPercent ?? 0);

    if (!(minPrice > 0) || !(maxPrice >= minPrice)) {
      return reply.status(400).send({ success: false, error: 'نطاق السعر غير صالح' });
    }
    if (!(commission >= 0 && commission < 100)) {
      return reply.status(400).send({ success: false, error: 'نسبة المنصة غير صالحة' });
    }

    const res = await query(
      `UPDATE problem_prices SET min_price = $1, max_price = $2, commission_percent = $4, updated_at = NOW()
       WHERE problem_type = $3 RETURNING problem_type`,
      [minPrice, maxPrice, body.problemType ?? '', commission]
    );

    if (res.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'نوع المشكلة غير موجود' });
    }

    // Saved client prices follow the new range from the next quote
    await query('DELETE FROM client_problem_prices WHERE problem_type = $1', [body.problemType]);

    return reply.send({ success: true, message: 'تم تحديث السعر' });
  });

  // POST /api/v1/admin/commission - One percent for every service, new orders only
  fastify.post('/commission', async (request: FastifyRequest, reply: FastifyReply) => {
    const percent = Number(((request.body || {}) as { percent?: number }).percent);
    if (!(percent >= 0 && percent < 100)) {
      return reply.status(400).send({ success: false, error: 'نسبة المنصة غير صالحة' });
    }

    await query('UPDATE problem_prices SET commission_percent = $1, updated_at = NOW()', [percent]);
    return reply.send({ success: true, message: 'تم تطبيق النسبة على كل الخدمات' });
  });

  // GET /api/v1/admin/urgent-applications
  fastify.get('/urgent-applications', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT lp.user_id, lp.full_name, lp.syndicate_number, lp.specialty, lp.bio, u.phone, u.email, lp.urgent_terms_accepted_at,
              COALESCE(lp.profile_photo_path, u.profile_photo_path) AS photo,
              card.id AS card_id, card.mime_type AS card_mime
       FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id
       LEFT JOIN LATERAL (
         SELECT id, mime_type FROM lawyer_documents d
         WHERE d.lawyer_profile_id = lp.id AND d.document_type = 'syndicate_card' AND d.is_current
         ORDER BY uploaded_at DESC LIMIT 1
       ) card ON TRUE
       WHERE lp.urgent_status = 'PENDING' ORDER BY lp.urgent_terms_accepted_at ASC`
    );
    return reply.send({ success: true, data: res.rows });
  });

  // POST /api/v1/admin/urgent-applications/:id/decision
  fastify.post('/urgent-applications/:id/decision', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { approve?: boolean; reason?: string };
    const approved = body.approve === true;
    const reason = body.reason ? sanitizeText(body.reason, 500) : null;

    const res = await query(
      `UPDATE lawyer_profiles SET urgent_status = $1, urgent_rejection_reason = $2, updated_at = NOW()
       WHERE user_id = $3 AND urgent_status = 'PENDING' RETURNING user_id`,
      [approved ? 'APPROVED' : 'REJECTED', approved ? null : reason, id]
    );
    if (res.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو تم الفصل فيه' });
    }

    await notify(
      dbPool,
      id,
      approved ? 'تمت الموافقة على تقديمك' : 'تم رفض تقديمك',
      approved ? 'بقيت محامٍ معتمد، فعّل حالتك عشان تستقبل الطلبات' : reason || 'تقدر تراجع بياناتك وتقدم تاني'
    );
    return reply.send({ success: true, message: 'تم تسجيل القرار' });
  });

  // GET /api/v1/admin/tax
  fastify.get('/tax', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query('SELECT tax_percent FROM platform_settings LIMIT 1');
    return reply.send({ success: true, data: { percent: Number(res.rows[0]?.tax_percent ?? 0) } });
  });

  // POST /api/v1/admin/tax - New orders only, open orders keep their locked tax
  fastify.post('/tax', async (request: FastifyRequest, reply: FastifyReply) => {
    const percent = Number(((request.body || {}) as { percent?: number }).percent);
    if (!(percent >= 0 && percent < 100)) {
      return reply.status(400).send({ success: false, error: 'نسبة الضريبة غير صالحة' });
    }

    await query('UPDATE platform_settings SET tax_percent = $1, updated_at = NOW()', [percent]);
    return reply.send({ success: true, message: 'تم تحديث نسبة الضريبة' });
  });

  // GET /api/v1/admin/reviews/reported
  fastify.get('/reviews/reported', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT r.id, r.rating, r.comment, r.report_reason, r.reported_at, r.lawyer_id, lp.full_name as lawyer_name
       FROM reviews r JOIN lawyer_profiles lp ON lp.user_id = r.lawyer_id
       WHERE r.reported_at IS NOT NULL AND r.is_hidden = FALSE
       ORDER BY r.reported_at ASC`
    );
    return reply.send({ success: true, data: res.rows });
  });

  // POST /api/v1/admin/reviews/:id/moderate
  fastify.post('/reviews/:id/moderate', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { hide?: boolean };

    const res = await query(
      `UPDATE reviews SET is_hidden = $1, reported_at = CASE WHEN $1 THEN reported_at ELSE NULL END
       WHERE id::text = $2 RETURNING lawyer_id`,
      [body.hide === true, id]
    );

    if (res.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'التقييم غير موجود' });
    }

    await refreshLawyerRating(dbPool, res.rows[0].lawyer_id);
    return reply.send({ success: true, message: 'تم تحديث التقييم' });
  });
}
