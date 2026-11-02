import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { pipeline } from 'stream/promises';
import { query, withTransaction } from '../../database/index.js';
import { config } from '../../config/index.js';
import { sanitizeText } from '../../utils/security.js';
import { approximateCoordinate } from '../lifecycle/service.js';

// Ensure storage directories exist
if (!fs.existsSync(config.publicStoragePath)) {
  fs.mkdirSync(config.publicStoragePath, { recursive: true });
}
const avatarsDir = path.join(config.publicStoragePath, 'avatars');
if (!fs.existsSync(avatarsDir)) {
  fs.mkdirSync(avatarsDir, { recursive: true });
}

if (!fs.existsSync(config.privateStoragePath)) {
  fs.mkdirSync(config.privateStoragePath, { recursive: true });
}

interface AuthenticatedLawyer {
  userId: string;
  role: string;
}

// Clients can browse the map further than the area they can order from
const MAX_MAP_RADIUS_KM = 1500;

export async function lawyerRoutes(fastify: FastifyInstance) {
  // Helper authentication hook for protected lawyer routes
  const requireLawyerAuth = async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
      const { role } = request.user as AuthenticatedLawyer;
      if (role !== 'lawyer' && role !== 'admin') {
        return reply.status(403).send({ success: false, error: 'هذا المسار مخصص للمحامين فقط' });
      }
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }
  };

  // 1. GET /api/v1/lawyers/nearby (Open to clients & visitors for real nearby search)
  fastify.get('/nearby', async (request: FastifyRequest, reply: FastifyReply) => {
    const queryParams = request.query as {
      lat?: string;
      lon?: string;
      radius_km?: string;
      specialty?: string;
    };

    const userLat = parseFloat(queryParams.lat || '');
    const userLon = parseFloat(queryParams.lon || '');
    const radiusKm = Math.min(Math.max(parseFloat(queryParams.radius_km || '25') || 25, 1), MAX_MAP_RADIUS_KM);

    // If client coordinates are missing or invalid
    if (isNaN(userLat) || isNaN(userLon)) {
      return reply.status(400).send({
        success: false,
        error: 'يجب توفير إحداثيات صالحة للبحث (lat و lon)',
      });
    }

    // Egypt geographic boundary sanity check (22.0 to 31.8 N, 24.5 to 37.0 E)
    if (userLat < 21.0 || userLat > 32.5 || userLon < 24.0 || userLon > 37.5) {
      return reply.send({
        success: true,
        data: [],
        message: 'الإحداثيات خارج نطاق تغطية جمهورية مصر العربية',
      });
    }

    // Query ONLY approved, active, online lawyers with valid Egyptian coordinates
    // Haversine formula calculation directly in PostgreSQL with explicit float8 casts
    // Nearby lawyers are grouped by distance, and each group starts with the highest rated
    const sql = `
      SELECT * FROM (
      SELECT
        u.id as user_id,
        lp.id as profile_id,
        lp.full_name,
        lp.profile_photo_path,
        lp.specialty,
        lp.degree,
        lp.rating,
        lp.reviews_count,
        lp.experience_years,
        lp.latitude,
        lp.longitude,
        lp.is_available,
        (
          6371.0 * acos(
            least(1.0::float8, greatest(-1.0::float8,
              cos(radians($1::float8)) * cos(radians(lp.latitude::float8)) *
              cos(radians(lp.longitude::float8) - radians($2::float8)) +
              sin(radians($1::float8)) * sin(radians(lp.latitude::float8))
            ))
          )
        ) AS distance_km
      FROM lawyer_profiles lp
      JOIN users u ON lp.user_id = u.id
      WHERE lp.approval_status = 'approved'
        AND u.status = 'active'
        AND lp.is_available = TRUE
        AND lp.latitude IS NOT NULL
        AND lp.longitude IS NOT NULL
        AND lp.latitude BETWEEN 22.0 AND 31.8
        AND lp.longitude BETWEEN 24.5 AND 37.0
        AND lp.suspended_until IS NULL
        AND lp.urgent_status = 'APPROVED'
        AND NOT EXISTS (
          SELECT 1 FROM service_orders o
          WHERE o.lawyer_id = u.id AND o.status IN ('PENDING', 'ACCEPTED', 'ACTIVE')
        )
      ) lp
      ORDER BY
        CASE
          WHEN (distance_km) <= 2 THEN 1
          WHEN (distance_km) <= 5 THEN 2
          WHEN (distance_km) <= 10 THEN 3
          WHEN (distance_km) <= 25 THEN 4
          ELSE 5
        END,
        lp.rating DESC,
        distance_km ASC
      LIMIT 1000;
    `;

    try {
      const res = await query(sql, [userLat, userLon]);

      // Filter by requested radius
      const nearbyLawyers = res.rows
        .filter((row) => Number(row.distance_km) <= radiusKm)
        .map((lawyer) => ({
          id: lawyer.user_id,
          profileId: lawyer.profile_id,
          userId: lawyer.user_id,
          name: lawyer.full_name,
          specialty: lawyer.specialty || 'محامٍ معتمد ومستشار قانوني',
          degree: lawyer.degree || 'محامي استئناف',
          rating: Number(lawyer.rating) || 0,
          reviewsCount: Number(lawyer.reviews_count) || 0,
          experienceYears: Number(lawyer.experience_years) || 5,
          isOnline: lawyer.is_available === true,
          avatar: lawyer.profile_photo_path || null,
          // The exact place is shared with the client only after payment
          coordinates: [approximateCoordinate(Number(lawyer.latitude)), approximateCoordinate(Number(lawyer.longitude))],
          distanceKm: Number(Number(lawyer.distance_km).toFixed(1)),
        }));

      return reply.send({
        success: true,
        data: nearbyLawyers,
      });
    } catch (err: any) {
      fastify.log.error(err, 'Error fetching nearby lawyers');
      return reply.status(500).send({
        success: false,
        error: 'حدث خطأ أثناء البحث عن المحامين المتاحين',
        detail: err?.message,
      });
    }
  });

  // GET /api/v1/lawyers/:id/reviews - Published reviews, open like the nearby search
  fastify.get('/:id/reviews', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    if (!/^[0-9a-f-]{36}$/i.test(id)) {
      return reply.status(400).send({ success: false, error: 'معرف المحامي غير صالح' });
    }

    const res = await query(
      `SELECT id, rating, comment, published_at FROM reviews
       WHERE lawyer_id = $1 AND published_at IS NOT NULL AND is_hidden = FALSE
       ORDER BY published_at DESC LIMIT 50`,
      [id]
    );

    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        id: row.id,
        rating: row.rating,
        comment: row.comment,
        // Client names are not stored, so reviews show a neutral label
        authorName: 'عميل استخدم الخدمة',
        publishedAt: row.published_at,
      })),
    });
  });

  // POST /api/v1/lawyers/me/reviews/:reviewId/report - Lawyer reports a comment to the admin
  fastify.post('/me/reviews/:reviewId/report', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;
    const { reviewId } = request.params as { reviewId: string };
    const body = (request.body || {}) as { reason?: string };

    const res = await query(
      `UPDATE reviews SET reported_at = NOW(), report_reason = $1
       WHERE id::text = $2 AND lawyer_id = $3 RETURNING id`,
      [sanitizeText(body.reason || 'بلاغ من المحامي', 500), reviewId, userId]
    );

    if (res.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'التقييم غير موجود' });
    }

    return reply.send({ success: true, message: 'تم إرسال البلاغ للإدارة' });
  });

  // 2. GET /api/v1/lawyers/me (Protected: Lawyer Profile)
  fastify.get('/me', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;

    const lawyerRes = await query(
      `SELECT lp.id as profile_id, lp.full_name, lp.profile_photo_path, lp.approval_status,
              lp.syndicate_number, lp.specialty, lp.degree, lp.rating, lp.reviews_count,
              lp.experience_years, lp.bio, lp.is_available, lp.latitude, lp.longitude,
              lp.last_location_updated_at, lp.last_active_at, lp.availability_off_reason, lp.urgent_status, lp.urgent_rejection_reason, lp.submitted_at, lp.approved_at,
              lp.rejected_at, lp.rejection_reason,
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
  fastify.post('/me/urgent-terms', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;
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
  fastify.post('/me/availability', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;
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
  fastify.post('/me/location', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;
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
       SET latitude = $1, longitude = $2, last_location_updated_at = NOW(), last_active_at = NOW(), updated_at = NOW()
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

  // 5. POST /api/v1/lawyers/me/profile-photo (Protected: Avatars upload)
  fastify.post('/me/profile-photo', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;

    const data = await request.file();
    if (!data) {
      return reply.status(400).send({ success: false, error: 'لم يتم إرسال ملف الصورة' });
    }

    const allowedMime = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedMime.includes(data.mimetype)) {
      return reply.status(400).send({ success: false, error: 'نوع الملف غير مدعوم، يرجى رفع صورة JPG أو PNG أو WEBP' });
    }

    const ext = data.mimetype === 'image/png' ? '.png' : data.mimetype === 'image/webp' ? '.webp' : '.jpg';
    const filename = `avatar_${crypto.randomUUID()}${ext}`;
    const filePath = path.join(avatarsDir, filename);

    await pipeline(data.file, fs.createWriteStream(filePath));

    const relativeWebPath = `/uploads/avatars/${filename}`;

    await query(
      `UPDATE lawyer_profiles
       SET profile_photo_path = $1, updated_at = NOW()
       WHERE user_id = $2`,
      [relativeWebPath, userId]
    );

    return reply.send({
      success: true,
      message: 'تم رفع الصورة الشخصية بنجاح',
      data: {
        profilePhotoPath: relativeWebPath
      }
    });
  });

  // 6. POST /api/v1/lawyers/me/documents (Protected: Syndicate card upload)
  fastify.post('/me/documents', { preHandler: [requireLawyerAuth] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedLawyer;

    const lawyerRes = await query('SELECT id FROM lawyer_profiles WHERE user_id = $1', [userId]);
    if (lawyerRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'ملف المحامي غير موجود' });
    }
    const profileId = lawyerRes.rows[0].id;

    const data = await request.file();
    if (!data) {
      return reply.status(400).send({ success: false, error: 'لم يتم إرسال الملف' });
    }

    const allowedMime = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
    if (!allowedMime.includes(data.mimetype)) {
      return reply.status(400).send({ success: false, error: 'نوع الملف غير مدعوم، يرجى رفع صورة أو ملف PDF' });
    }

    const ext = path.extname(data.filename) || (data.mimetype === 'application/pdf' ? '.pdf' : '.jpg');
    const secretStorageName = `doc_${crypto.randomBytes(24).toString('hex')}${ext}`;
    const secretStoragePath = path.join(config.privateStoragePath, secretStorageName);

    await pipeline(data.file, fs.createWriteStream(secretStoragePath));

    const stats = fs.statSync(secretStoragePath);

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
        [profileId, secretStoragePath, data.filename, data.mimetype, stats.size]
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
  fastify.get('/documents/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }

    const { userId, role } = request.user as AuthenticatedLawyer;
    const { id } = request.params as { id: string };

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
