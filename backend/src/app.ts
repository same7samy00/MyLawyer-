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
import { lawyerRoutes } from './modules/lawyers/routes.js';
import { orderRoutes } from './modules/orders/routes.js';
import { adminRoutes } from './modules/admin/routes.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { dbPool } from './database/index.js';
import { runMigrations } from './database/migrate.js';

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
  fastify.register(rateLimit, {
    max: config.nodeEnv === 'test' ? 100000 : 120,
    timeWindow: '1 minute',
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

  // Migration trigger & debug endpoint
  fastify.get('/health/migrate', async () => {
    try {
      const count = await runMigrations(false);
      return { success: true, appliedCount: count };
    } catch (err: any) {
      return {
        success: false,
        error: err.message,
        detail: err.detail || err.hint || null,
        stack: err.stack,
      };
    }
  });

  // Register API modules under /api/v1
  fastify.register(async (api) => {
    api.get('/health', healthHandler);
    api.get('/health/migrate', async () => {
      try {
        const count = await runMigrations(false);
        return { success: true, appliedCount: count };
      } catch (err: any) {
        return {
          success: false,
          error: err.message,
          detail: err.detail || err.hint || null,
          stack: err.stack,
        };
      }
    });
    api.get('/admin-panel', async (_request, reply) => {
      const page = fs.readFileSync(path.resolve(process.cwd(), 'public/admin.html'), 'utf-8');
      return reply.type('text/html; charset=utf-8').send(page);
    });
    api.register(authRoutes, { prefix: '/auth' });
    api.register(userRoutes, { prefix: '/users' });
    api.register(lawyerRoutes, { prefix: '/lawyers' });
    api.register(orderRoutes, { prefix: '/orders' });
    api.register(adminRoutes, { prefix: '/admin' });
    api.register(notificationRoutes, { prefix: '/notifications' });
  }, { prefix: '/api/v1' });

  return fastify;
}
