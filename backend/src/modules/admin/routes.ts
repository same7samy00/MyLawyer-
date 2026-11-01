import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { addClientCredit, addLawyerStrike, lawyerShare, MAX_CODE_ATTEMPTS, notify, refreshLawyerRating, warnClient } from '../lifecycle/service.js';

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

  // GET /api/v1/admin/lawyers/pending
  fastify.get('/lawyers/pending', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT lp.id as profile_id, lp.full_name, lp.syndicate_number, lp.submitted_at, lp.profile_photo_path,
              u.id as user_id, u.email, u.phone, u.status,
              (SELECT id FROM lawyer_documents ld WHERE ld.lawyer_profile_id = lp.id AND ld.is_current = TRUE LIMIT 1) as document_id
       FROM lawyer_profiles lp
       JOIN users u ON lp.user_id = u.id
       WHERE lp.approval_status = 'pending'
       ORDER BY lp.submitted_at ASC`
    );

    return reply.send({
      success: true,
      data: res.rows
    });
  });

  // POST /api/v1/admin/lawyers/:id/decision
  fastify.post('/lawyers/:id/decision', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const { decision, reason } = request.body as { decision: 'approved' | 'rejected' | 'suspended' | 'reactivated'; reason?: string };

    if (!['approved', 'rejected', 'suspended', 'reactivated'].includes(decision)) {
      return reply.status(400).send({ success: false, error: 'القرار غير صالح' });
    }

    const lawyerRes = await query('SELECT id, user_id FROM lawyer_profiles WHERE id = $1', [id]);
    if (lawyerRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'ملف المحامي غير موجود' });
    }
    const lawyer = lawyerRes.rows[0];

    const cleanReason = reason ? sanitizeText(reason, 1000) : null;
    let targetUserStatus = 'pending_admin_approval';
    let targetProfileStatus = 'pending';

    if (decision === 'approved' || decision === 'reactivated') {
      targetUserStatus = 'active';
      targetProfileStatus = 'approved';
    } else if (decision === 'rejected') {
      targetUserStatus = 'rejected';
      targetProfileStatus = 'rejected';
    } else if (decision === 'suspended') {
      targetUserStatus = 'suspended';
      targetProfileStatus = 'suspended';
    }

    await withTransaction(async (client) => {
      // Update lawyer profile
      await client.query(
        `UPDATE lawyer_profiles
         SET approval_status = $1::lawyer_approval_status,
             approved_at = CASE WHEN $1::text = 'approved' THEN NOW() ELSE approved_at END,
             rejected_at = CASE WHEN $1::text = 'rejected' THEN NOW() ELSE rejected_at END,
             rejection_reason = $2,
             updated_at = NOW()
         WHERE id = $3`,
        [targetProfileStatus, cleanReason, id]
      );

      // Update user status
      await client.query(
        'UPDATE users SET status = $1::user_status, updated_at = NOW() WHERE id = $2',
        [targetUserStatus, lawyer.user_id]
      );

      // Audit history
      await client.query(
        `INSERT INTO lawyer_approval_history (lawyer_profile_id, action, reason, admin_user_id)
         VALUES ($1, $2::approval_action_type, $3, $4)`,
        [id, decision, cleanReason, adminId]
      );
    });

    return reply.send({
      success: true,
      message: `تم اتخاذ القرار (${decision}) بنجاح لحساب المحامي`
    });
  });

  // GET /api/v1/admin/complaints - Open complaints with the context needed to decide
  fastify.get('/complaints', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT c.id, c.reason, c.filed_after_hold, c.created_at,
              o.id as order_id, o.order_number, o.status as order_status, o.price, o.service_title,
              o.problem_description, o.completed_at, o.payout_status,
              u.phone as client_phone, lu.phone as lawyer_phone, lp.full_name as lawyer_name,
              (SELECT COUNT(*)::int FROM complaints x WHERE x.client_id = c.client_id) as client_complaints,
              (SELECT COUNT(*)::int FROM complaints x WHERE x.lawyer_id = c.lawyer_id) as lawyer_complaints
       FROM complaints c
       JOIN service_orders o ON o.id = c.order_id
       JOIN users u ON u.id = c.client_id
       JOIN users lu ON lu.id = c.lawyer_id
       JOIN lawyer_profiles lp ON lp.user_id = c.lawyer_id
       WHERE c.status = 'OPEN'
       ORDER BY c.created_at ASC`
    );

    return reply.send({ success: true, data: res.rows });
  });

  // POST /api/v1/admin/complaints/:id/resolve
  fastify.post('/complaints/:id/resolve', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { resolution?: string; refundAmount?: number; note?: string };

    if (!['REFUND_FULL', 'REFUND_PARTIAL', 'RELEASE'].includes(body.resolution ?? '')) {
      return reply.status(400).send({ success: false, error: 'القرار غير صالح' });
    }

    const complaintRes = await query(
      `SELECT c.*, o.price, o.commission_percent, o.status as order_status, o.client_id as order_client
       FROM complaints c JOIN service_orders o ON o.id = c.order_id
       WHERE c.id::text = $1 AND c.status = 'OPEN'`,
      [id]
    );
    if (complaintRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الشكوى غير موجودة أو تم الفصل فيها' });
    }

    const complaint = complaintRes.rows[0];
    const price = Number(complaint.price);
    const refund = body.resolution === 'REFUND_FULL' ? price
      : body.resolution === 'REFUND_PARTIAL' ? Number(body.refundAmount)
      : 0;

    if (!Number.isFinite(refund) || refund < 0 || refund > price
        || (body.resolution === 'REFUND_PARTIAL' && (refund === 0 || refund === price))) {
      return reply.status(400).send({ success: false, error: 'قيمة الرد غير صالحة' });
    }
    if (complaint.filed_after_hold && refund > 0) {
      return reply.status(400).send({ success: false, error: 'الشكوى بعد انتهاء المهلة لا يترتب عليها رد تلقائي' });
    }

    await withTransaction(async (client) => {
      await client.query(
        `UPDATE complaints
         SET status = 'RESOLVED', resolution = $1, refund_amount = $2, admin_note = $3,
             resolved_by = $4, resolved_at = NOW()
         WHERE id = $5`,
        [body.resolution, refund, body.note ? sanitizeText(body.note, 1000) : null, adminId, complaint.id]
      );

      if (!complaint.filed_after_hold) {
        // The platform share follows what stays after the refund
        const lawyerAmount = lawyerShare(price - refund, Number(complaint.commission_percent));
        await client.query(
          `UPDATE service_orders
           SET status = $1, payout_status = $2, payout_amount = $3, completion_code = NULL,
               completed_at = COALESCE(completed_at, NOW())
           WHERE id = $4`,
          [
            lawyerAmount > 0 ? 'COMPLETED' : 'REFUNDED',
            lawyerAmount > 0 ? 'AVAILABLE' : 'REFUNDED',
            lawyerAmount,
            complaint.order_id,
          ]
        );
        await client.query(
          `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
           VALUES ($1, $2, $3, $4, $5)`,
          [complaint.order_id, adminId, complaint.order_status, lawyerAmount > 0 ? 'COMPLETED' : 'REFUNDED', `قرار الشكوى: ${body.resolution}`]
        );
      }

      if (refund > 0) {
        await addClientCredit(client, complaint.client_id, complaint.order_id, refund, 'رد قيمة بعد مراجعة شكوى');
        await addLawyerStrike(client, complaint.lawyer_id, complaint.order_id, 'COMPLAINT');
      }

      const clientMessage = refund > 0 ? `رجعلك ${refund} ج.م في رصيدك` : 'تم إغلاق شكواك بعد المراجعة';
      await notify(client, complaint.client_id, 'قرار الشكوى', clientMessage, complaint.order_id);
      await notify(client, complaint.lawyer_id, 'قرار الشكوى', 'راجعت الإدارة الشكوى، وتقدر تشوف الرصيد في المحفظة', complaint.order_id);
    });

    return reply.send({ success: true, message: 'تم تسجيل القرار' });
  });

  // GET /api/v1/admin/appeals
  fastify.get('/appeals', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT a.id, a.reason, a.created_at, o.order_number, o.price, o.service_title, lp.full_name as lawyer_name
       FROM order_appeals a
       JOIN service_orders o ON o.id = a.order_id
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

  // GET /api/v1/admin/tickets - Everything waiting for a decision, oldest first
  fastify.get('/tickets', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT * FROM (
         SELECT 'complaint' AS type, 'شكوى موكل' AS label, c.id::text AS id, o.order_number, c.reason AS details, c.created_at, o.price
         FROM complaints c JOIN service_orders o ON o.id = c.order_id WHERE c.status = 'OPEN'
         UNION ALL
         SELECT 'appeal', 'اعتراض محامي', a.id::text, o.order_number, a.reason, a.created_at, o.price
         FROM order_appeals a JOIN service_orders o ON o.id = a.order_id WHERE a.status = 'OPEN'
         UNION ALL
         SELECT 'report', 'بلاغ من محامي', r.id::text, o.order_number, r.reason, r.created_at, o.price
         FROM lawyer_reports r JOIN service_orders o ON o.id = r.order_id WHERE r.status = 'OPEN'
         UNION ALL
         SELECT 'locked', 'كود مقفول', o.id::text, o.order_number, 'المحامي تجاوز عدد محاولات الكود', o.updated_at, o.price
         FROM service_orders o WHERE o.status = 'ACTIVE' AND o.code_attempts >= $1
         UNION ALL
         SELECT 'review', 'تعليق مبلغ عنه', r.id::text, o.order_number, r.report_reason, r.reported_at, o.price
         FROM reviews r JOIN service_orders o ON o.id = r.order_id WHERE r.reported_at IS NOT NULL AND r.is_hidden = FALSE
       ) tickets
       ORDER BY created_at ASC`,
      [MAX_CODE_ATTEMPTS]
    );

    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        ...row,
        isOverdue: Date.now() - new Date(row.created_at).getTime() > 86400000,
      })),
    });
  });

  // POST /api/v1/admin/orders/:id/unlock-code
  fastify.post('/orders/:id/unlock-code', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const res = await query(
      `UPDATE service_orders SET code_attempts = 0
       WHERE id::text = $1 AND status = 'ACTIVE' RETURNING lawyer_id, id`,
      [id]
    );

    if (res.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });
    }

    await notify(dbPool, res.rows[0].lawyer_id, 'تم فتح الكود', 'تقدر تكتب كود الموكل تاني', res.rows[0].id);
    return reply.send({ success: true, message: 'تم فتح الكود' });
  });

  // POST /api/v1/admin/reports/:id/resolve
  fastify.post('/reports/:id/resolve', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId: adminId } = request.user as { userId: string };
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { note?: string };

    const res = await query(
      `UPDATE lawyer_reports SET status = 'RESOLVED', admin_note = $1, resolved_by = $2, resolved_at = NOW()
       WHERE id::text = $3 AND status = 'OPEN' RETURNING lawyer_id, order_id`,
      [body.note ? sanitizeText(body.note, 1000) : null, adminId, id]
    );

    if (res.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'البلاغ غير موجود أو تم إغلاقه' });
    }

    await notify(dbPool, res.rows[0].lawyer_id, 'تم إغلاق البلاغ', 'راجعت الإدارة بلاغك', res.rows[0].order_id);
    return reply.send({ success: true, message: 'تم إغلاق البلاغ' });
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
