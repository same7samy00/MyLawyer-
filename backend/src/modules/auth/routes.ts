import { FastifyInstance } from 'fastify';
import { registerSignUp } from './register.js';
import { registerSession } from './session.js';
import { registerPasswordReset } from './password.js';
import { requireAuth } from '../../utils/http.js';

/// Everything under /api/v1/auth, one file per job
export async function authRoutes(fastify: FastifyInstance) {
  await registerSignUp(fastify);
  await registerSession(fastify);
  await registerPasswordReset(fastify);

  // GET /api/v1/auth/check - Says only whether the token is good. Nginx asks it before it hands out an answer
  // it keeps for everyone (the lawyers map), so those answers stay for signed-in accounts
  fastify.get('/check', { onRequest: requireAuth() }, async () => ({ success: true }));
}
