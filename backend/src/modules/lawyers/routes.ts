import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { query, withTransaction } from '../../database/index.js';
import { config } from '../../config/index.js';
import { sanitizeText, shortName } from '../../utils/security.js';
import { detectFileType } from '../../utils/files.js';
import { AuthenticatedUser, HttpError, requireAuth, UUID_PATTERN } from '../../utils/http.js';
import { CELL_DEGREES, CellSize, cellsJson, lightCellsJson, MAX_CELLS, SHOWCASE_SECONDS, topInGovernorate } from './showcase.js';
import { GOVERNORATES } from './governorates.js';

export async function lawyerRoutes(fastify: FastifyInstance) {
  // Helper authentication hook for protected lawyer routes
  // Runs first, so the suspended-account check in app.ts sees who is asking
  const requireLawyerAuth = requireAuth(['lawyer', 'admin'], 'هذا المسار مخصص للمحامين فقط');

  // GET /api/v1/lawyers/map?size=s&cells=x_y,x_y - every approved lawyer in the asked squares, for looking only.
  // A square is x = floor(lon / size), y = floor(lat / size), with size 0.1 (s) or 0.5 (l) degrees.
  fastify.get('/map', async (request: FastifyRequest, reply: FastifyReply) => {
    const params = request.query as { size?: string; cells?: string; kind?: string };
    // cards (default): every lawyer, for up close; top: only the best rated lawyer of each small area (showcase.ts)
    const kind = params.kind === 'top' ? 'top' : 'cards';
    const size: CellSize = params.size === 'l' ? 'l' : 's';
    const degrees = CELL_DEGREES[size];
    const wanted: [number, number][] = [];
    for (const part of (params.cells || '').split(',')) {
      const match = /^(-?\d{1,4})_(-?\d{1,4})$/.exec(part.trim());
      if (!match) continue;
      const x = Number(match[1]);
      const y = Number(match[2]);
      // Squares outside Egypt have no lawyers to read
      if (x * degrees > 37.5 || (x + 1) * degrees < 24 || y * degrees > 32.5 || (y + 1) * degrees < 21) continue;
      if (!wanted.some(([wx, wy]) => wx === x && wy === y)) wanted.push([x, y]);
    }
    if (wanted.length === 0) return reply.status(400).send({ success: false, error: 'حدد مربعات الخريطة' });
    if (wanted.length > MAX_CELLS) return reply.status(400).send({ success: false, error: 'مربعات كتير في طلب واحد' });

    const cells = kind === 'cards' ? await cellsJson(size, wanted) : await lightCellsJson(kind, size, wanted);
    reply.header('Cache-Control', `public, max-age=${SHOWCASE_SECONDS}`);
    // Ready text from the squares, joined without turning the lawyers into objects again
    return reply.type('application/json; charset=utf-8').send(`{"success":true,"data":{"size":"${size}","kind":"${kind}","cells":${cells},"seconds":${SHOWCASE_SECONDS}}}`);
  });

  // GET /api/v1/lawyers/top?governorate=... - the top rated lawyers of one governorate, for the lawyers map list
  fastify.get('/top', async (request: FastifyRequest, reply: FastifyReply) => {
    const { governorate, offset, limit } = request.query as { governorate?: string; offset?: string; limit?: string };
    if (!governorate || !GOVERNORATES.includes(governorate)) {
      return reply.status(400).send({ success: false, error: 'المحافظة غير معروفة' });
    }
    // 20 at a time; the app asks for more with offset
    const from = Math.max(0, Math.min(100, Number(offset) || 0));
    const count = Math.max(1, Math.min(50, Number(limit) || 20));
    const data = (await topInGovernorate(governorate)).slice(from, from + count);
    reply.header('Cache-Control', `public, max-age=${SHOWCASE_SECONDS}`);
    return reply.send({ success: true, data });
  });

  // GET /api/v1/lawyers/:id/reviews - Published reviews, open to everyone
  fastify.get('/:id/reviews', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) {
      return reply.status(400).send({ success: false, error: 'معرف المحامي غير صالح' });
    }

    const res = await query(
      `SELECT r.id, r.rating, r.comment, r.published_at, u.full_name, u.profile_photo_path
       FROM reviews r
       JOIN users u ON u.id = r.client_id
       WHERE r.lawyer_id = $1 AND r.published_at IS NOT NULL AND r.is_hidden = FALSE
       ORDER BY r.published_at DESC LIMIT 50`,
      [id]
    );

    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        id: row.id,
        rating: row.rating,
        comment: row.comment,
        // This route is open, so only the short form of the name leaves the server
        authorName: shortName(row.full_name, 'عميل'),
        authorPhoto: row.profile_photo_path || null,
        publishedAt: row.published_at,
      })),
    });
  });

  // POST /api/v1/lawyers/me/reviews/:reviewId/report - Lawyer reports a comment to the admin
  fastify.post('/me/reviews/:reviewId/report', { onRequest: requireLawyerAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { reviewId } = request.params as { reviewId: string };
    const body = (request.body || {}) as { reason?: string };

    const res = await query(
      `UPDATE reviews SET reported_at = NOW(), report_reason = $1
       WHERE id::text = $2 AND lawyer_id = $3 AND report_reason IS NULL RETURNING id`,
      [sanitizeText(body.reason || 'بلاغ من المحامي', 500), reviewId, userId]
    );

    if (res.rows.length === 0) {
      const exists = await query('SELECT 1 FROM reviews WHERE id::text = $1 AND lawyer_id = $2', [reviewId, userId]);
      if (exists.rows.length > 0) throw new HttpError(409, 'بلغت عن التعليق ده قبل كده');
      return reply.status(404).send({ success: false, error: 'التقييم غير موجود' });
    }

    return reply.send({ success: true, message: 'تم إرسال البلاغ للإدارة' });
  });

  // 2. GET /api/v1/lawyers/me (Protected: Lawyer Profile)
  fastify.get('/me', { onRequest: requireLawyerAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;

    const lawyerRes = await query(
      `SELECT lp.id as profile_id, lp.full_name, lp.profile_photo_path, lp.approval_status,
              lp.syndicate_number, lp.rating, lp.reviews_count,
              lp.experience_years, lp.is_available, lp.latitude, lp.longitude,
              lp.last_location_updated_at, lp.last_active_at, lp.availability_off_reason, lp.urgent_status, lp.urgent_rejection_reason, lp.submitted_at, lp.approved_at,
              lp.rejected_at, lp.rejection_reason, lp.suspended_until,
              u.id as user_id, u.email, u.phone, u.status
       FROM lawyer_profiles lp
       JOIN users u ON lp.user_id = u.id
       WHERE lp.user_id = $1`,
      [userId]
    );

    if (lawyerRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'ملف المحامي غير موجود' });
    }

    const lawyer = lawyerRes.rows[0];

    // Fetch uploaded documents
    const docsRes = await query(
      `SELECT id, document_type, original_filename, mime_type, file_size, is_current, uploaded_at
       FROM lawyer_documents
       WHERE lawyer_profile_id = $1
       ORDER BY uploaded_at DESC`,
      [lawyer.profile_id]
    );

    return reply.send({
      success: true,
      data: {
        profile: lawyer,
        documents: docsRes.rows,
      }
    });
  });

  // POST /api/v1/lawyers/me/urgent-terms - The lawyer joins the urgent service
  fastify.post('/me/urgent-terms', { onRequest: requireLawyerAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;

    // The admin checks the photo and the syndicate card before approving
    const filesRes = await query(
      `SELECT COALESCE(lp.profile_photo_path, u.profile_photo_path) AS photo,
              EXISTS (SELECT 1 FROM lawyer_documents d WHERE d.lawyer_profile_id = lp.id
                      AND d.document_type = 'syndicate_card' AND d.is_current) AS has_card
       FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id WHERE lp.user_id = $1`,
      [userId]
    );
    const files = filesRes.rows[0];
    if (!files?.photo) {
      return reply.status(400).send({ success: false, error: 'ارفع صورتك الشخصية الأول من البيانات الشخصية' });
    }
    if (!files.has_card) {
      return reply.status(400).send({ success: false, error: 'ارفع صورة كارنيه النقابة الأول' });
    }

    await query(
      `UPDATE lawyer_profiles
       SET urgent_terms_accepted_at = COALESCE(urgent_terms_accepted_at, NOW()), updated_at = NOW(),
           urgent_status = CASE WHEN urgent_status = 'APPROVED' THEN urgent_status ELSE 'PENDING' END,
           urgent_rejection_reason = NULL
       WHERE user_id = $1`,
      [userId]
    );
    return reply.send({ success: true, message: 'تم إرسال طلبك للإدارة' });
  });

  // 3. POST /api/v1/lawyers/me/availability (Protected: Toggle online/offline status)
  fastify.post('/me/availability', { onRequest: requireLawyerAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as { isAvailable?: boolean; is_available?: boolean };

    const rawVal = body.isAvailable !== undefined ? body.isAvailable : body.is_available;
    const isAvailable = Boolean(rawVal);

    const suspensionRes = await query('SELECT suspended_until, urgent_status FROM lawyer_profiles WHERE user_id = $1', [userId]);
    if (isAvailable && suspensionRes.rows[0]?.urgent_status !== 'APPROVED') {
      return reply.status(403).send({ success: false, error: 'لازم الإدارة توافق على تقديمك للخدمة الأول' });
    }
    if (isAvailable && suspensionRes.rows[0]?.suspended_until) {
      return reply.status(403).send({ success: false, error: 'حسابك موقوف مؤقتاً' });
    }

    const updateRes = await query(
      `UPDATE lawyer_profiles
       SET is_available = $1, availability_off_reason = CASE WHEN $1 THEN NULL ELSE 'MANUAL' END,
           missed_orders = 0, last_active_at = NOW(), updated_at = NOW()
       WHERE user_id = $2
       RETURNING id, is_available, last_active_at`,
      [isAvailable, userId]
    );

    if (updateRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'ملف المحامي غير موجود' });
    }

    return reply.send({
      success: true,
      message: isAvailable ? 'أنت الآن متاح لاستقبال الطلبات الفورية' : 'تم تحويل حالتك إلى غير متاح',
      data: {
        isAvailable: updateRes.rows[0].is_available,
        lastActiveAt: updateRes.rows[0].last_active_at,
      }
    });
  });

  // 4. POST /api/v1/lawyers/me/location (Protected: Update live GPS coordinates)
  fastify.post('/me/location', { onRequest: requireLawyerAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as any;

    const lat = Number(body.latitude ?? body.lat);
    const lon = Number(body.longitude ?? body.lon ?? body.lng);

    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return reply.status(400).send({ success: false, error: 'إحداثيات الموقع غير صالحة' });
    }

    // Egypt bounds check
    if (lat < 21.0 || lat > 32.5 || lon < 24.0 || lon > 37.5) {
      return reply.status(400).send({ success: false, error: 'الإحداثيات تقع خارج جمهورية مصر العربية' });
    }

    const updateRes = await query(
      `UPDATE lawyer_profiles
       SET latitude = $1, longitude = $2, last_location_updated_at = NOW(), last_active_at = NOW(), updated_at = NOW(),
           wake_count = 0, last_wake_at = NULL
       WHERE user_id = $3
       RETURNING id, latitude, longitude, last_location_updated_at, is_available`,
      [lat, lon, userId]
    );

    if (updateRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'ملف المحامي غير موجود' });
    }

    return reply.send({
      success: true,
      message: 'تم تحديث موقعك الميداني بنجاح',
      data: {
        latitude: Number(updateRes.rows[0].latitude),
        longitude: Number(updateRes.rows[0].longitude),
        lastLocationUpdatedAt: updateRes.rows[0].last_location_updated_at,
        isAvailable: updateRes.rows[0].is_available,
      }
    });
  });

  // 6. POST /api/v1/lawyers/me/documents (Protected: Syndicate card upload)
  fastify.post('/me/documents', { onRequest: requireLawyerAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;

    const lawyerRes = await query('SELECT id FROM lawyer_profiles WHERE user_id = $1', [userId]);
    if (lawyerRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'ملف المحامي غير موجود' });
    }
    const profileId = lawyerRes.rows[0].id;

    const data = await request.file();
    if (!data) {
      return reply.status(400).send({ success: false, error: 'لم يتم إرسال الملف' });
    }

    const buffer = await data.toBuffer();
    const type = detectFileType(buffer);
    if (!type) {
      return reply.status(400).send({ success: false, error: 'نوع الملف غير مدعوم، يرجى رفع صورة أو ملف PDF' });
    }

    const secretStorageName = `doc_${crypto.randomBytes(24).toString('hex')}${type.ext}`;
    await fs.promises.mkdir(config.privateStoragePath, { recursive: true });
    const secretStoragePath = path.join(config.privateStoragePath, secretStorageName);
    await fs.promises.writeFile(secretStoragePath, buffer);

    const docRes = await withTransaction(async (client) => {
      await client.query(
        `UPDATE lawyer_documents
         SET is_current = FALSE
         WHERE lawyer_profile_id = $1 AND document_type = 'syndicate_card'`,
        [profileId]
      );

      const inserted = await client.query(
        `INSERT INTO lawyer_documents (lawyer_profile_id, document_type, storage_path, original_filename, mime_type, file_size, is_current)
         VALUES ($1, 'syndicate_card', $2, $3, $4, $5, TRUE)
         RETURNING id, document_type, original_filename, mime_type, file_size, uploaded_at`,
        [profileId, secretStoragePath, data.filename || 'card' + type.ext, type.mime, buffer.length]
      );
      return inserted.rows[0];
    });

    return reply.status(201).send({
      success: true,
      message: 'تم رفع صورة كارنيه المحاماة بنجاح في المسار المحمي',
      data: docRes
    });
  });

  // 7. GET /api/v1/lawyers/documents/:id (Secure private document download)
  fastify.get('/documents/:id', { onRequest: requireAuth() }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    if (!UUID_PATTERN.test(id)) {
      return reply.status(400).send({ success: false, error: 'معرف المستند غير صالح' });
    }

    const docRes = await query(
      `SELECT d.id, d.storage_path, d.mime_type, d.original_filename, lp.user_id
       FROM lawyer_documents d
       JOIN lawyer_profiles lp ON d.lawyer_profile_id = lp.id
       WHERE d.id = $1`,
      [id]
    );

    if (docRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'المستند غير موجود' });
    }

    const doc = docRes.rows[0];

    if (role !== 'admin' && doc.user_id !== userId) {
      return reply.status(403).send({ success: false, error: 'غير مصرح لك بعرض هذا المستند الخاص' });
    }

    if (!fs.existsSync(doc.storage_path)) {
      return reply.status(404).send({ success: false, error: 'الملف غير موجود على السيرفر' });
    }

    const fileStream = fs.createReadStream(doc.storage_path);
    reply.header('Content-Type', doc.mime_type);
    reply.header('Content-Disposition', `inline; filename="${encodeURIComponent(doc.original_filename)}"`);
    return reply.send(fileStream);
  });
}
