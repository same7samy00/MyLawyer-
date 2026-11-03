import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { notify, refreshLawyerRating, REVIEW_WINDOW_DAYS } from '../lifecycle/service.js';
import { AuthenticatedUser } from './shared.js';

/// Client ratings of a finished order
export async function registerOrderReviews(fastify: FastifyInstance) {
  // 11. POST /api/v1/orders/:id/review - Client rates a completed order
  fastify.post('/:id/review', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { rating?: number; comment?: string };

    const rating = Number(body.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return reply.status(400).send({ success: false, error: 'اختر تقييماً من 1 إلى 5' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND client_id = $2`,
      [id, userId]
    );
    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'COMPLETED') {
      return reply.status(400).send({ success: false, error: 'التقييم متاح بعد إنهاء المهمة فقط' });
    }

    const windowEnd = new Date(order.completed_at).getTime() + REVIEW_WINDOW_DAYS * 86400000;
    if (Date.now() > windowEnd) {
      return reply.status(400).send({ success: false, error: 'انتهت مدة التقييم لهذا الطلب' });
    }

    const comment = body.comment ? sanitizeText(body.comment, 1000) : null;
    const res = await query(
      `INSERT INTO reviews (order_id, client_id, lawyer_id, rating, comment, publish_at, published_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       ON CONFLICT (order_id) DO NOTHING RETURNING id`,
      [order.id, userId, order.lawyer_id, rating, comment]
    );

    if (res.rows.length === 0) {
      return reply.status(409).send({ success: false, error: 'تم تقييم هذا الطلب من قبل' });
    }

    await refreshLawyerRating(dbPool, order.lawyer_id);
    await notify(dbPool, order.lawyer_id, 'تقييم جديد', `${rating} من 5 على طلب ${order.order_number}`, order.id);
    return reply.status(201).send({ success: true, message: 'شكراً لتقييمك' });
  });

  // 16. PUT /api/v1/orders/:id/review - One edit before the review is published
  fastify.put('/:id/review', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { rating?: number; comment?: string };

    const rating = Number(body.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return reply.status(400).send({ success: false, error: 'اختر تقييماً من 1 إلى 5' });
    }

    const res = await query(
      `UPDATE reviews r SET rating = $1, comment = $2, edited = TRUE
       FROM service_orders o
       WHERE r.order_id = o.id AND (o.id::text = $3 OR o.order_number = $3) AND r.client_id = $4
         AND r.edited = FALSE AND o.completed_at > NOW() - make_interval(days => $5)
       RETURNING r.id, r.lawyer_id`,
      [rating, body.comment ? sanitizeText(body.comment, 1000) : null, id, userId, REVIEW_WINDOW_DAYS]
    );

    if (res.rows.length === 0) {
      return reply.status(400).send({ success: false, error: 'لا يمكن تعديل هذا التقييم' });
    }

    await refreshLawyerRating(dbPool, res.rows[0].lawyer_id);
    return reply.send({ success: true, message: 'تم تعديل تقييمك' });
  });
}
