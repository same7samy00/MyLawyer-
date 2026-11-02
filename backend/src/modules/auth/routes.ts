import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query, withTransaction } from '../../database/index.js';
import { 
  hashPassword, 
  verifyPassword, 
  generateOtpCode, 
  hashSha256, 
  generateSecureToken, 
  sanitizeText 
} from '../../utils/security.js';
import { sendOtpEmail } from '../../services/emailService.js';
import {
  registerSchema,
  verifyOtpSchema,
  resendOtpSchema,
  loginSchema,
  forgotPasswordSchema,
  resetPasswordSchema
} from './schemas.js';

export async function authRoutes(fastify: FastifyInstance) {

  // 1. POST /api/v1/auth/register
  fastify.post('/register', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = registerSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: parseResult.error.issues[0]?.message || 'بيانات التسجيل غير صالحة'
      });
    }

    const { phone, email, password, role, fullName, syndicateNumber, specialty, bio } = parseResult.data;

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
    const otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

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
          `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, specialty, bio, approval_status, is_available)
           VALUES ($1, $2, $3, $4, $5, 'approved', FALSE)`,
          [
            user.id,
            cleanName,
            syndicateNumber || null,
            specialty ? sanitizeText(specialty, 100) : null,
            bio ? sanitizeText(bio, 150) : null,
          ]
        );
      }

      return user;
    });

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

    if (verif.attempts >= 5) {
      return reply.status(429).send({ success: false, error: 'تم تجاوز الحد الأقصى للمحاولات الخاطئة، يرجى طلب رمز جديد' });
    }

    if (verif.otp_hash !== otpHash) {
      await query('UPDATE email_verifications SET attempts = attempts + 1 WHERE id = $1', [verif.id]);
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
        await client.query(
          `UPDATE lawyer_profiles
           SET approval_status = 'approved', approved_at = NOW(), is_available = TRUE, updated_at = NOW()
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

    // Check rate limit: Cooldown of 60 seconds
    const lastOtp = await query(
      `SELECT created_at FROM email_verifications
       WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [user.id]
    );

    if (lastOtp.rows.length > 0) {
      const elapsedSec = (Date.now() - new Date(lastOtp.rows[0].created_at).getTime()) / 1000;
      if (elapsedSec < 60) {
        return reply.status(429).send({
          success: false,
          error: `يرجى الانتظار ${Math.ceil(60 - elapsedSec)} ثانية قبل طلب رمز تحقق جديد`
        });
      }
    }

    const newCode = generateOtpCode();
    const newHash = hashSha256(newCode);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

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

  // 4. POST /api/v1/auth/login
  fastify.post('/login', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = loginSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: parseResult.error.issues[0]?.message || 'بيانات الدخول غير مكتملة'
      });
    }

    const { identifier, password, rememberMe } = parseResult.data;

    // Search by email or phone
    const userRes = await query(
      `SELECT u.id, u.phone, u.email, u.role, u.status, u.email_verified_at, uc.password_hash,
              COALESCE(lp.full_name, u.full_name) as full_name, lp.profile_photo_path, lp.approval_status, lp.rejection_reason
       FROM users u
       JOIN user_credentials uc ON u.id = uc.user_id
       LEFT JOIN lawyer_profiles lp ON u.id = lp.user_id
       WHERE u.email = $1 OR u.phone = $1`,
      [identifier.toLowerCase()]
    );

    if (userRes.rows.length === 0) {
      return reply.status(401).send({ success: false, error: 'بيانات الدخول غير صحيحة، تأكد من رقم الهاتف/الإيميل وكلمة المرور' });
    }

    const user = userRes.rows[0];

    const isValid = await verifyPassword(user.password_hash, password);
    if (!isValid) {
      return reply.status(401).send({ success: false, error: 'بيانات الدخول غير صحيحة، تأكد من رقم الهاتف/الإيميل وكلمة المرور' });
    }

    // Check account statuses
    if (user.status === 'suspended') {
      return reply.status(403).send({
        success: false,
        error: 'تم إيقاف هذا الحساب من قِبل إدارة التطبيق. يرجى التواصل مع الدعم الفني.',
        data: { status: 'suspended' }
      });
    }

    if (user.status === 'rejected') {
      return reply.status(403).send({
        success: false,
        error: `تم رفض طلب تسجيل المحامي: ${user.rejection_reason || 'المستندات غير مطابقة للشروط'}`,
        data: { status: 'rejected', reason: user.rejection_reason }
      });
    }

    if (user.status === 'pending_email_verification') {
      return reply.status(403).send({
        success: false,
        error: 'يرجى تأكيد بريدك الإلكتروني أولاً لتفعيل حسابك',
        data: { status: 'pending_email_verification', email: user.email }
      });
    }

    // Generate JWT Access Token (15 mins) & Refresh Token (30 days)
    const accessToken = fastify.jwt.sign(
      {
        userId: user.id,
        role: user.role,
        status: user.status
      },
      { expiresIn: '15m' }
    );

    const refreshToken = generateSecureToken(32);
    const refreshHash = hashSha256(refreshToken);
    const refreshExpires = new Date(Date.now() + (rememberMe ? 60 : 30) * 24 * 60 * 60 * 1000);

    // Save session in database
    await query(
      `INSERT INTO user_sessions (user_id, refresh_token_hash, user_agent, ip_address, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        user.id,
        refreshHash,
        request.headers['user-agent'] || 'Unknown',
        request.ip || '127.0.0.1',
        refreshExpires
      ]
    );

    return reply.send({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          phone: user.phone,
          email: user.email,
          role: user.role,
          status: user.status,
          fullName: user.full_name || null,
          profilePhotoPath: user.profile_photo_path || null,
          lawyerApprovalStatus: user.approval_status || null
        }
      }
    });
  });

  // 5. POST /api/v1/auth/refresh
  fastify.post('/refresh', async (request: FastifyRequest, reply: FastifyReply) => {
    const { refreshToken } = request.body as { refreshToken?: string };
    if (!refreshToken) {
      return reply.status(400).send({ success: false, error: 'Refresh Token مطلوب' });
    }

    const refreshHash = hashSha256(refreshToken);
    const sessionRes = await query(
      `SELECT s.id, s.user_id, s.expires_at, s.revoked_at, u.role, u.status
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE s.refresh_token_hash = $1`,
      [refreshHash]
    );

    if (sessionRes.rows.length === 0) {
      return reply.status(401).send({ success: false, error: 'جلسة غير صالحة، يرجى إعادة تسجيل الدخول' });
    }

    const session = sessionRes.rows[0];

    if (session.revoked_at || new Date() > new Date(session.expires_at)) {
      return reply.status(401).send({ success: false, error: 'انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول' });
    }

    if (session.status === 'suspended') {
      return reply.status(403).send({ success: false, error: 'الحساب موقوف', data: { status: 'suspended' } });
    }

    // Refresh Token Rotation: Revoke old session, create new session
    const newRefreshToken = generateSecureToken(32);
    const newRefreshHash = hashSha256(newRefreshToken);
    const newExpires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    await withTransaction(async (client) => {
      await client.query('UPDATE user_sessions SET revoked_at = NOW() WHERE id = $1', [session.id]);
      await client.query(
        `INSERT INTO user_sessions (user_id, refresh_token_hash, user_agent, ip_address, expires_at)
         VALUES ($1, $2, $3, $4, $5)`,
        [session.user_id, newRefreshHash, request.headers['user-agent'] || 'Unknown', request.ip || '127.0.0.1', newExpires]
      );
    });

    const newAccessToken = fastify.jwt.sign(
      {
        userId: session.user_id,
        role: session.role,
        status: session.status
      },
      { expiresIn: '15m' }
    );

    return reply.send({
      success: true,
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken
      }
    });
  });

  // 6. POST /api/v1/auth/logout
  fastify.post('/logout', async (request: FastifyRequest, reply: FastifyReply) => {
    const { refreshToken } = (request.body || {}) as { refreshToken?: string };
    if (refreshToken) {
      const hash = hashSha256(refreshToken);
      await query('UPDATE user_sessions SET revoked_at = NOW() WHERE refresh_token_hash = $1', [hash]);
    }
    return reply.send({ success: true, message: 'تم تسجيل الخروج بنجاح' });
  });

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
    const otp = generateOtpCode();
    const otpHash = hashSha256(otp);
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins

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

    const resetReq = await query(
      `SELECT id, expires_at, attempts, consumed_at
       FROM password_reset_requests
       WHERE user_id = $1 AND otp_hash = $2 AND consumed_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [user.id, otpHash]
    );

    if (resetReq.rows.length === 0) {
      return reply.status(400).send({ success: false, error: 'رمز التحقق غير صحيح أو منتهي' });
    }

    const reqData = resetReq.rows[0];

    if (new Date() > new Date(reqData.expires_at)) {
      return reply.status(400).send({ success: false, error: 'انتهت صلاحية رمز التحقق' });
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

