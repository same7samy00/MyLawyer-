import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { HttpError, requireAuth } from '../../utils/http.js';
import { roadRoute } from '../../services/roadRoutes.js';

const inEgypt = (lat: number, lon: number) => Number.isFinite(lat) && Number.isFinite(lon) && lat >= 21.7 && lat <= 32 && lon >= 24.5 && lon <= 37;

/// The road between two points with live traffic, for the arrival time and the line on the map.
/// The phone asks here, so the TomTom key never leaves the server.
export async function roadRouteRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());

  fastify.get('/', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    const q = request.query as Record<string, string | undefined>;
    const from = { lat: Number(q.fromLat), lon: Number(q.fromLon) };
    const to = { lat: Number(q.toLat), lon: Number(q.toLon) };
    if (!inEgypt(from.lat, from.lon) || !inEgypt(to.lat, to.lon)) throw new HttpError(400, 'المكان غير صحيح');

    const route = await roadRoute(from, to, q.points === '1');
    if (!route) throw new HttpError(503, 'تعذر حساب الطريق دلوقتي');
    return reply.send({ success: true, data: route });
  });
}
