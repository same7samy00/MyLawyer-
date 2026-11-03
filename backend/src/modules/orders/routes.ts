import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { registerOrderCreation } from './create.js';
import { registerOrderQueries } from './queries.js';
import { registerOrderDecisions } from './decisions.js';
import { registerOrderProgress } from './progress.js';
import { registerOrderReviews } from './reviews.js';

export async function orderRoutes(fastify: FastifyInstance) {
  // Authentication hook for all order endpoints
  fastify.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }
  });

  await registerOrderCreation(fastify);
  await registerOrderQueries(fastify);
  await registerOrderDecisions(fastify);
  await registerOrderProgress(fastify);
  await registerOrderReviews(fastify);
}
