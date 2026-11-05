import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { AuthenticatedUser, HttpError, requireAuth, UUID_PATTERN } from '../../utils/http.js';
import { lawyerHasOpenOrder, lawyerShare, LAWYER_RESPONSE_SECONDS, notify, PAYMENT_MINUTES } from '../lifecycle/service.js';
import { governorateOf } from '../orders/shared.js';
import { LAWYER_CAN_WORK, LIVE_OFFERS, priceRangeFor, ROUND_SECONDS, sendRound } from './service.js';

const ROAD_FACTOR = 1.4;
const CITY_SPEED_KMH = 30;

const secondsUntil = (date: string | Date) => Math.max(0, Math.ceil((new Date(date).getTime() - Date.now()) / 1000));
const roundedKm = (value: unknown) => Number(Number(value).toFixed(1));

function requireId(id: string) {
  if (!UUID_PATTERN.test(id)) throw new HttpError(404, 'الطلب غير موجود');
}

export async function requestRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());

  // The price limits shown to the client before sending
  fastify.get('/range', async (request: FastifyRequest, reply: FastifyReply) => {
    const { problemType } = request.query as { problemType?: string };
    const range = await priceRangeFor(dbPool, problemType ? sanitizeText(problemType, 100) : null);
    return reply.send({ success: true, data: { minPrice: range.minPrice, maxPrice: range.maxPrice } });
  });

  // The client sends one request, and the nearest lawyers receive it together
  fastify.post('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    if (role !== 'client') throw new HttpError(403, 'الطلبات مخصصة للموكلين');

    const body = (request.body || {}) as {
      serviceTitle?: string; problemType?: string; problemDescription?: string;
      clientLat?: number; clientLon?: number; clientAddress?: string;
    };
    if (typeof body.problemDescription !== 'string' || !body.problemDescription.trim()) {
      throw new HttpError(400, 'يرجى كتابة وصف تفصيلي للمشكلة أو المهمة');
    }
    const description = sanitizeText(body.problemDescription, 3000);
    const lat = Number(body.clientLat);
    const lon = Number(body.clientLon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) throw new HttpError(400, 'إحداثيات موقع العميل غير صالحة');

    const problemType = body.problemType ? sanitizeText(body.problemType, 100) : null;

    const created = await withTransaction(async (client) => {
      await client.query('SELECT id FROM users WHERE id = $1 FOR NO KEY UPDATE', [userId]);

      const open = await client.query(`SELECT * FROM service_requests WHERE client_id = $1 AND status = 'OPEN' LIMIT 1`, [userId]);
      if (open.rows[0]) return open.rows[0];

      const openOrder = await client.query(
        `SELECT 1 FROM service_orders WHERE client_id = $1 AND status IN ('PENDING', 'ACCEPTED', 'ACTIVE') AND postponed_at IS NULL LIMIT 1`,
        [userId]
      );
      if (openOrder.rows.length > 0) throw new HttpError(409, 'عندك طلب مفتوح بالفعل، كمله من صفحة الطلبات');

      const range = await priceRangeFor(client, problemType);
      const res = await client.query(
        `INSERT INTO service_requests (
           client_id, service_title, problem_type, problem_description, client_latitude, client_longitude, client_address,
           min_price, max_price, commission_percent, tax_percent, round_deadline
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW() + make_interval(secs => $12)) RETURNING *`,
        [
          userId, sanitizeText(body.serviceTitle || 'محاميك حالاً', 255), problemType, description,
          lat, lon, body.clientAddress ? sanitizeText(body.clientAddress, 500) : null,
          range.minPrice, range.maxPrice, range.commissionPercent, range.taxPercent, ROUND_SECONDS,
        ]
      );
      const sent = await sendRound(client, res.rows[0], 1);
      if (sent === 0) throw new HttpError(409, 'مفيش محامي متاح دلوقتي، جرب تاني كمان شوية');
      return res.rows[0];
    });

    return reply.status(201).send({ success: true, message: 'طلبك اتبعت لأقرب المحامين', data: { id: created.id } });
  });

  // The requests waiting for this lawyer's price
  fastify.get('/incoming', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    if (role !== 'lawyer') throw new HttpError(403, 'الصفحة دي للمحامين');

    const res = await query(
      `SELECT r.*, rr.distance_km, rr.round AS my_round, ro.price AS my_price, ro.withdrawn_at AS my_withdrawn_at
       FROM request_recipients rr
       JOIN service_requests r ON r.id = rr.request_id
       LEFT JOIN request_offers ro ON ro.request_id = r.id AND ro.lawyer_id = rr.lawyer_id
       WHERE rr.lawyer_id = $1 AND r.status = 'OPEN'
         AND ((rr.round = r.round AND r.round_deadline > NOW()) OR (ro.id IS NOT NULL AND ro.withdrawn_at IS NULL))
       ORDER BY r.created_at DESC`,
      [userId]
    );

    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        id: row.id,
        problemType: row.problem_type || row.service_title,
        problemDescription: row.problem_description,
        area: governorateOf(row.client_address),
        distanceKm: roundedKm(row.distance_km),
        minPrice: Number(row.min_price),
        maxPrice: Number(row.max_price),
        // What the lawyer keeps from every pound, so the phone shows the net while typing
        netRate: lawyerShare(1000, Number(row.commission_percent), Number(row.tax_percent)) / 1000,
        secondsLeft: row.my_round === row.round ? secondsUntil(row.round_deadline) : 0,
        myPrice: row.my_price != null && !row.my_withdrawn_at ? Number(row.my_price) : null,
      })),
    });
  });

  // The lawyer's one price for this request
  fastify.post('/:id/offer', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);
    if (role !== 'lawyer') throw new HttpError(403, 'العروض للمحامين فقط');
    const price = Number((request.body as { price?: unknown } | null)?.price);

    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT * FROM service_requests WHERE id = $1 FOR UPDATE`, [id]);
      const target = locked.rows[0];
      const recipient = await client.query('SELECT round FROM request_recipients WHERE request_id = $1 AND lawyer_id = $2', [id, userId]);
      if (!target || recipient.rows.length === 0) throw new HttpError(404, 'الطلب غير موجود');
      if (target.status !== 'OPEN' || recipient.rows[0].round !== target.round || new Date(target.round_deadline).getTime() <= Date.now()) {
        throw new HttpError(409, 'وقت إرسال العروض على الطلب ده خلص');
      }

      const min = Number(target.min_price);
      const max = Number(target.max_price);
      if (!Number.isInteger(price) || price < min || price > max) throw new HttpError(400, `السعر لازم يكون من ${min} لـ ${max} ج.م`);

      const eligible = await client.query(
        `SELECT 1 FROM users u JOIN lawyer_profiles lp ON lp.user_id = u.id WHERE u.id = $1 AND ${LAWYER_CAN_WORK('lp', 'u')}`,
        [userId]
      );
      if (eligible.rows.length === 0) throw new HttpError(409, 'لازم تكون متاح ومعندكش مهمة مفتوحة');

      const saved = await client.query(
        `INSERT INTO request_offers (request_id, lawyer_id, price, lawyer_amount) VALUES ($1, $2, $3, $4)
         ON CONFLICT (request_id, lawyer_id) DO UPDATE
           SET price = EXCLUDED.price, lawyer_amount = EXCLUDED.lawyer_amount, withdrawn_at = NULL, created_at = NOW()
           WHERE request_offers.withdrawn_at IS NOT NULL
         RETURNING id`,
        [id, userId, price, lawyerShare(price, Number(target.commission_percent), Number(target.tax_percent))]
      );
      if (saved.rows.length === 0) throw new HttpError(409, 'بعت عرضك على الطلب ده قبل كده');
      await notify(client, target.client_id, 'وصلك عرض', `عرض جديد بـ ${price} ج.م`);
    });

    return reply.status(201).send({ success: true, message: 'عرضك اتبعت للموكل' });
  });

  // The lawyer can take the price back until the client chooses
  fastify.post('/:id/offer/withdraw', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);

    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT status FROM service_requests WHERE id = $1 FOR UPDATE`, [id]);
      if (locked.rows[0]?.status !== 'OPEN') throw new HttpError(409, 'الطلب اتقفل');
      const res = await client.query(
        'UPDATE request_offers SET withdrawn_at = NOW() WHERE request_id = $1 AND lawyer_id = $2 AND withdrawn_at IS NULL',
        [id, userId]
      );
      if (res.rowCount === 0) throw new HttpError(404, 'مفيش عرض لسحبه');
    });

    return reply.send({ success: true, message: 'تم سحب عرضك' });
  });

  // The client follows the request and reads its offers
  fastify.get('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);

    const res = await query('SELECT * FROM service_requests WHERE id = $1 AND client_id = $2', [id, userId]);
    const target = res.rows[0];
    if (!target) throw new HttpError(404, 'الطلب غير موجود');

    const offers = await query(
      `SELECT ro.id, ro.lawyer_id, ro.price, rr.distance_km, lp.full_name, lp.profile_photo_path, lp.rating, lp.reviews_count, lp.experience_years
       ${LIVE_OFFERS.replace('WHERE', 'JOIN request_recipients rr ON rr.request_id = ro.request_id AND rr.lawyer_id = ro.lawyer_id WHERE')}
         AND ro.request_id = $1
       ORDER BY ro.created_at ASC`,
      [id]
    );

    return reply.send({
      success: true,
      data: {
        id: target.id,
        status: target.status,
        round: target.round,
        secondsLeft: secondsUntil(target.round_deadline),
        minPrice: Number(target.min_price),
        maxPrice: Number(target.max_price),
        orderId: target.order_id,
        offers: target.status !== 'OPEN' ? [] : offers.rows.map((row) => ({
          id: row.id,
          lawyerId: row.lawyer_id,
          name: row.full_name,
          avatar: row.profile_photo_path || null,
          rating: Number(row.rating) || 0,
          reviewsCount: Number(row.reviews_count) || 0,
          experienceYears: Number(row.experience_years) || 0,
          price: Number(row.price),
          distanceKm: roundedKm(row.distance_km),
          minutesAway: Math.ceil((Number(row.distance_km) * ROAD_FACTOR / CITY_SPEED_KMH) * 60),
        })),
      },
    });
  });

  fastify.post('/:id/cancel', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);

    await query(`UPDATE service_requests SET status = 'CANCELLED' WHERE id = $1 AND client_id = $2 AND status = 'OPEN'`, [id, userId]);
    return reply.send({ success: true, message: 'تم إلغاء الطلب' });
  });

  // Choosing an offer turns the request into an order waiting for payment
  fastify.post('/:id/offers/:offerId/select', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id, offerId } = request.params as { id: string; offerId: string };
    requireId(id);
    requireId(offerId);

    const offerRes = await query('SELECT lawyer_id FROM request_offers WHERE id = $1 AND request_id = $2', [offerId, id]);
    if (offerRes.rows.length === 0) throw new HttpError(404, 'العرض غير موجود');
    const lawyerId = offerRes.rows[0].lawyer_id;

    const order = await withTransaction(async (client) => {
      // Same account locks as every new order, so one lawyer can't be booked twice
      await client.query('SELECT id FROM users WHERE id = ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE', [[userId, lawyerId]]);
      const locked = await client.query('SELECT * FROM service_requests WHERE id = $1 AND client_id = $2 FOR UPDATE', [id, userId]);
      const target = locked.rows[0];
      if (!target) throw new HttpError(404, 'الطلب غير موجود');
      if (target.status !== 'OPEN') throw new HttpError(409, 'الطلب اتقفل');

      const live = await client.query(
        `SELECT ro.price, ro.lawyer_amount, lp.latitude, lp.longitude ${LIVE_OFFERS} AND ro.id = $1`,
        [offerId]
      );
      const offer = live.rows[0];
      if (!offer || await lawyerHasOpenOrder(client, lawyerId)) throw new HttpError(409, 'المحامي ده مش متاح دلوقتي، اختار عرض تاني');

      const created = await client.query(
        `INSERT INTO service_orders (
           client_id, lawyer_id, service_type, service_title, problem_type, problem_description,
           client_latitude, client_longitude, client_address, lawyer_latitude, lawyer_longitude,
           price, commission_percent, tax_percent, lawyer_amount,
           response_deadline, status, accepted_at, payment_deadline
         ) VALUES ($1, $2, 'lawyer_now', $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14,
           NOW() + make_interval(secs => $15), 'ACCEPTED', NOW(), NOW() + make_interval(mins => $16))
         RETURNING *`,
        [
          userId, lawyerId, target.service_title, target.problem_type, target.problem_description,
          target.client_latitude, target.client_longitude, target.client_address, offer.latitude, offer.longitude,
          offer.price, target.commission_percent, target.tax_percent, offer.lawyer_amount,
          LAWYER_RESPONSE_SECONDS, PAYMENT_MINUTES,
        ]
      );
      const newOrder = created.rows[0];

      await client.query(`UPDATE service_requests SET status = 'SELECTED', order_id = $1 WHERE id = $2`, [newOrder.id, id]);
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, NULL, 'ACCEPTED', $3)`,
        [newOrder.id, userId, `اختار الموكل عرض المحامي بسعر ${Number(offer.price)} ج.م`]
      );

      await notify(client, lawyerId, 'الموكل اختار عرضك', 'مستنيين الموكل يدفع خلال 10 دقايق', newOrder.id);
      const others = await client.query(
        'SELECT lawyer_id FROM request_offers WHERE request_id = $1 AND lawyer_id <> $2 AND withdrawn_at IS NULL',
        [id, lawyerId]
      );
      for (const other of others.rows) {
        await notify(client, other.lawyer_id, 'الطلب اتقفل', 'الموكل اختار عرض تاني');
      }
      return newOrder;
    });

    return reply.send({
      success: true,
      message: 'تم اختيار العرض',
      data: { orderId: order.id, orderNumber: order.order_number, price: Number(order.price), lawyerId },
    });
  });
}
