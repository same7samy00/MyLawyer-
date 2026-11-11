import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import crypto from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import { config } from '../../config/index.js';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { hashPassword, verifyPassword, sanitizeText } from '../../utils/security.js';
import { z } from 'zod';
import { detectFileType } from '../../utils/files.js';
import { requireAuth } from '../../utils/http.js';
import { deletionBlocker, requestDeletion } from './deletion.js';

export async function userRoutes(fastify: FastifyInstance) {
  // Hook to authenticate all routes in this plugin
  fastify.addHook('onRequest', requireAuth());

  // GET /api/v1/users/me
  fastify.get('/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as { userId: string };

    const userRes = await query(
      `SELECT u.id, u.phone, u.email, u.role, u.status, u.email_verified_at, u.created_at,
              COALESCE(lp.full_name, u.full_name) as full_name, COALESCE(lp.profile_photo_path, u.profile_photo_path) as profile_photo_path,
              u.warnings_count, lp.rating, lp.experience_years, lp.urgent_status,
              (SELECT COUNT(*)::int FROM service_orders o WHERE o.client_id = u.id AND o.status = 'COMPLETED') as client_completed, lp.approval_status, lp.syndicate_number
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
        syndicateNumber: user.syndicate_number || null,
        approvalStatus: user.approval_status || null,
        experienceYears: user.experience_years ?? null,
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
    if (!data) return reply.status(400).send({ success: false, error: 'اختار صورة الأول' });

    // Phones often send no image type, so the file itself decides
    const buffer = await data.toBuffer();
    const type = detectFileType(buffer);
    const ext = type?.mime.startsWith('image/') ? type.ext : null;
    if (!ext) return reply.status(400).send({ success: false, error: 'الملف ده مش صورة مدعومة' });

    const filename = `avatar_${crypto.randomUUID()}${ext}`;
    const avatarsDir = path.join(config.publicStoragePath, 'avatars');
    await fs.mkdir(avatarsDir, { recursive: true });
    await fs.writeFile(path.join(avatarsDir, filename), buffer);

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
    const body = (request.body || {}) as { fullName?: string };

    if (role === 'lawyer' && body.fullName) {
      const cleanName = body.fullName ? sanitizeText(body.fullName, 255) : undefined;

      await query(
        `UPDATE lawyer_profiles
         SET full_name = COALESCE($1, full_name),
             updated_at = NOW()
         WHERE user_id = $2`,
        [cleanName, userId]
      );
    }

    return reply.send({ success: true, message: 'تم تحديث البيانات بنجاح' });
  });

  // POST /api/v1/users/me/delete - Asks to delete the account. The password confirms it is the owner; the account
  // is signed out now and wiped 30 days later, and signing in before that cancels it
  fastify.post('/me/delete', { config: { rateLimit: { max: 5, timeWindow: '1 minute' } } }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as { userId: string; role: string };
    const password = (request.body as { password?: unknown } | null)?.password;
    if (typeof password !== 'string' || !password) return reply.status(400).send({ success: false, error: 'اكتب كلمة السر عشان نتأكد إنه حسابك' });
    if (role === 'admin') return reply.status(403).send({ success: false, error: 'حساب الإدارة ما بيتمسحش من هنا' });

    const cred = await query('SELECT password_hash FROM user_credentials WHERE user_id = $1', [userId]);
    if (!cred.rows[0] || !(await verifyPassword(cred.rows[0].password_hash, password))) {
      return reply.status(400).send({ success: false, error: 'كلمة السر غلط' });
    }

    const blocker = await deletionBlocker(dbPool, { id: userId, role });
    if (blocker) return reply.status(409).send({ success: false, error: blocker });

    const deleteAt = await requestDeletion(dbPool, userId);
    return reply.send({ success: true, message: 'اتسجل طلب حذف الحساب', data: { deleteAt } });
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
    await withTransaction(async (client) => {
      await client.query('UPDATE user_credentials SET password_hash = $1, password_updated_at = NOW() WHERE user_id = $2', [newHash, userId]);
      // Whoever knew the old password loses their session too
      await client.query('UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL', [userId]);
    });

    return reply.send({ success: true, message: 'تم تغيير كلمة المرور بنجاح' });
  });
}
