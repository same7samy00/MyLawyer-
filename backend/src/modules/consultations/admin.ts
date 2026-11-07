import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { AuthenticatedUser, HttpError, UUID_PATTERN } from '../../utils/http.js';
import { publishChange } from '../../services/liveUpdates.js';
import { notify } from '../lifecycle/service.js';
import { logAdminAction } from '../admin/actions.js';
import { pageLinks, priceOf, readSettings } from './service.js';

const NEXT: Record<string, string[]> = { PAID: ['CONTACTING', 'DONE', 'REJECTED'], CONTACTING: ['DONE', 'REJECTED'] };

/// جانب لوحة التحكم: القايمة، والتفاصيل بالصور، وتغيير الحالة، والأسعار
export async function registerAdminConsultations(fastify: FastifyInstance) {
  // GET /api/v1/admin/consultations - كل الاستشارات، اللي مستنية الأول
  fastify.get('/consultations', async (_request: FastifyRequest, reply: FastifyReply) => {
    const res = await query(
      `SELECT c.id, c.reference, c.kind, c.pages, c.price, c.payment_method, c.status, c.created_at, c.contacted_at, c.closed_at,
              c.unreachable_at, c.callback_requested_at,
              c.client_id, u.phone AS client_phone, COALESCE(u.full_name, u.phone) AS client_name, LEFT(c.details, 160) AS details_preview
       FROM consultations c JOIN users u ON u.id = c.client_id
       ORDER BY c.created_at DESC LIMIT 500`
    );
    return reply.send({ success: true, data: res.rows });
  });

  // GET /api/v1/admin/consultations/:id
  fastify.get('/consultations/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    const res = await query(
      `SELECT c.*, u.phone AS client_phone, u.email AS client_email, COALESCE(u.full_name, u.phone) AS client_name,
              u.profile_photo_path AS client_photo, h.email AS handled_by_email
       FROM consultations c JOIN users u ON u.id = c.client_id LEFT JOIN users h ON h.id = c.handled_by
       WHERE c.id = $1`,
      [id]
    );
    const row = res.rows[0];
    if (!row) return reply.status(404).send({ success: false, error: 'الاستشارة غير موجودة' });
    return reply.send({ success: true, data: { ...row, page_links: await pageLinks(dbPool, row.id) } });
  });

  // POST /api/v1/admin/consultations/:id/status - جاري التواصل، أو تمت، أو رفض بسبب ويرجع المبلغ للرصيد
  fastify.post('/consultations/:id/status', async (request: FastifyRequest, reply: FastifyReply) => {
    const admin = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { status?: string; note?: string; reason?: string };
    if (!UUID_PATTERN.test(id)) throw new HttpError(400, 'المعرف غير صالح');
    const status = String(body.status || '');
    const note = sanitizeText(body.note ?? '', 2000).trim() || null;
    const reason = sanitizeText(body.reason ?? '', 500).trim();
    if (status === 'REJECTED' && reason.length < 3) throw new HttpError(400, 'اكتب سبب الرفض');

    const row = await withTransaction(async (db) => {
      const res = await db.query('SELECT * FROM consultations WHERE id = $1 FOR UPDATE', [id]);
      const current = res.rows[0];
      if (!current) throw new HttpError(404, 'الاستشارة غير موجودة');
      if (!(NEXT[current.status] ?? []).includes(status)) throw new HttpError(409, 'لا يمكن نقل الاستشارة لهذه الحالة');

      const updated = await db.query(
        `UPDATE consultations SET status = $2::text, handled_by = $3,
           admin_note = COALESCE($4::text, admin_note),
           reject_reason = CASE WHEN $2::text = 'REJECTED' THEN $5::text ELSE reject_reason END,
           contacted_at = CASE WHEN $2::text = 'CONTACTING' THEN NOW() ELSE contacted_at END,
           closed_at = CASE WHEN $2::text IN ('DONE', 'REJECTED') THEN NOW() ELSE closed_at END
         WHERE id = $1 RETURNING *`,
        [id, status, admin.userId, note, reason || null]
      );
      const saved = updated.rows[0];
      if (status === 'REJECTED') {
        // المبلغ كله بيرجع لرصيد الموكل، سواء دفع من الرصيد أو مباشر
        await db.query('INSERT INTO client_credits (client_id, amount, reason, created_by) VALUES ($1, $2, $3, $4)', [
          saved.client_id,
          Number(saved.price),
          `استرداد استشارة ${saved.reference}`,
          admin.userId,
        ]);
        await notify(db, saved.client_id, 'استشارتك اترفضت', `${reason}\nرجّعنا ${Number(saved.price)} ج.م لرصيدك`);
      } else if (status === 'DONE') {
        await notify(db, saved.client_id, 'الاستشارة تمت', `استشارة ${saved.reference}، شكرًا إنك استخدمت My Lawyer`);
      }
      await publishChange(db, saved.client_id, false, 'consultations', saved.id);
      return saved;
    });

    return reply.send({ success: true, data: row, message: 'تم تحديث الاستشارة' });
  });

  // POST /api/v1/admin/consultations/:id/unreachable - «مقدرناش نوصلك»: تنبيه للموكل يطلب التواصل لما يكون متاح
  fastify.post('/consultations/:id/unreachable', async (request: FastifyRequest, reply: FastifyReply) => {
    const admin = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) throw new HttpError(400, 'المعرف غير صالح');
    const row = await withTransaction(async (db) => {
      const res = await db.query('SELECT * FROM consultations WHERE id = $1 FOR UPDATE', [id]);
      const current = res.rows[0];
      if (!current) throw new HttpError(404, 'الاستشارة غير موجودة');
      if (current.status !== 'PAID' && current.status !== 'CONTACTING') throw new HttpError(409, 'الاستشارة دي اتقفلت');
      const saved = await db.query(
        'UPDATE consultations SET unreachable_at = NOW(), callback_requested_at = NULL, handled_by = $2 WHERE id = $1 RETURNING *',
        [id, admin.userId]
      );
      await notify(db, current.client_id, 'مقدرناش نوصلك', `حاولنا نكلمك على استشارة ${current.reference}\nلما تكون متاح افتح الطلب واضغط «طلب التواصل»`);
      await publishChange(db, current.client_id, false, 'consultations', current.id);
      return saved.rows[0];
    });
    return reply.send({ success: true, data: row, message: 'تم إرسال التنبيه للموكل' });
  });

  // GET /api/v1/admin/consultation-settings
  fastify.get('/consultation-settings', async (_request: FastifyRequest, reply: FastifyReply) => {
    const settings = await readSettings(dbPool);
    return reply.send({ success: true, data: { ...settings, sample: priceOf(settings, 'PAPERS', 3).total } });
  });

  // PUT /api/v1/admin/consultation-settings - الأسعار والحدود، وبتتطبق على الاستشارات الجديدة بس
  fastify.put('/consultation-settings', async (request: FastifyRequest, reply: FastifyReply) => {
    const admin = request.user as AuthenticatedUser;
    const body = (request.body || {}) as Record<string, unknown>;
    const num = (key: string, min: number, max: number) => {
      const value = Number(body[key]);
      if (!Number.isFinite(value) || value < min || value > max) throw new HttpError(400, `قيمة غير صالحة: ${key}`);
      return value;
    };
    const values = [
      num('callPrice', 0, 100000),
      num('papersBasePrice', 0, 100000),
      num('pagePrice', 0, 10000),
      Math.round(num('maxPages', 1, 20)),
      Math.round(num('callMinutes', 1, 120)),
      Math.round(num('minDetailsChars', 10, 1000)),
      body.isOpen !== false,
    ];
    await query(
      `UPDATE consultation_settings SET call_price = $1, papers_base_price = $2, page_price = $3, max_pages = $4,
         call_minutes = $5, min_details_chars = $6, is_open = $7, updated_at = NOW()`,
      values
    );
    await logAdminAction(admin.userId, 'CONSULTATION_SETTINGS', 'استشارة سريعة',
      `استشارة ${values[0]}، اطلاع ${values[1]} + ${values[2]} للورقة، حد ${values[3]} ورقات، مكالمة ${values[4]} دقايق${values[6] ? '' : '، الخدمة متوقفة'}`);
    return reply.send({ success: true, data: await readSettings(dbPool), message: 'تم حفظ إعدادات الاستشارة' });
  });
}
