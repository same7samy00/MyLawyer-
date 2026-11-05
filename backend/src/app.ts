import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import jwt from '@fastify/jwt';
import multipart from '@fastify/multipart';
import { config } from './config/index.js';
import { HttpError } from './utils/http.js';
import { authRoutes } from './modules/auth/routes.js';
import { userRoutes } from './modules/users/routes.js';
import { walletRoutes } from './modules/wallet/routes.js';
import { supportRoutes } from './modules/support/routes.js';
import { lawyerRoutes } from './modules/lawyers/routes.js';
import { orderRoutes } from './modules/orders/routes.js';
import { requestRoutes } from './modules/requests/routes.js';
import { adminRoutes } from './modules/admin/routes.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { registerAdminPanel } from './modules/admin/panel.js';
import { dbPool } from './database/index.js';

// PostgreSQL's code for a value of the wrong type, like a malformed id in a link
const INVALID_TEXT_FOR_TYPE = '22P02';

export function buildApp() {
  const fastify = Fastify({
    logger: config.nodeEnv === 'test' ? false : { level: config.nodeEnv === 'production' ? 'warn' : 'info' },
    // Only Nginx on this machine may name the caller, so nobody can pose as another address
    trustProxy: 'loopback',
  });

  // Nothing technical reaches the caller, and every server failure reaches the log
  fastify.setErrorHandler((error: Error & { statusCode?: number; code?: string }, request, reply) => {
    if (error instanceof HttpError) {
      return reply.status(error.status).send({ success: false, error: error.message });
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
  // Mobile networks put many phones behind one IP, so signed-in users count by account
  fastify.register(rateLimit, {
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
      return { status: 'UP', database: 'CONNECTED' };
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

      const res = await dbPool.query('SELECT status FROM users WHERE id = $1', [user.userId]);
      if (res.rows[0]?.status === 'suspended') {
        return reply.status(403).send({ success: false, error: 'تم إيقاف هذا الحساب', data: { status: 'suspended' } });
      }
    });

    api.get('/health', healthHandler);
    registerAdminPanel(api);
    api.register(authRoutes, { prefix: '/auth' });
    api.register(userRoutes, { prefix: '/users' });
    api.register(walletRoutes, { prefix: '/wallet' });
    api.register(supportRoutes, { prefix: '/support' });
    api.register(lawyerRoutes, { prefix: '/lawyers' });
    api.register(orderRoutes, { prefix: '/orders' });
    api.register(requestRoutes, { prefix: '/requests' });
    api.register(adminRoutes, { prefix: '/admin' });
    api.register(notificationRoutes, { prefix: '/notifications' });
  }, { prefix: '/api/v1' });

  return fastify;
}
