import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { config } from '../../config/index.js';
import { dbPool, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { detectFileType } from '../../utils/files.js';
import { AuthenticatedUser, HttpError, requireAuth, UUID_PATTERN } from '../../utils/http.js';
import { notify } from '../lifecycle/service.js';
import { OPEN_ORDER_TICKET } from '../support/service.js';
import { createServiceRequest, inServiceArea } from '../requests/service.js';
import { finishOrder, lockOrder } from '../orders/shared.js';
import { arrivalRadiusMeters, FIELD_SERVICES, markFieldArrival, MAX_CODE_ATTEMPTS, MAX_PROOF_PHOTOS, newHandoverCode } from './service.js';

const PROOFS_DIR = () => path.join(config.privateStoragePath, 'field-proofs');
const MAX_PROOF_BYTES = 5 * 1024 * 1024;

const requireId = (id: string) => {
  if (!UUID_PATTERN.test(id)) throw new HttpError(404, 'الطلب غير موجود');
};

/// The order of a field request, locked, for the lawyer who holds it
async function lockFieldOrder(client: any, orderId: string, lawyerId: string) {
  const order = await lockOrder(client, orderId);
  if (!order || order.lawyer_id !== lawyerId) throw new HttpError(404, 'الطلب غير موجود أو غير مسند إليك');
  const field = (await client.query(
    `SELECT f.* FROM service_requests r JOIN field_requests f ON f.request_id = r.id WHERE r.order_id = $1 FOR UPDATE OF f`,
    [order.id]
  )).rows[0];
  if (!field) throw new HttpError(404, 'الطلب ده مش خدمة ميدانية');
  return { order, field };
}

/// The field services: a request for the client or for another person, to a named place
export async function fieldRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());

  // The client sends a field request. It reaches the nearest lawyers to the place, with the same offers and
  // payment as every request, and the field details are saved with it
  fastify.post('/requests', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    if (role !== 'client') throw new HttpError(403, 'الطلبات مخصصة للموكلين');

    const body = (request.body || {}) as {
      serviceTitle?: string; problemDescription?: string; placeName?: string; placeLat?: number; placeLon?: number;
      placeVerified?: boolean; forOther?: boolean; personName?: string; relation?: string; detained?: boolean;
    };
    const kind = typeof body.serviceTitle === 'string' ? FIELD_SERVICES[body.serviceTitle] : undefined;
    if (!kind) throw new HttpError(400, 'الخدمة دي مش من الخدمات الميدانية');
    if (typeof body.problemDescription !== 'string' || !body.problemDescription.trim()) {
      throw new HttpError(400, 'اكتب تفاصيل الطلب');
    }
    const placeName = typeof body.placeName === 'string' ? sanitizeText(body.placeName, 255).trim() : '';
    if (!placeName) throw new HttpError(400, 'اكتب اسم المكان');
    const lat = Number(body.placeLat);
    const lon = Number(body.placeLon);
    if (!inServiceArea(lat, lon)) throw new HttpError(400, 'تعذر تحديد المكان، اختاره تاني');

    const forOther = body.forOther === true;
    const personName = forOther && typeof body.personName === 'string' ? sanitizeText(body.personName, 120).trim() : '';
    if (forOther && !personName) throw new HttpError(400, 'اكتب اسم الشخص');
    const verified = body.placeVerified !== false;

    const created = await createServiceRequest(
      userId,
      {
        serviceTitle: body.serviceTitle as string,
        problemType: body.serviceTitle as string,
        description: sanitizeText(body.problemDescription, 3000),
        lat,
        lon,
        address: placeName,
      },
      async (client, saved) => {
        await client.query(
          `INSERT INTO field_requests (request_id, for_other, person_name, relation, person_detained, place_name, place_kind,
                                       place_verified, arrival_radius_m, handover_code)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            saved.id, forOther, forOther ? personName : null,
            forOther && typeof body.relation === 'string' ? sanitizeText(body.relation, 60).trim() || null : null,
            forOther && body.detained === true, placeName, kind, verified, arrivalRadiusMeters(kind, verified),
            forOther ? newHandoverCode() : null,
          ]
        );
      }
    );
    return reply.status(201).send({ success: true, message: 'طلبك اتبعت لأقرب المحامين', data: { id: created.id } });
  });

  // The lawyer met the person and types the code the person gave. It counts as the arrival
  fastify.post('/orders/:id/code', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    if (role !== 'lawyer') throw new HttpError(403, 'الكود للمحامي');
    const typed = String((request.body as { code?: unknown } | null)?.code ?? '').trim();

    // A wrong code is counted even though the transaction answers with an error, so it is saved outside it
    let wrong = false;
    await withTransaction(async (client) => {
      const { order, field } = await lockFieldOrder(client, id, userId);
      if (order.status !== 'ACTIVE' || order.arrived_at) throw new HttpError(400, 'لا يمكن تسجيل الوصول لهذا الطلب');
      if (!field.for_other || !field.handover_code) throw new HttpError(400, 'الطلب ده مالوش كود');
      if (field.code_attempts >= MAX_CODE_ATTEMPTS) throw new HttpError(423, 'الكود اتقفل، خلّي الموكل يأكد وصولك');

      if (typed !== field.handover_code) {
        await client.query('UPDATE field_requests SET code_attempts = code_attempts + 1 WHERE request_id = $1', [field.request_id]);
        wrong = true;
        return;
      }
      await client.query('UPDATE service_orders SET arrived_at = NOW(), updated_at = NOW() WHERE id = $1', [order.id]);
      await markFieldArrival(client, order.id, 'code');
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'ACTIVE', 'ACTIVE', 'سجّل المحامي وصوله بكود الشخص')`,
        [order.id, userId]
      );
      await notify(client, order.client_id, 'المحامي قابل الشخص', 'المحامي كتب الكود الصح، وبدأ المهمة', order.id);
    });

    if (wrong) throw new HttpError(400, 'الكود غلط، اتأكد منه مع الشخص');
    return reply.send({ success: true, message: 'تم تسجيل وصولك' });
  });

  // The person refused the lawyer after the meeting. The lawyer arrived and the trip happened, so the fee is the
  // lawyer's in full (owner decision 2026-11-12): the order closes like «إنهاء المهمة»
  fastify.post('/orders/:id/refused', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    if (role !== 'lawyer') throw new HttpError(403, 'الإجراء ده للمحامي');

    await withTransaction(async (client) => {
      const { order, field } = await lockFieldOrder(client, id, userId);
      if (order.status !== 'ACTIVE') throw new HttpError(400, 'لا يمكن إنهاء المهمة قبل سداد الموكل');
      if (!order.arrived_at) throw new HttpError(409, 'سجل وصولك الأول');
      if (field.refused_at) throw new HttpError(409, 'اتسجل قبل كده');
      const openComplaint = await client.query(`SELECT ${OPEN_ORDER_TICKET('$1')} AS open`, [order.id]);
      if (openComplaint.rows[0].open) throw new HttpError(409, 'الطلب قيد مراجعة تذكرة من الإدارة');

      await client.query('UPDATE field_requests SET refused_at = NOW() WHERE request_id = $1', [field.request_id]);
      await finishOrder(client, order, userId, 'الشخص رفض المحامي بعد الوصول، والأتعاب للمحامي كاملة');
      await notify(
        client, order.client_id, 'الشخص رفض المحامي',
        'المحامي وصل والشخص رفضه، فالأتعاب اتسلمت للمحامي. لو عندك اعتراض افتح «عندك مشكلة؟»', order.id
      );
    });
    return reply.send({ success: true, message: 'تم تسجيل رفض الشخص، والأتعاب هتتاح بعد 24 ساعة' });
  });

  // A photo the lawyer keeps as evidence (the station, the reception paper). Only the admin sees it
  fastify.post('/orders/:id/proof', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    if (role !== 'lawyer') throw new HttpError(403, 'الصورة للمحامي');
    if (!request.isMultipart()) throw new HttpError(400, 'ارفع صورة');

    const part = await request.file({ limits: { fileSize: MAX_PROOF_BYTES } });
    if (!part) throw new HttpError(400, 'ارفع صورة');
    const buffer = await part.toBuffer();
    if (part.file.truncated) throw new HttpError(400, 'الصورة أكبر من 5 ميجا');
    const type = detectFileType(buffer);
    if (!type?.mime.startsWith('image/')) throw new HttpError(400, 'الملف لازم يكون صورة');

    const count = await withTransaction(async (client) => {
      const { order, field } = await lockFieldOrder(client, id, userId);
      if (order.status !== 'ACTIVE' && order.status !== 'COMPLETED') throw new HttpError(400, 'الطلب لسه ما بدأش');
      const saved = await client.query('SELECT COUNT(*)::int AS total FROM field_proofs WHERE request_id = $1', [field.request_id]);
      if (saved.rows[0].total >= MAX_PROOF_PHOTOS) throw new HttpError(409, 'وصلت للحد الأقصى من الصور');
      const fileName = `${crypto.randomUUID()}${type.ext}`;
      await fs.promises.mkdir(PROOFS_DIR(), { recursive: true });
      await fs.promises.writeFile(path.join(PROOFS_DIR(), fileName), buffer);
      await client.query('INSERT INTO field_proofs (request_id, uploaded_by, file_name, mime) VALUES ($1, $2, $3, $4)', [field.request_id, userId, fileName, type.mime]);
      return saved.rows[0].total + 1;
    });
    return reply.status(201).send({ success: true, message: 'الصورة اتحفظت عند الإدارة', data: { proofs: count } });
  });

  // The admin reads the evidence photos of an order
  fastify.get('/orders/:id/proofs', { onRequest: requireAuth(['admin']) }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    requireId(id);
    const res = await dbPool.query(
      `SELECT p.id, p.created_at FROM field_proofs p
       JOIN service_requests r ON r.id = p.request_id WHERE r.order_id = $1 ORDER BY p.created_at`,
      [id]
    );
    return reply.send({ success: true, data: res.rows.map((row) => ({ id: row.id, createdAt: row.created_at, url: `/field/proofs/${row.id}` })) });
  });

  fastify.get('/proofs/:id', { onRequest: requireAuth(['admin']) }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    requireId(id);
    const res = await dbPool.query('SELECT file_name, mime FROM field_proofs WHERE id = $1', [id]);
    const row = res.rows[0];
    if (!row) throw new HttpError(404, 'الصورة غير موجودة');
    return reply.type(row.mime).header('Cache-Control', 'private, no-store').send(fs.createReadStream(path.join(PROOFS_DIR(), row.file_name)));
  });
}
