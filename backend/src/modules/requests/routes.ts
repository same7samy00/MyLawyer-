import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { publishChange } from '../../services/liveUpdates.js';
import { AuthenticatedUser, HttpError, requireAuth, UUID_PATTERN } from '../../utils/http.js';
import { lawyerHasOpenOrder, lawyerShare, LAWYER_RESPONSE_SECONDS, notify, PAYMENT_MINUTES } from '../lifecycle/service.js';
import { availableNear, callsEnd, chooseEnd, createServiceRequest, inServiceArea, LAWYER_CAN_WORK, LIVE_OFFERS, chooseRound, deliverCall, priceRangeFor, ROUND_SECONDS } from './service.js';
import { readOnAction } from '../notifications/readOnAction.js';
import { roadRoute } from '../../services/roadRoutes.js';
import { governorateOf } from '../orders/shared.js';

const ROAD_FACTOR = 1.4;
const CITY_SPEED_KMH = 30;

const secondsUntil = (date: string | Date) => Math.max(0, Math.ceil((new Date(date).getTime() - Date.now()) / 1000));
const roundedKm = (value: unknown) => Number(Number(value).toFixed(1));

function requireId(id: string) {
  if (!UUID_PATTERN.test(id)) throw new HttpError(404, 'الطلب غير موجود');
}

