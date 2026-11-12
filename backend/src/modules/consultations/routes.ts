import fs from 'fs';
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { AuthenticatedUser, HttpError, requireAuth } from '../../utils/http.js';
import { publishChange } from '../../services/liveUpdates.js';
import { notify } from '../lifecycle/service.js';
import {
  CONSULTATION_KINDS,
  ConsultationKind,
  listItem,
  pageFile,
  pageLinks,
  priceOf,
  readConsultationForm,
  readSettings,
  savePages,
  waitingForClient,
} from './service.js';

/// «استشارة سريعة» للموكل: الأسعار والشروط، والسعر قبل الدفع، والطلب بالدفع، وطلباته
export async function consultationRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());

  // GET /api/v1/consultations/settings - الشروط اللي بتظهر في التطبيق
  fastify.get('/settings', async (_request: FastifyRequest, reply: FastifyReply) => {
    const settings = await readSettings(dbPool);
    return reply.send({
      success: true,
      data: { maxPages: settings.maxPages, callMinutes: settings.callMinutes, minDetailsChars: settings.minDetailsChars, isOpen: settings.isOpen },
    });
  });

  // POST /api/v1/consultations/quote - تقييم السعر من غير ما يتسجل حاجة
  fastify.post('/quote', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = (request.body || {}) as { kind?: string; pages?: number };
    const kind = body.kind as ConsultationKind;
    if (!CONSULTATION_KINDS.includes(kind)) return reply.status(400).send({ success: false, error: 'اختار نوع الاستشارة' });
    const settings = await readSettings(dbPool);
    const pages = kind === 'PAPERS' ? Math.max(1, Math.min(Number(body.pages) || 0, settings.maxPages)) : 0;
    return reply.send({ success: true, data: { ...priceOf(settings, kind, pages), pages, callMinutes: settings.callMinutes } });
  });

  // GET /api/v1/consultations - استشاراتي، الأحدث الأول
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const res = await query('SELECT * FROM consultations WHERE client_id = $1 ORDER BY created_at DESC LIMIT 100', [userId]);
    return reply.send({ success: true, data: res.rows.map(listItem) });
  });

  // POST /api/v1/consultations - الطلب بالدفع: النوع والتفاصيل وطريقة الدفع وصور الورق
  fastify.post('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    if (role !== 'client') throw new HttpError(403, 'الاستشارة السريعة للموكلين');

    const settings = await readSettings(dbPool);
    if (!settings.isOpen) throw new HttpError(409, 'الخدمة متوقفة دلوقتي، جرب بعد شوية');
    const { fields, pages } = await readConsultationForm(request, settings.maxPages);

    const kind = fields.kind as ConsultationKind;
    if (!CONSULTATION_KINDS.includes(kind)) throw new HttpError(400, 'اختار نوع الاستشارة');
    const details = sanitizeText(fields.details ?? '', 4000).trim();
    if (details.length < settings.minDetailsChars) throw new HttpError(400, `اكتب مشكلتك بالتفصيل في ${settings.minDetailsChars} حرف على الأقل`);
    if (kind === 'PAPERS' && pages.length === 0) throw new HttpError(400, 'ضيف صور الورق');
    const pageCount = kind === 'PAPERS' ? pages.length : 0;
    const { total } = priceOf(settings, kind, pageCount);
    const method = fields.method === 'wallet' ? 'WALLET' : 'DIRECT';
    // Told by voice: the app turned it into text that only the admin reads
    const inputMethod = fields.inputMethod === 'voice' ? 'VOICE' : 'TEXT';

    const row = await withTransaction(async (db) => {
      // الرصيد مشترك مع الطلبات والتحويلات، فبناخد نفس قفل الحساب
      await db.query('SELECT id FROM users WHERE id = $1 FOR NO KEY UPDATE', [userId]);
      if (method === 'WALLET') {
        const balance = await db.query('SELECT COALESCE(SUM(amount), 0) AS balance FROM client_credits WHERE client_id = $1', [userId]);
        if (Number(balance.rows[0].balance) < total) throw new HttpError(400, 'رصيدك مش كفاية');
      }
      const saved = await db.query(
        `INSERT INTO consultations (client_id, kind, details, pages, price, payment_method, input_method) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [userId, kind, details, pageCount, total, method, inputMethod]
      );
      const consultation = saved.rows[0];
      if (method === 'WALLET') {
        await db.query('INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, $2, $3)', [
          userId,
          -total,
          `سداد استشارة ${consultation.reference}`,
        ]);
      }
      await savePages(db, consultation.id, kind === 'PAPERS' ? pages : []);
      await notify(db, userId, 'استلمنا استشارتك', `رقم ${consultation.reference}، وفريقنا هيكلمك خلال دقايق`, { consultationId: consultation.id });
      await publishChange(db, userId, false, 'consultations', consultation.id);
      return consultation;
    });

    return reply.status(201).send({ success: true, data: listItem(row), message: 'استلمنا استشارتك، وفريقنا هيكلمك خلال دقايق' });
  });

  // POST /api/v1/consultations/:id/contact - بعد «مقدرناش نوصلك»: الموكل بيقول إنه متاح دلوقتي
  fastify.post('/:id/contact', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const row = await withTransaction(async (db) => {
      const res = await db.query('SELECT * FROM consultations WHERE (id::text = $1 OR reference = $1) AND client_id = $2 FOR UPDATE', [id, userId]);
      const current = res.rows[0];
      if (!current) throw new HttpError(404, 'الاستشارة غير موجودة');
      if (!waitingForClient(current)) throw new HttpError(409, 'فريقنا هيكلمك، مش محتاج تطلب التواصل دلوقتي');
      const saved = await db.query('UPDATE consultations SET callback_requested_at = NOW() WHERE id = $1 RETURNING *', [current.id]);
      await publishChange(db, userId, false, 'consultations', current.id);
      return saved.rows[0];
    });
    return reply.send({ success: true, data: listItem(row), message: 'وصلنا طلبك، وفريقنا هيكلمك خلال دقايق' });
  });

  // GET /api/v1/consultations/pages/:id - صورة ورقة لصاحبها والإدارة بس
  fastify.get('/pages/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const viewer = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const file = await pageFile(dbPool, id, viewer);
    if (!file) return reply.status(404).send({ success: false, error: 'الصورة غير موجودة' });
    reply.header('Cache-Control', 'private, max-age=3600');
    return reply.type(file.mime).send(fs.createReadStream(file.filePath));
  });

  // GET /api/v1/consultations/:id - استشارة واحدة بصور ورقها
  fastify.get('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const res = await query('SELECT * FROM consultations WHERE (id::text = $1 OR reference = $1) AND client_id = $2', [id, userId]);
    const row = res.rows[0];
    if (!row) return reply.status(404).send({ success: false, error: 'الاستشارة غير موجودة' });
    return reply.send({ success: true, data: { ...listItem(row), pages: await pageLinks(dbPool, row.id) } });
  });
}
