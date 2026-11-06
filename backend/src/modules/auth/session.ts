import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query, withTransaction } from '../../database/index.js';
import { verifyPassword, hashSha256, generateSecureToken } from '../../utils/security.js';
import { clearLoginFailures, isLoginLocked, recordLoginFailure } from './loginAttempts.js';
import { loginSchema } from './schemas.js';

/// Signing in, renewing the session and signing out
export async function registerSession(fastify: FastifyInstance) {
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
    const attemptKey = identifier.toLowerCase();

    if (isLoginLocked(attemptKey)) {
      return reply.status(429).send({ success: false, error: 'محاولات دخول كتير على الحساب ده، استنى 10 دقايق وحاول تاني' });
    }

    // Search by email or phone
    const userRes = await query(
      `SELECT u.id, u.phone, u.email, u.role, u.status, u.suspended_until, u.email_verified_at, uc.password_hash,
              COALESCE(lp.full_name, u.full_name) as full_name, lp.profile_photo_path, lp.approval_status, lp.rejection_reason
       FROM users u
       JOIN user_credentials uc ON u.id = uc.user_id
       LEFT JOIN lawyer_profiles lp ON u.id = lp.user_id
       WHERE u.email = $1 OR u.phone = $1`,
      [identifier.toLowerCase()]
    );

    if (userRes.rows.length === 0) {
      recordLoginFailure(attemptKey);
      return reply.status(401).send({ success: false, error: 'بيانات الدخول غير صحيحة، تأكد من رقم الهاتف/الإيميل وكلمة المرور' });
    }

    const user = userRes.rows[0];

    const isValid = await verifyPassword(user.password_hash, password);
    if (!isValid) {
      recordLoginFailure(attemptKey);
      return reply.status(401).send({ success: false, error: 'بيانات الدخول غير صحيحة، تأكد من رقم الهاتف/الإيميل وكلمة المرور' });
    }
    clearLoginFailures(attemptKey);

    // Check account statuses
    if (user.status === 'suspended') {
      return reply.status(403).send({
        success: false,
        error: 'تم إيقاف هذا الحساب من قِبل إدارة التطبيق. يرجى التواصل مع الدعم الفني.',
        data: { status: 'suspended', suspendedUntil: user.suspended_until }
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
    const { refreshToken } = (request.body || {}) as { refreshToken?: unknown };
    if (!refreshToken || typeof refreshToken !== 'string') {
      return reply.status(400).send({ success: false, error: 'انتهت الجلسة، سجل الدخول مرة أخرى' });
    }

    const refreshHash = hashSha256(refreshToken);
    const sessionRes = await query(
      `SELECT s.id, s.user_id, s.expires_at, s.revoked_at, u.role, u.status, u.suspended_until
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
      return reply.status(403).send({ success: false, error: 'الحساب موقوف', data: { status: 'suspended', suspendedUntil: session.suspended_until } });
    }

    // Refresh Token Rotation: Revoke old session, create new session
    const newRefreshToken = generateSecureToken(32);
    const newRefreshHash = hashSha256(newRefreshToken);
    const newExpires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    // One token buys one renewal, even when it arrives twice at the same moment
    const rotated = await withTransaction(async (client) => {
      const revoked = await client.query('UPDATE user_sessions SET revoked_at = NOW() WHERE id = $1 AND revoked_at IS NULL', [session.id]);
      if (revoked.rowCount === 0) return false;
      await client.query(
        `INSERT INTO user_sessions (user_id, refresh_token_hash, user_agent, ip_address, expires_at)
         VALUES ($1, $2, $3, $4, $5)`,
        [session.user_id, newRefreshHash, request.headers['user-agent'] || 'Unknown', request.ip || '127.0.0.1', newExpires]
      );
      return true;
    });
    if (!rotated) {
      return reply.status(401).send({ success: false, error: 'انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول' });
    }

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
    const { refreshToken } = (request.body || {}) as { refreshToken?: unknown };
    if (refreshToken && typeof refreshToken === 'string') {
      const hash = hashSha256(refreshToken);
      await query('UPDATE user_sessions SET revoked_at = NOW() WHERE refresh_token_hash = $1', [hash]);
    }
    return reply.send({ success: true, message: 'تم تسجيل الخروج بنجاح' });
  });
}
