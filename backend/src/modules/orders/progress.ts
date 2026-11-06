import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { CANCEL_MINUTES } from '../lifecycle/settlement.js';
import { OPEN_ORDER_TICKET } from '../support/service.js';
import { sanitizeText } from '../../utils/security.js';
import { HttpError, UUID_PATTERN } from '../../utils/http.js';
import { addClientCredit, addLawyerStrike, ARRIVAL_RADIUS_KM, HOLD_HOURS, LIVE_POSITION_FRESH_SECONDS, LIVE_POSITION_SECONDS, notify } from '../lifecycle/service.js';
import { publishPosition } from '../../services/liveUpdates.js';
import { distanceKm, lockOrder, AuthenticatedUser } from './shared.js';

/// Arrival, completion, cancellation and withdrawal
export async function registerOrderProgress(fastify: FastifyInstance) {
  // 13. POST /api/v1/orders/:id/arrive - Lawyer confirms arrival near the client
  fastify.post('/:id/arrive', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { latitude?: number; longitude?: number };

    const lat = Number(body.latitude);
    const lon = Number(body.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return reply.status(400).send({ success: false, error: 'تعذر تحديد موقعك' });
    }

    await withTransaction(async (client) => {
      const order = await lockOrder(client, id);
      if (!order || order.lawyer_id !== userId) throw new HttpError(404, 'الطلب غير موجود أو غير مسند إليك');
      if (order.status !== 'ACTIVE' || order.arrived_at) throw new HttpError(400, 'لا يمكن تسجيل الوصول لهذا الطلب');

      // The arrival is the proof that the two really met: near where the client asked from,
      // or near where the client is now, when the client's phone shared it in the last two minutes
      const distance = distanceKm(lat, lon, Number(order.client_latitude), Number(order.client_longitude));
      const liveIsFresh = order.client_live_at && Date.now() - new Date(order.client_live_at).getTime() <= LIVE_POSITION_FRESH_SECONDS * 1000;
      const liveDistance = liveIsFresh
        ? distanceKm(lat, lon, Number(order.client_live_latitude), Number(order.client_live_longitude))
        : Infinity;
      if (Math.min(distance, liveDistance) > ARRIVAL_RADIUS_KM) throw new HttpError(400, 'لازم تكون قريب من الموكل');

      await client.query(
        `UPDATE service_orders SET arrived_at = NOW(), arrived_latitude = $1, arrived_longitude = $2 WHERE id = $3`,
        [lat, lon, order.id]
      );
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'ACTIVE', 'ACTIVE', 'وصل المحامي إلى موقع الموكل')`,
        [order.id, userId]
      );
      await notify(client, order.client_id, 'المحامي وصل', 'المحامي عند موقعك دلوقتي', order.id);
    });

    return reply.send({ success: true, message: 'تم تسجيل وصولك' });
  });

  // Each side's newest point on the way to the meeting, from payment until the lawyer arrives.
  // Only the latest point is kept, it reaches the other side live, and nothing is sent after the arrival.
  fastify.post('/:id/position', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { latitude?: unknown; longitude?: unknown };
    const lat = Number(body.latitude);
    const lon = Number(body.longitude);
    if (!UUID_PATTERN.test(id)) throw new HttpError(404, 'الطلب غير موجود');
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < 21 || lat > 32.5 || lon < 24 || lon > 37.5) {
      throw new HttpError(400, 'إحداثيات الموقع غير صالحة');
    }

    const res = await query(
      `SELECT lawyer_id, client_id, status, arrived_at, lawyer_live_at, client_live_at FROM service_orders WHERE id = $1`,
      [id]
    );
    const order = res.rows[0];
    if (!order || (order.lawyer_id !== userId && order.client_id !== userId)) throw new HttpError(404, 'الطلب غير موجود');

    // The app stops sending once this says the way to the meeting is over
    const tracking = order.status === 'ACTIVE' && !order.arrived_at;
    if (!tracking) return reply.send({ success: true, data: { tracking: false } });

    const side = order.lawyer_id === userId ? 'lawyer' : 'client';
    const last = side === 'lawyer' ? order.lawyer_live_at : order.client_live_at;
    if (last && Date.now() - new Date(last).getTime() < LIVE_POSITION_SECONDS * 1000) {
      return reply.send({ success: true, data: { tracking: true } });
    }

    await query(
      side === 'lawyer'
        ? 'UPDATE service_orders SET lawyer_live_latitude = $2, lawyer_live_longitude = $3, lawyer_live_at = NOW() WHERE id = $1'
        : 'UPDATE service_orders SET client_live_latitude = $2, client_live_longitude = $3, client_live_at = NOW() WHERE id = $1',
      [id, lat, lon]
    );
    await publishPosition(dbPool, side === 'lawyer' ? order.client_id : order.lawyer_id, id, side, lat, lon);
    return reply.send({ success: true, data: { tracking: true } });
  });

  // The client chose to keep waiting for a late lawyer, so the two-hour refund stops
  fastify.post('/:id/keep-waiting', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    await withTransaction(async (client) => {
      const order = await lockOrder(client, id);
      if (!order || order.client_id !== userId) throw new HttpError(404, 'الطلب غير موجود');
      if (order.status !== 'ACTIVE' || order.arrived_at || !order.delay_notified_at) {
        throw new HttpError(400, 'الطلب مش في مرحلة الانتظار');
      }
      await client.query(`UPDATE service_orders SET client_keeps_waiting = TRUE, updated_at = NOW() WHERE id = $1`, [order.id]);
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'ACTIVE', 'ACTIVE', 'اختار الموكل انتظار المحامي بعد انتهاء مهلة الوصول')`,
        [order.id, userId]
      );
      await notify(client, order.lawyer_id, 'الموكل مستنيك', 'لما توصل دوس «وصلت»', order.id);
    });

    return reply.send({ success: true, message: 'تمام، هنكمل انتظار المحامي' });
  });

  // The lawyer arrived but the task needs more time. The money stays held until «إنهاء».
  fastify.post('/:id/postpone', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string; until?: string };

    const reason = sanitizeText(body.reason || '', 500).trim();
    const until = new Date(body.until || '');
    if (!reason) throw new HttpError(400, 'اكتب سبب التأجيل');
    if (Number.isNaN(until.getTime()) || until.getTime() <= Date.now()) throw new HttpError(400, 'اختار ميعاد جديد صحيح');

    await withTransaction(async (client) => {
      const order = await lockOrder(client, id);
      if (!order || order.lawyer_id !== userId) throw new HttpError(404, 'الطلب غير موجود أو غير مسند إليك');
      if (order.status !== 'ACTIVE' || !order.arrived_at) throw new HttpError(400, 'التأجيل بيبقى بعد «وصلت» بس');

      const openComplaint = await client.query(`SELECT ${OPEN_ORDER_TICKET('$1')} AS open`, [order.id]);
      if (openComplaint.rows[0].open) throw new HttpError(409, 'الطلب قيد مراجعة تذكرة من الإدارة');

      await client.query(
        `UPDATE service_orders SET postponed_at = NOW(), postponed_until = $1, postponed_reason = $2, updated_at = NOW() WHERE id = $3`,
        [until, reason, order.id]
      );
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'ACTIVE', 'ACTIVE', $3)`,
        [order.id, userId, `أجّل المحامي المهمة: ${reason}`]
      );
      await notify(client, order.client_id, 'المحامي أجّل المهمة', `${reason}. وفلوسك لسه محجوزة`, order.id);
    });

    return reply.send({ success: true, message: 'تم تأجيل المهمة' });
  });

  // 7. POST /api/v1/orders/:id/complete - Lawyer completes active order
  fastify.post('/:id/complete', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    if (role !== 'lawyer' && role !== 'admin') {
      return reply.status(403).send({ success: false, error: 'إنهاء الطلبات مخصص للمحامي المعني فقط' });
    }

    const { order, completed } = await withTransaction(async (client) => {
      const order = await lockOrder(client, id);
      if (!order || order.lawyer_id !== userId) throw new HttpError(404, 'الطلب غير موجود أو غير مسند إليك');
      if (order.status !== 'ACTIVE') throw new HttpError(400, 'لا يمكن إنهاء المهمة قبل سداد الموكل');
      if (!order.arrived_at) throw new HttpError(409, 'سجل وصولك الأول عند الموكل');

      // A ticket on the order waits for the admin decision before the task can close
      const openComplaint = await client.query(`SELECT ${OPEN_ORDER_TICKET('$1')} AS open`, [order.id]);
      if (openComplaint.rows[0].open) throw new HttpError(409, 'الطلب قيد مراجعة تذكرة من الإدارة');

      const res = await client.query(
        `UPDATE service_orders
         SET status = 'COMPLETED', completed_at = NOW(), payout_status = 'HELD', payout_amount = lawyer_amount,
             hold_until = NOW() + make_interval(hours => $2), updated_at = NOW()
         WHERE id = $1 RETURNING hold_until`,
        [order.id, HOLD_HOURS]
      );

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, $3, 'COMPLETED', 'أنهى المحامي المهمة بعد الالتقاء بالموكل')`,
        [order.id, userId, order.status]
      );

      await notify(client, order.client_id, 'انتهت المهمة', 'قيّم المحامي. ولو فيه مشكلة افتح «عندك مشكلة؟»', order.id);

      return { order, completed: res.rows[0] };
    });

    return reply.send({
      success: true,
      message: 'تم إنهاء المهمة بنجاح',
      data: { orderId: order.id, status: 'COMPLETED', holdUntil: completed.hold_until },
    });
  });

  // 8. POST /api/v1/orders/:id/cancel - Client or Lawyer cancels order
  fastify.post('/:id/cancel', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    const cleanReason = body.reason ? sanitizeText(body.reason, 500) : 'تم الإلغاء بناءً على طلب المستخدم';

    const order = await withTransaction(async (client) => {
      const order = await lockOrder(client, id);
      if (!order) throw new HttpError(404, 'الطلب غير موجود');

      // Authorization
      if (role !== 'admin' && order.client_id !== userId && order.lawyer_id !== userId) {
        throw new HttpError(403, 'غير مصرح لك بإلغاء هذا الطلب');
      }

      if (order.status === 'CANCELLED') throw new HttpError(400, 'الطلب ملغى بالفعل مسبقاً');

      // After payment the client may cancel before the lawyer arrives, in the first minutes or once the lawyer is late
      const withinFirstMinutes = order.status === 'ACTIVE' && Date.now() - new Date(order.paid_at).getTime() <= CANCEL_MINUTES * 60000;
      const lawyerIsLate = order.status === 'ACTIVE' && order.arrival_deadline && new Date(order.arrival_deadline).getTime() <= Date.now();
      const refundOnCancel = order.client_id === userId && !order.arrived_at && Boolean(withinFirstMinutes || lawyerIsLate);
      if (refundOnCancel && !withinFirstMinutes) {
        const openComplaint = await client.query(`SELECT ${OPEN_ORDER_TICKET('$1')} AS open`, [order.id]);
        if (openComplaint.rows[0].open) throw new HttpError(409, 'الطلب قيد مراجعة تذكرة من الإدارة');
      }
      if (order.status !== 'PENDING' && order.status !== 'ACCEPTED' && !refundOnCancel) {
        throw new HttpError(400, 'لا يمكن إلغاء الطلب في حالته الحالية');
      }

      await client.query(
        `UPDATE service_orders
         SET status = 'CANCELLED', cancelled_at = NOW(), cancellation_reason = $1, completion_code = NULL,
             payout_status = CASE WHEN $3 THEN 'REFUNDED' ELSE payout_status END, updated_at = NOW()
         WHERE id = $2`,
        [cleanReason, order.id, refundOnCancel]
      );

      if (refundOnCancel) {
        await addClientCredit(client, order.client_id, order.id, Number(order.price), 'رد قيمة طلب ملغى قبل وصول المحامي');
      }

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, $3, 'CANCELLED', $4)`,
        [order.id, userId, order.status, `تم الإلغاء: ${cleanReason}`]
      );

      const otherParty = userId === order.client_id ? order.lawyer_id : order.client_id;
      await notify(client, otherParty, 'الطلب اتلغى', userId === order.client_id ? 'الموكل لغى الطلب' : 'المحامي لغى الطلب', order.id);
      return order;
    });

    return reply.send({
      success: true,
      message: 'تم إلغاء الطلب بنجاح',
      data: { orderId: order.id, status: 'CANCELLED' },
    });
  });

  // 14. POST /api/v1/orders/:id/withdraw - Lawyer steps down after payment
  fastify.post('/:id/withdraw', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    const reason = sanitizeText(body.reason || 'اعتذر المحامي بعد الدفع', 500);

    await withTransaction(async (client) => {
      const order = await lockOrder(client, id);
      if (!order || order.lawyer_id !== userId) throw new HttpError(404, 'الطلب غير موجود أو غير مسند إليك');
      if (order.status !== 'ACTIVE') throw new HttpError(400, 'لا يمكن الاعتذار عن هذا الطلب');

      await client.query(
        `UPDATE service_orders
         SET status = 'CANCELLED', cancelled_at = NOW(), cancellation_reason = $1,
             completion_code = NULL, payout_status = 'REFUNDED'
         WHERE id = $2`,
        [reason, order.id]
      );
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'ACTIVE', 'CANCELLED', $3)`,
        [order.id, userId, `اعتذار بعد الدفع: ${reason}`]
      );
      await addClientCredit(client, order.client_id, order.id, Number(order.price), 'رد قيمة بعد اعتذار المحامي');
      await addLawyerStrike(client, userId, order.id, 'WITHDRAWAL');
      await notify(client, order.client_id, 'المحامي اعتذر', 'رجعلك المبلغ في رصيدك', order.id);
    });

    return reply.send({ success: true, message: 'تم تسجيل الاعتذار ورد المبلغ للموكل' });
  });
}
