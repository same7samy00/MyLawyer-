import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query, withTransaction } from '../../database/index.js';
import { hashPassword, generateOtpCode, hashSha256 } from '../../utils/security.js';
import { sendOtpEmail } from '../../services/emailService.js';
import { forgotPasswordSchema, resetPasswordSchema } from './schemas.js';
import { OTP_RESEND_SECONDS, OTP_VALID_MS, takeAttempt } from './codes.js';

/// A forgotten password, reset with an emailed code
export async function registerPasswordReset(fastify: FastifyInstance) {
  // 7. POST /api/v1/auth/forgot-password
  fastify.post('/forgot-password', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = forgotPasswordSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: 'البريد الإلكتروني غير صحيح' });
    }

    const { email } = parseResult.data;
    const userRes = await query('SELECT id, email FROM users WHERE email = $1', [email]);

    // Constant-time generic response to prevent user enumeration
    if (userRes.rows.length === 0) {
      return reply.send({
        success: true,
        message: 'إذا كان البريد الإلكتروني مسجلاً، فقد تم إرسال رمز التحقق إليه.'
      });
    }

    const user = userRes.rows[0];

    // Same answer during the cooldown, so nobody can flood a mailbox or collect many live codes
    const lastRequest = await query(
      `SELECT 1 FROM password_reset_requests
       WHERE user_id = $1 AND created_at > NOW() - make_interval(secs => $2) LIMIT 1`,
      [user.id, OTP_RESEND_SECONDS]
    );
    if (lastRequest.rows.length > 0) {
      return reply.send({
        success: true,
        message: 'إذا كان البريد الإلكتروني مسجلاً، فقد تم إرسال رمز التحقق إليه.'
      });
    }

    const otp = generateOtpCode();
    const otpHash = hashSha256(otp);
    const expiresAt = new Date(Date.now() + OTP_VALID_MS);

    await query(
      'INSERT INTO password_reset_requests (user_id, otp_hash, expires_at) VALUES ($1, $2, $3)',
      [user.id, otpHash, expiresAt]
    );

    sendOtpEmail(user.email, otp, 'reset_password').catch((err) => {
      fastify.log.error(err, 'Failed to send password reset OTP');
    });

    return reply.send({
      success: true,
      message: 'إذا كان البريد الإلكتروني مسجلاً، فقد تم إرسال رمز التحقق إليه.'
    });
  });

  // 8. POST /api/v1/auth/reset-password
  fastify.post('/reset-password', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = resetPasswordSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: parseResult.error.issues[0]?.message || 'البيانات غير صالحة'
      });
    }

    const { email, otp, newPassword } = parseResult.data;
    const otpHash = hashSha256(otp);

    const userRes = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
    if (userRes.rows.length === 0) {
      return reply.status(400).send({ success: false, error: 'رمز التحقق غير صحيح أو انتهت صلاحيته' });
    }

    const user = userRes.rows[0];

    // Only the latest code counts, and its wrong guesses are limited, or six digits could be guessed
    const resetReq = await query(
      `SELECT id, otp_hash, expires_at, attempts
       FROM password_reset_requests
       WHERE user_id = $1 AND consumed_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [user.id]
    );

    if (resetReq.rows.length === 0) {
      return reply.status(400).send({ success: false, error: 'رمز التحقق غير صحيح أو منتهي' });
    }

    const reqData = resetReq.rows[0];

    if (new Date() > new Date(reqData.expires_at)) {
      return reply.status(400).send({ success: false, error: 'انتهت صلاحية رمز التحقق' });
    }

    if (!(await takeAttempt('password_reset_requests', reqData.id))) {
      return reply.status(429).send({ success: false, error: 'تم تجاوز الحد الأقصى للمحاولات الخاطئة، يرجى طلب رمز جديد' });
    }

    if (reqData.otp_hash !== otpHash) {
      return reply.status(400).send({ success: false, error: 'رمز التحقق غير صحيح أو منتهي' });
    }

    const newHash = await hashPassword(newPassword);

    await withTransaction(async (client) => {
      // Mark consumed
      await client.query('UPDATE password_reset_requests SET consumed_at = NOW() WHERE id = $1', [reqData.id]);
      // Update password
      await client.query(
        'UPDATE user_credentials SET password_hash = $1, password_updated_at = NOW() WHERE user_id = $2',
        [newHash, user.id]
      );
      // Revoke all existing sessions for security
      await client.query('UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = $1', [user.id]);
    });

    return reply.send({
      success: true,
      message: 'تم تغيير كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة.'
    });
  });
}
