import fs from 'fs';
import path from 'path';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import jwt from '@fastify/jwt';
import multipart from '@fastify/multipart';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { config } from './config/index.js';
import { authRoutes } from './modules/auth/routes.js';
import { userRoutes } from './modules/users/routes.js';
import { walletRoutes } from './modules/wallet/routes.js';
import { lawyerRoutes } from './modules/lawyers/routes.js';
import { orderRoutes } from './modules/orders/routes.js';
import { adminRoutes } from './modules/admin/routes.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { dbPool } from './database/index.js';

export function buildApp() {
  const fastify = Fastify({
    logger: config.nodeEnv === 'development',
    trustProxy: true,
  });

  // Security Headers
  fastify.register(helmet, {
    contentSecurityPolicy: false, // Served behind Nginx
  });

  // CORS
  fastify.register(cors, {
    origin: true,
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

  // Swagger Documentation
  fastify.register(swagger, {
    openapi: {
      info: {
        title: 'MyLawyer API',
        description: 'Production REST API for MyLawyer Client & Lawyer Platform',
        version: '1.0.0',
      },
      servers: [
        { url: '/api/v1', description: 'Production API' },
      ],
    },
  });

  fastify.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: false,
    },
  });

  const healthHandler = async () => {
    try {
      const dbRes = await dbPool.query('SELECT 1 as healthy');
      let appliedMigrations: any[] = [];
      try {
        const migRes = await dbPool.query('SELECT name, applied_at FROM schema_migrations ORDER BY applied_at ASC');
        appliedMigrations = migRes.rows;
      } catch {
        // table might not exist yet
      }

      return {
        status: 'UP',
        database: dbRes.rows[0].healthy === 1 ? 'CONNECTED' : 'DISCONNECTED',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        appliedMigrations,
      };
    } catch (err: any) {
      return {
        status: 'DEGRADED',
        database: 'ERROR',
        error: err.message,
        timestamp: new Date().toISOString(),
      };
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
    api.get('/admin-panel', async (_request, reply) => {
      const page = fs.readFileSync(path.resolve(process.cwd(), 'public/admin.html'), 'utf-8');
      return reply.type('text/html; charset=utf-8').send(page);
    });
    api.register(authRoutes, { prefix: '/auth' });
    api.register(userRoutes, { prefix: '/users' });
    api.register(walletRoutes, { prefix: '/wallet' });
    api.register(lawyerRoutes, { prefix: '/lawyers' });
    api.register(orderRoutes, { prefix: '/orders' });
    api.register(adminRoutes, { prefix: '/admin' });
    api.register(notificationRoutes, { prefix: '/notifications' });
  }, { prefix: '/api/v1' });

  return fastify;
}
