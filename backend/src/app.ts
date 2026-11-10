import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import jwt from '@fastify/jwt';
import multipart from '@fastify/multipart';
import { config } from './config/index.js';
import { HttpError } from './utils/http.js';
import { BusyError } from './utils/security.js';
import { authRoutes } from './modules/auth/routes.js';
import { userRoutes } from './modules/users/routes.js';
import { walletRoutes } from './modules/wallet/routes.js';
import { supportRoutes } from './modules/support/routes.js';
import { consultationRoutes } from './modules/consultations/routes.js';
import { lawyerRoutes } from './modules/lawyers/routes.js';
import { orderRoutes } from './modules/orders/routes.js';
import { requestRoutes } from './modules/requests/routes.js';
import { roadRouteRoutes } from './modules/routes/routes.js';
import { closeAllLines, openLine } from './services/liveUpdates.js';
import { requireAuth } from './utils/http.js';
import { adminRoutes } from './modules/admin/routes.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { registerAdminPanel } from './modules/admin/panel.js';
import { dbPool } from './database/index.js';
import { fastMemory, fastMemoryState, knownActive, rememberActive } from './services/fastMemory.js';

// PostgreSQL's code for a value of the wrong type, like a malformed id in a link
const INVALID_TEXT_FOR_TYPE = '22P02';

