import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { pipeline } from 'stream/promises';
import { config } from '../../config/index.js';
import { query } from '../../database/index.js';
import { hashPassword, verifyPassword, sanitizeText } from '../../utils/security.js';
import { z } from 'zod';

export async function userRoutes(fastify: FastifyInstance) {
  // Hook to authenticate all routes in this plugin
  fastify.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }
  });

  // GET /api/v1/users/me
  fastify.get('/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as { userId: string };

    const userRes = await query(
      `SELECT u.id, u.phone, u.email, u.role, u.status, u.email_verified_at, u.created_at,
              COALESCE(lp.full_name, u.full_name) as full_name, COALESCE(lp.profile_photo_path, u.profile_photo_path) as profile_photo_path,
              u.warnings_count, lp.rating, lp.specialty, lp.urgent_status,
              (SELECT COUNT(*)::int FROM service_orders o WHERE o.client_id = u.id AND o.status = 'COMPLETED') as client_completed, lp.approval_status, lp.bio, lp.syndicate_number
       FROM users u
       LEFT JOIN lawyer_profiles lp ON u.id = lp.user_id
       WHERE u.id = $1`,
      [userId]
    );

    if (userRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'المستخدم غير موجود' });
    }

    const user = userRes.rows[0];
    return reply.send({
      success: true,
      data: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        role: user.role,
        status: user.status,
        emailVerifiedAt: user.email_verified_at,
        createdAt: user.created_at,
        fullName: user.full_name || null,
        profilePhotoPath: user.profile_photo_path || null,
        bio: user.bio || null,
        syndicateNumber: user.syndicate_number || null,
        approvalStatus: user.approval_status || null,
        specialty: user.specialty || null,
        isApproved: user.urgent_status === 'APPROVED',
        // A client starts at five and loses a point for each proven refusal
        rating: user.role === 'lawyer' ? Number(user.rating ?? 0) : Math.max(1, 5 - Number(user.warnings_count ?? 0)),
        completedOrders: user.client_completed,
      }
    });
  });

  // POST /api/v1/users/me/profile-photo
  fastify.post('/me/profile-photo', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as { userId: string; role: string };

    const data = await request.file();
    if (!data || !['image/jpeg', 'image/png', 'image/webp'].includes(data.mimetype)) {
      return reply.status(400).send({ success: false, error: 'اختار صورة JPG أو PNG أو WEBP' });
    }

    const ext = data.mimetype === 'image/png' ? '.png' : data.mimetype === 'image/webp' ? '.webp' : '.jpg';
    const filename = `avatar_${crypto.randomUUID()}${ext}`;
    const avatarsDir = path.join(config.publicStoragePath, 'avatars');
    fs.mkdirSync(avatarsDir, { recursive: true });
    await pipeline(data.file, fs.createWriteStream(path.join(avatarsDir, filename)));

    const webPath = `/uploads/avatars/${filename}`;
    await query(
      role === 'lawyer'
        ? 'UPDATE lawyer_profiles SET profile_photo_path = $1 WHERE user_id = $2'
        : 'UPDATE users SET profile_photo_path = $1 WHERE id = $2',
      [webPath, userId]
    );
    return reply.send({ success: true, data: { profilePhotoPath: webPath } });
  });

  // PATCH /api/v1/users/me
  fastify.patch('/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as { userId: string; role: string };
    const body = request.body as { fullName?: string; bio?: string };

    if (role === 'lawyer' && (body.fullName || body.bio)) {
      const cleanName = body.fullName ? sanitizeText(body.fullName, 255) : undefined;
      const cleanBio = body.bio ? sanitizeText(body.bio, 1000) : undefined;

      await query(
        `UPDATE lawyer_profiles
         SET full_name = COALESCE($1, full_name),
             bio = COALESCE($2, bio),
             updated_at = NOW()
         WHERE user_id = $3`,
        [cleanName, cleanBio, userId]
      );
    }

    return reply.send({ success: true, message: 'تم تحديث البيانات بنجاح' });
  });

  // POST /api/v1/users/me/change-password
  fastify.post('/me/change-password', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as { userId: string };
    const schema = z.object({
      currentPassword: z.string().min(1),
      newPassword: z.string().min(8, { message: 'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف' }),
      confirmNewPassword: z.string()
    }).refine(data => data.newPassword === data.confirmNewPassword, {
      message: 'كلمة المرور الجديدة وتأكيدها غير متطابقين'
    });

    const parseResult = schema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: parseResult.error.issues[0]?.message });
    }

    const { currentPassword, newPassword } = parseResult.data;

    const credRes = await query('SELECT password_hash FROM user_credentials WHERE user_id = $1', [userId]);
    if (credRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'بيانات الاعتماد غير موجودة' });
    }

    const isValid = await verifyPassword(credRes.rows[0].password_hash, currentPassword);
    if (!isValid) {
      return reply.status(400).send({ success: false, error: 'كلمة المرور الحالية غير صحيحة' });
    }

    const newHash = await hashPassword(newPassword);
    await query('UPDATE user_credentials SET password_hash = $1, password_updated_at = NOW() WHERE user_id = $2', [newHash, userId]);

    return reply.send({ success: true, message: 'تم تغيير كلمة المرور بنجاح' });
  });
}
