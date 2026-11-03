import { FastifyInstance } from 'fastify';
import { requireAuth } from '../../utils/http.js';
import { registerOrderCreation } from './create.js';
import { registerOrderQueries } from './queries.js';
import { registerOrderDecisions } from './decisions.js';
import { registerOrderProgress } from './progress.js';
import { registerOrderReviews } from './reviews.js';

export async function orderRoutes(fastify: FastifyInstance) {
  // Authentication hook for all order endpoints
  fastify.addHook('onRequest', requireAuth());

  await registerOrderCreation(fastify);
  await registerOrderQueries(fastify);
  await registerOrderDecisions(fastify);
  await registerOrderProgress(fastify);
  await registerOrderReviews(fastify);
}