export function buildApp() {
  const fastify = Fastify({
    logger: config.nodeEnv === 'test' ? false : { level: config.nodeEnv === 'production' ? 'warn' : 'info' },
    // Only Nginx may name the caller, so nobody can pose as another address. On the second server Nginx is the
    // main server, reached over the private link, so TRUST_PROXY names it there
    trustProxy: process.env.TRUST_PROXY || 'loopback',
  });

  // Nothing technical reaches the caller, and every server failure reaches the log
  fastify.setErrorHandler((error: Error & { statusCode?: number; code?: string }, request, reply) => {
    if (error instanceof HttpError) {
      return reply.status(error.status).send({ success: false, error: error.message });
    }
    // Too many password checks waiting: the app waits a moment and tries again by itself
    if (error instanceof BusyError) {
      return reply.status(503).header('Retry-After', '1').send({ success: false, error: 'فيه ضغط دلوقتي، ثانية واحدة وبنكمّل' });
    }
    if (error.code === INVALID_TEXT_FOR_TYPE) {
      return reply.status(400).send({ success: false, error: 'المعرف غير صالح' });
    }
    const status = error.statusCode ?? 500;
    if (status >= 500) {
      request.log.error(error);
      return reply.status(500).send({ success: false, error: 'حدث خطأ غير متوقع، حاول مرة أخرى بعد قليل' });
    }
    return reply.status(status).send({ success: false, error: error.message });
  });

  // Security Headers
  fastify.register(helmet, {
    contentSecurityPolicy: false, // Served behind Nginx
  });

  // CORS
  fastify.register(cors, {
    // The app sends no Origin and the control page is same-origin, so other sites are refused
    origin: config.corsOrigin.includes('*') ? false : config.corsOrigin,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  // Rate Limiter
  // Mobile networks put many phones behind one IP, so signed-in users count by account.
  // Counted in the fast memory, so every worker on both servers shares one count. If it stops answering,
  // requests go through rather than fail
  const memory = fastMemory();
  fastify.register(rateLimit, {
    ...(memory ? { redis: memory, nameSpace: 'limit:', skipOnError: true } : {}),
    max: (_request, key) => {
      if (config.nodeEnv === 'test') return 100000;
      if (key.startsWith('auth:')) return 120;
      return key.startsWith('user:') ? 300 : 600;
    },
    timeWindow: '1 minute',
    keyGenerator: (request) => {
      if (request.url.startsWith('/api/v1/auth')) return `auth:${request.ip}`;

      const token = request.headers.authorization?.replace(/^Bearer\s+/i, '');
      if (token) {
        try {
          return `user:${fastify.jwt.verify<{ userId: string }>(token).userId}`;
        } catch {
          // An invalid token counts against the IP like any anonymous request
        }
      }
      return request.ip;
    },
  });

  // Multipart uploads (files up to 10MB)
  fastify.register(multipart, {
    limits: {
      fileSize: 10 * 1024 * 1024,
      files: 2,
    },
  });

  // JWT
  fastify.register(jwt, {
    secret: config.jwtSecret,
  });

  // API explorer on a developer's machine only, so production carries neither the page nor its packages
  if (config.nodeEnv === 'development') {
    fastify.register(import('@fastify/swagger'), {
      openapi: {
        info: {
          title: 'MyLawyer API',
          description: 'REST API for MyLawyer Client & Lawyer Platform',
          version: '1.0.0',
        },
        servers: [
          { url: '/api/v1', description: 'API' },
        ],
      },
    });

    fastify.register(import('@fastify/swagger-ui'), {
      routePrefix: '/docs',
      uiConfig: {
        docExpansion: 'list',
        deepLinking: false,
      },
    });
  }

  // Public, so it says only whether the service works
  const healthHandler = async () => {
    try {
      await dbPool.query('SELECT 1');
      // The release lets deploy.sh see that the new code is the one answering.
      // The app works without the fast memory, so its state is told but doesn't change UP
      return { status: 'UP', database: 'CONNECTED', fastMemory: await fastMemoryState(), release: process.env.MYLAWYER_RELEASE || null };
    } catch {
      return { status: 'DEGRADED', database: 'ERROR' };
    }
  };

  // Health check endpoint (root & versioned)
  fastify.get('/health', healthHandler);

  // Register API modules under /api/v1
  fastify.register(async (api) => {
    // A suspended account is refused everywhere, even with a valid sign-in
    api.addHook('preHandler', async (request, reply) => {
      const user = request.user as { userId?: string } | undefined;
      if (!user?.userId || request.url.endsWith('/notifications/device-token/remove')) return;

      // Seen active a few seconds ago: the database is not asked again
      if (await knownActive(user.userId)) return;
      const res = await dbPool.query('SELECT status, suspended_until FROM users WHERE id = $1', [user.userId]);
      if (res.rows[0]?.status === 'suspended') {
        return reply.status(403).send({ success: false, error: 'تم إيقاف هذا الحساب', data: { status: 'suspended', suspendedUntil: res.rows[0].suspended_until } });
      }
      if (res.rows[0]?.status === 'active') rememberActive(user.userId);
    });

    api.get('/health', healthHandler);
    // The open line that tells the app something changed
    api.get('/events', { onRequest: requireAuth() }, async (request, reply) => {
      const { userId, role } = request.user as { userId: string; role?: string };
      reply.hijack();
      openLine(userId, reply.raw, role === 'admin');
    });
    // What changed after a number the app already has. Too far back, and the app reloads everything
    api.get('/events/since', { onRequest: requireAuth() }, async (request) => {
      const { userId } = request.user as { userId: string };
      const given = (request.query as { after?: string }).after;
      const latest = await dbPool.query('SELECT COALESCE(MAX(id), 0)::bigint AS last FROM change_log WHERE user_id = $1', [userId]);
      const last = Number(latest.rows[0].last);
      // An app with no number yet starts from the newest one
      if (given === undefined || given === '') return { success: true, data: { last, reset: true, changes: [] } };
      const after = Math.max(0, Number(given) || 0);
      const res = await dbPool.query(
        'SELECT id, kind, entity_id FROM change_log WHERE user_id = $1 AND id > $2 ORDER BY id LIMIT 201',
        [userId, after]
      );
      const oldest = await dbPool.query('SELECT MIN(id)::bigint AS first FROM change_log');
      // The changes after this number were already removed, so the app reloads everything
      const gone = after > 0 && Number(oldest.rows[0].first ?? 0) > after + 1;
      return {
        success: true,
        data: {
          last,
          reset: gone || res.rows.length > 200,
          changes: res.rows.slice(0, 200).map((row) => ({ kind: row.kind, entityId: row.entity_id })),
        },
      };
    });
    registerAdminPanel(api);
    api.register(authRoutes, { prefix: '/auth' });
    api.register(userRoutes, { prefix: '/users' });
    api.register(walletRoutes, { prefix: '/wallet' });
    api.register(supportRoutes, { prefix: '/support' });
    api.register(consultationRoutes, { prefix: '/consultations' });
    api.register(lawyerRoutes, { prefix: '/lawyers' });
    api.register(orderRoutes, { prefix: '/orders' });
    api.register(requestRoutes, { prefix: '/requests' });
    api.register(roadRouteRoutes, { prefix: '/routes' });
    api.register(adminRoutes, { prefix: '/admin' });
    api.register(notificationRoutes, { prefix: '/notifications' });
  }, { prefix: '/api/v1' });

  // Open lines would otherwise hold a restart forever
  fastify.addHook('preClose', async () => closeAllLines());

  return fastify;
}
