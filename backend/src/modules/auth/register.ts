import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query, withTransaction } from '../../database/index.js';
import { hashPassword, generateOtpCode, hashSha256, sanitizeText } from '../../utils/security.js';
import { sendOtpEmail } from '../../services/emailService.js';
import { registerSchema, verifyOtpSchema, resendOtpSchema } from './schemas.js';
import { OTP_RESEND_SECONDS, OTP_VALID_MS, takeAttempt } from './codes.js';

const UNIQUE_VIOLATION = '23505';

/// Creating an account and activating it with the emailed code
export async function registerSignUp(fastify: FastifyInstance) {
  // 1. POST /api/v1/auth/register
  fastify.post('/register', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = registerSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: parseResult.error.issues[0]?.message || 'بيانات التسجيل غير صالحة'
      });
    }

    const { phone, email, password, role, fullName, syndicateNumber, experienceYears } = parseResult.data;

    // Check unique phone and email
    const existing = await query(
      'SELECT id, phone, email FROM users WHERE phone = $1 OR email = $2',
      [phone, email]
    );

    if (existing.rows.length > 0) {
      const match = existing.rows[0];
      if (match.phone === phone) {
        return reply.status(409).send({ success: false, error: 'رقم الهاتف مسجل بالفعل مسبقاً' });
      }
      if (match.email === email) {
        return reply.status(409).send({ success: false, error: 'البريد الإلكتروني مسجل بالفعل مسبقاً' });
      }
    }

    const pwdHash = await hashPassword(password);
    const otpCode = generateOtpCode();
    const otpHash = hashSha256(otpCode);
    const otpExpires = new Date(Date.now() + OTP_VALID_MS);

    // Create user in database transaction
    const newUser = await withTransaction(async (client) => {
      // 1. Insert user
      const userRes = await client.query(
        `INSERT INTO users (phone, email, role, status, full_name)
         VALUES ($1, $2, $3, 'pending_email_verification', $4)
         RETURNING id, phone, email, role, status, created_at`,
        [phone, email, role, fullName ? sanitizeText(fullName, 255) : null]
      );
      const user = userRes.rows[0];

      // 2. Insert password credentials
      await client.query(
        `INSERT INTO user_credentials (user_id, password_hash)
         VALUES ($1, $2)`,
        [user.id, pwdHash]
      );

      // 3. Insert email verification OTP
      await client.query(
        `INSERT INTO email_verifications (user_id, otp_hash, expires_at)
         VALUES ($1, $2, $3)`,
        [user.id, otpHash, otpExpires]
      );

      // 4. If lawyer, create initial profile - directly approved and active as requested
      if (role === 'lawyer') {
        const cleanName = sanitizeText(fullName || 'محامٍ جديد', 255);
        await client.query(
          // No place until the phone sends a real one, so the lawyer stays off the map
          `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, experience_years, approval_status, is_available)
           VALUES ($1, $2, $3, $4, 'approved', FALSE)`,
          [
            user.id,
            cleanName,
            syndicateNumber || null,
            experienceYears ?? 0,
          ]
        );
      }

      return user;
    }).catch((err) => {
      // Two requests with the same details at once, and the first one already took them
      if (err.code === UNIQUE_VIOLATION) return null;
      throw err;
    });

    if (!newUser) {
      return reply.status(409).send({ success: false, error: 'رقم الهاتف أو البريد الإلكتروني مسجل بالفعل مسبقاً' });
    }

    // Send email asynchronously
    sendOtpEmail(email, otpCode, 'register').catch((err) => {
      fastify.log.error(err, 'Failed to send registration OTP email');
    });

    return reply.status(201).send({
      success: true,
      message: 'تم إنشاء الحساب بنجاح، يرجى إدخال رمز التحقق (OTP) المرسل إلى بريدك الإلكتروني',
      data: {
        userId: newUser.id,
        email: newUser.email,
        phone: newUser.phone,
        role: newUser.role,
        status: newUser.status
      }
    });
  });

  // 2. POST /api/v1/auth/verify-otp
  fastify.post('/verify-otp', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = verifyOtpSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: parseResult.error.issues[0]?.message || 'البيانات غير صالحة'
      });
    }

    const { email, otp } = parseResult.data;
    const otpHash = hashSha256(otp);

    const userRes = await query(
      'SELECT id, role, status FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (userRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'المستخدم غير مسجل' });
    }

    const user = userRes.rows[0];

    // Only a new account is activated here, otherwise a suspended person could lift their own suspension
    if (user.status !== 'pending_email_verification') {
      return reply.status(409).send({ success: false, error: 'الحساب ده مش مستني تفعيل، سجل دخولك' });
    }

    // Check verification OTP
    const verifRes = await query(
      `SELECT id, otp_hash, expires_at, attempts, consumed_at
       FROM email_verifications
       WHERE user_id = $1 AND consumed_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [user.id]
    );

    if (verifRes.rows.length === 0) {
      return reply.status(400).send({ success: false, error: 'لا يوجد رمز تحقق نشط، يرجى طلب رمز جديد' });
    }

    const verif = verifRes.rows[0];

    if (new Date() > new Date(verif.expires_at)) {
      return reply.status(400).send({ success: false, error: 'انتهت صلاحية رمز التحقق، يرجى طلب رمز جديد' });
    }

    // Each guess takes its attempt before the comparison, so guesses sent together can't pass the limit
    if (!(await takeAttempt('email_verifications', verif.id))) {
      return reply.status(429).send({ success: false, error: 'تم تجاوز الحد الأقصى للمحاولات الخاطئة، يرجى طلب رمز جديد' });
    }

    if (verif.otp_hash !== otpHash) {
      return reply.status(400).send({ success: false, error: 'رمز التحقق غير صحيح، يرجى المحاولة مرة أخرى' });
    }

    // Determine target status:
    // Client and Lawyer both become active immediately as requested
    const targetStatus = 'active';

    await withTransaction(async (client) => {
      // Mark OTP consumed
      await client.query('UPDATE email_verifications SET consumed_at = NOW() WHERE id = $1', [verif.id]);
      // Update user status
      await client.query(
        `UPDATE users
         SET status = $1, email_verified_at = NOW(), updated_at = NOW()
         WHERE id = $2`,
        [targetStatus, user.id]
      );
      if (user.role === 'lawyer') {
        // Availability stays with the lawyer's own button, after the admin approves the service
        await client.query(
          `UPDATE lawyer_profiles
           SET approval_status = 'approved', approved_at = NOW(), updated_at = NOW()
           WHERE user_id = $1`,
          [user.id]
        );
      }
    });

    return reply.send({
      success: true,
      message: 'تم تفعيل حسابك بنجاح! يمكنك الآن استخدام كافة خدمات التطبيق.',
      data: {
        userId: user.id,
        role: user.role,
        status: targetStatus
      }
    });
  });

  // 3. POST /api/v1/auth/resend-otp
  fastify.post('/resend-otp', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = resendOtpSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: 'البريد الإلكتروني غير صحيح' });
    }

    const { email } = parseResult.data;
    const userRes = await query('SELECT id, email, status FROM users WHERE email = $1', [email.toLowerCase()]);
    if (userRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'البريد الإلكتروني غير مسجل' });
    }

    const user = userRes.rows[0];

    if (user.status !== 'pending_email_verification') {
      return reply.status(409).send({ success: false, error: 'الحساب ده مش مستني تفعيل، سجل دخولك' });
    }

    // Check rate limit: Cooldown of 60 seconds
    const lastOtp = await query(
      `SELECT created_at FROM email_verifications
       WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [user.id]
    );

    if (lastOtp.rows.length > 0) {
      const elapsedSec = (Date.now() - new Date(lastOtp.rows[0].created_at).getTime()) / 1000;
      if (elapsedSec < OTP_RESEND_SECONDS) {
        return reply.status(429).send({
          success: false,
          error: `يرجى الانتظار ${Math.ceil(OTP_RESEND_SECONDS - elapsedSec)} ثانية قبل طلب رمز تحقق جديد`
        });
      }
    }

    const newCode = generateOtpCode();
    const newHash = hashSha256(newCode);
    const expiresAt = new Date(Date.now() + OTP_VALID_MS);

    await query(
      'INSERT INTO email_verifications (user_id, otp_hash, expires_at) VALUES ($1, $2, $3)',
      [user.id, newHash, expiresAt]
    );

    sendOtpEmail(user.email, newCode, 'register').catch((err) => {
      fastify.log.error(err, 'Failed to resend registration OTP');
    });

    return reply.send({
      success: true,
      message: 'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني'
    });
  });
}