export async function requestRoutes(fastify: FastifyInstance) {
  fastify.addHook('onRequest', requireAuth());
  readOnAction(fastify, 'request_id');

  // The price limits shown to the client before sending
  fastify.get('/range', async (request: FastifyRequest, reply: FastifyReply) => {
    const { problemType } = request.query as { problemType?: string };
    const range = await priceRangeFor(dbPool, problemType ? sanitizeText(problemType, 100) : null);
    return reply.send({ success: true, data: { minPrice: range.minPrice, maxPrice: range.maxPrice } });
  });

  // GET /requests/nearby?lat=&lon= - the lawyers a request from here would reach right now, for the list before
  // sending. Live, never kept by Nginx or the phone; the showcase map is the copy that waits hours
  fastify.get('/nearby', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { lat, lon } = request.query as { lat?: string; lon?: string };
    const latitude = Number(lat);
    const longitude = Number(lon);
    if (!lat || !lon || !inServiceArea(latitude, longitude)) throw new HttpError(400, 'تعذر تحديد موقعك، حاول تاني');
    reply.header('Cache-Control', 'no-store');
    return reply.send({ success: true, data: await availableNear(latitude, longitude, userId) });
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
    if (!body.clientLat || !body.clientLon || !inServiceArea(lat, lon)) throw new HttpError(400, 'تعذر تحديد موقعك، حاول تاني');

    const created = await createServiceRequest(userId, {
      serviceTitle: body.serviceTitle || 'طلب محامي',
      problemType: body.problemType ? sanitizeText(body.problemType, 100) : null,
      description,
      lat,
      lon,
      address: body.clientAddress ?? null,
    });

    return reply.status(201).send({ success: true, message: 'طلبك اتبعت لأقرب المحامين', data: { id: created.id } });
  });

  // The client's requests that have no chosen lawyer yet, for the orders page: the open one, and the ones that
  // closed without a choice in the last 30 days. A request with a chosen lawyer shows as its order instead
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    if (role !== 'client') return reply.send({ success: true, data: [] });
    const res = await query(
      `SELECT r.*, (SELECT COUNT(*)::int ${LIVE_OFFERS} AND ro.request_id = r.id) AS offers
       FROM service_requests r
       WHERE r.client_id = $1 AND r.order_id IS NULL
         AND (r.status = 'OPEN' OR (r.status IN ('NO_OFFERS', 'EXPIRED', 'CANCELLED') AND r.created_at > NOW() - INTERVAL '30 days'))
       ORDER BY r.created_at DESC LIMIT 50`,
      [userId]
    );
    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        id: row.id,
        status: row.status,
        problemType: row.problem_type || row.service_title,
        serviceTitle: row.service_title,
        problemDescription: row.problem_description,
        minPrice: Number(row.min_price),
        maxPrice: Number(row.max_price),
        offers: row.status === 'OPEN' ? row.offers : 0,
        secondsLeft: row.status === 'OPEN' ? secondsUntil(callsEnd(row)) : 0,
        chooseSecondsLeft: row.status === 'OPEN' ? secondsUntil(chooseEnd(row)) : 0,
        createdAt: row.created_at,
      })),
    });
  });

  // The requests waiting for this lawyer's price
  fastify.get('/incoming', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    if (role !== 'lawyer') throw new HttpError(403, 'الصفحة دي للمحامين');

    const res = await query(
      `SELECT r.*, rr.distance_km, ro.price AS my_price, ro.withdrawn_at AS my_withdrawn_at,
         EXISTS (SELECT 1 ${LIVE_OFFERS} AND ro.request_id = r.id) AS has_offers,
         f.request_id AS field_id, f.for_other AS f_for_other, f.person_detained AS f_detained, f.place_kind AS f_place_kind
       FROM request_recipients rr
       JOIN service_requests r ON r.id = rr.request_id
       LEFT JOIN field_requests f ON f.request_id = r.id
       LEFT JOIN request_offers ro ON ro.request_id = r.id AND ro.lawyer_id = rr.lawyer_id
       WHERE rr.lawyer_id = $1
         -- Every lawyer the request reached can send a price while it is open
         AND (r.status = 'OPEN'
              -- A chosen offer stays here until the client pays, then it lives in the orders history
              OR EXISTS (SELECT 1 FROM service_orders o WHERE o.id = r.order_id AND o.lawyer_id = rr.lawyer_id AND o.status = 'ACCEPTED'))
       ORDER BY r.created_at DESC`,
      [userId]
    );

    return reply.send({
      success: true,
      data: res.rows.map((row) => ({
        id: row.id,
        problemType: row.problem_type || row.service_title,
        problemDescription: row.problem_description,
        service: row.field_id ? row.service_title : 'طلب محامي',
        // The lawyer needs the area to price the visit. The exact point stays hidden until payment.
        // A field request names a place, so only its governorate shows until the client pays
        area: row.field_id ? governorateOf(row.client_address) : row.client_address,
        field: row.field_id ? { forOther: row.f_for_other, detained: row.f_detained, placeKind: row.f_place_kind } : null,
        distanceKm: roundedKm(row.distance_km),
        minPrice: Number(row.min_price),
        maxPrice: Number(row.max_price),
        // What the lawyer keeps from every pound, so the phone shows the net while typing
        netRate: lawyerShare(1000, Number(row.commission_percent), Number(row.tax_percent)) / 1000,
        // Prices are taken until the calls end, and while offers wait, until the client must choose
        secondsLeft: row.status === 'OPEN' ? secondsUntil(row.has_offers ? chooseEnd(row) : callsEnd(row)) : 0,
        myPrice: row.my_price != null && !row.my_withdrawn_at ? Number(row.my_price) : null,
        state: row.status === 'OPEN' ? 'OPEN' : 'CHOSEN',
        orderId: row.order_id,
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

    // The client sees how long this lawyer needs by road. With few lawyers around it was not asked at the call,
    // so it is asked once here, before anything is locked
    const way = (await query(
      `SELECT rr.road_seconds, r.client_latitude, r.client_longitude, lp.latitude, lp.longitude
       FROM request_recipients rr JOIN service_requests r ON r.id = rr.request_id JOIN lawyer_profiles lp ON lp.user_id = rr.lawyer_id
       WHERE rr.request_id = $1 AND rr.lawyer_id = $2 AND r.status = 'OPEN'`,
      [id, userId]
    )).rows[0];
    if (way && way.road_seconds == null && way.latitude != null) {
      const road = await roadRoute(
        { lat: Number(way.latitude), lon: Number(way.longitude) },
        { lat: Number(way.client_latitude), lon: Number(way.client_longitude) }
      );
      if (road) {
        await query('UPDATE request_recipients SET road_seconds = $3 WHERE request_id = $1 AND lawyer_id = $2', [id, userId, Math.round(road.durationSeconds)]);
      }
    }

    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT * FROM service_requests WHERE id = $1 FOR UPDATE`, [id]);
      const target = locked.rows[0];
      const recipient = await client.query('SELECT 1 FROM request_recipients WHERE request_id = $1 AND lawyer_id = $2', [id, userId]);
      if (!target || recipient.rows.length === 0) throw new HttpError(404, 'الطلب غير موجود');
      if (target.status !== 'OPEN') {
        throw new HttpError(409, 'وقت إرسال العروض على الطلب ده خلص');
      }

      const min = Number(target.min_price);
      const max = Number(target.max_price);
      if (!Number.isInteger(price) || price < min || price > max) throw new HttpError(400, `السعر لازم يكون من ${min} لـ ${max} ج.م`);

      const eligible = await client.query(
        `SELECT 1 FROM users u JOIN lawyer_profiles lp ON lp.user_id = u.id WHERE u.id = $1 AND ${LAWYER_CAN_WORK('lp', 'u')}`,
        [userId]
      );
      if (eligible.rows.length === 0) throw new HttpError(409, 'لازم تكون متاح، ومعندكش مهمة شغالة دلوقتي');

      const saved = await client.query(
        `INSERT INTO request_offers (request_id, lawyer_id, price, lawyer_amount) VALUES ($1, $2, $3, $4)
         ON CONFLICT (request_id, lawyer_id) DO UPDATE
           SET price = EXCLUDED.price, lawyer_amount = EXCLUDED.lawyer_amount, withdrawn_at = NULL, created_at = NOW()
           WHERE request_offers.withdrawn_at IS NOT NULL
         RETURNING id`,
        [id, userId, price, lawyerShare(price, Number(target.commission_percent), Number(target.tax_percent))]
      );
      if (saved.rows.length === 0) throw new HttpError(409, 'بعت عرضك على الطلب ده قبل كده');
      const live = await client.query(`SELECT COUNT(*)::int AS total ${LIVE_OFFERS} AND ro.request_id = $1`, [id]);
      const count = live.rows[0].total;
      await notify(client, target.client_id, count > 1 ? `وصلك ${count} عروض` : 'وصلك عرض', 'اختار العرض المناسب ليك', { requestId: id });
    });

    return reply.status(201).send({ success: true, message: 'عرضك اتبعت للموكل' });
  });

  // The lawyer can take the price back until the client chooses
  fastify.post('/:id/offer/withdraw', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);

    await withTransaction(async (client) => {
      const locked = await client.query(`SELECT status, client_id FROM service_requests WHERE id = $1 FOR UPDATE`, [id]);
      if (locked.rows[0]?.status !== 'OPEN') throw new HttpError(409, 'الطلب اتقفل');
      const res = await client.query(
        'UPDATE request_offers SET withdrawn_at = NOW() WHERE request_id = $1 AND lawyer_id = $2 AND withdrawn_at IS NULL',
        [id, userId]
      );
      if (res.rowCount === 0) throw new HttpError(404, 'مفيش عرض لسحبه');
      await publishChange(client, locked.rows[0].client_id, false, 'requests', id);
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
      `SELECT ro.id, ro.lawyer_id, ro.price, rr.distance_km, rr.road_seconds, lp.full_name, lp.profile_photo_path, lp.rating, lp.reviews_count, lp.experience_years
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
        // The app keeps searching until all the calls end, then shows the offers or «بحث جديد»
        secondsLeft: secondsUntil(callsEnd(target)),
        chooseSecondsLeft: secondsUntil(chooseEnd(target)),
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
          // The road time with traffic when it is known, and a city-driving guess on the straight distance when not
          minutesAway: row.road_seconds != null
            ? Math.max(1, Math.ceil(Number(row.road_seconds) / 60))
            : Math.ceil((Number(row.distance_km) * ROAD_FACTOR / CITY_SPEED_KMH) * 60),
        })),
      },
    });
  });

  fastify.post('/:id/cancel', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);

    await withTransaction(async (client) => {
      const cancelled = await client.query(`UPDATE service_requests SET status = 'CANCELLED' WHERE id = $1 AND client_id = $2 AND status = 'OPEN'`, [id, userId]);
      if (cancelled.rowCount === 0) return;
      const recipients = await client.query('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id]);
      for (const row of recipients.rows) await publishChange(client, row.lawyer_id, false, 'requests', id);
    });
    return reply.send({ success: true, message: 'تم إلغاء الطلب' });
  });

  // «بحث جديد»: the next call right away, to the nearest 10 not asked yet (up to 50 km after the third call).
  // With nobody new left, the nearest 10 who did not send a price are asked again. The offers already sent stay.
  fastify.post('/:id/search', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    requireId(id);

    const seen = (await query('SELECT * FROM service_requests WHERE id = $1 AND client_id = $2', [id, userId])).rows[0];
    if (!seen) throw new HttpError(404, 'الطلب غير موجود');
    if (seen.status !== 'OPEN') throw new HttpError(409, 'الطلب اتقفل، ابعت طلب جديد');
    // With fewer than 10 lawyers around, the next group is empty, so the search goes straight back to the nearest.
    // Worked out before the lock, like every call
    const call = await chooseRound(seen, seen.round + 1, true);

    const round = await withTransaction(async (client) => {
      const locked = await client.query(`SELECT * FROM service_requests WHERE id = $1 AND client_id = $2 FOR UPDATE`, [id, userId]);
      const target = locked.rows[0];
      if (!target) throw new HttpError(404, 'الطلب غير موجود');
      if (target.status !== 'OPEN') throw new HttpError(409, 'الطلب اتقفل، ابعت طلب جديد');

      // An automatic call may have gone out meanwhile, so this one takes the number after the newest
      const next = target.round + 1;
      const sent = await deliverCall(client, target, { ...call, round: next });
      if (sent === 0) throw new HttpError(409, 'مفيش محامين تانيين متاحين قريب منك دلوقتي');
      await client.query(
        `UPDATE service_requests SET round = $1, round_deadline = NOW() + make_interval(secs => $2) WHERE id = $3`,
        [next, ROUND_SECONDS, id]
      );
      return next;
    });

    return reply.send({ success: true, message: 'بعتنا طلبك لمحامين تانيين', data: { round } });
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
      for (const other of others.rows) await publishChange(client, other.lawyer_id, false, 'requests', id);
      return newOrder;
    });

    return reply.send({
      success: true,
      message: 'تم اختيار العرض',
      data: { orderId: order.id, orderNumber: order.order_number, price: Number(order.price), lawyerId },
    });
  });
}
