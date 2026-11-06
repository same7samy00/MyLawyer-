import { FastifyInstance } from 'fastify';
import { registerSignUp } from './register.js';
import { registerSession } from './session.js';
import { registerPasswordReset } from './password.js';

/// Everything under /api/v1/auth, one file per job
export async function authRoutes(fastify: FastifyInstance) {
  await registerSignUp(fastify);
  await registerSession(fastify);
  await registerPasswordReset(fastify);
}
