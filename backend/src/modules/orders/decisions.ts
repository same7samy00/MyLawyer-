import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { HttpError } from '../../utils/http.js';
import { addClientCredit, lawyerHasOpenOrder, notify, ORDER_DEADLINE_HOURS, PAYMENT_MINUTES } from '../lifecycle/service.js';
import { AuthenticatedUser, lockOrder } from './shared.js';

/// The lawyer answer and the client payment
export async function registerOrderDecisions(fastify: FastifyInstance) {
  // 4. POST /api/v1/orders/:id/accept - Lawyer accepts incoming order
  fastify.post('/:id/accept', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    if (role !== 'lawyer' && role !== 'admin') {
      return reply.status(403).send({ success: false, error: 'قبول الطلبات مخصص للمحامي المعني فقط' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );

    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'PENDING') {
      return reply.status(400).send({
        success: false,
        error: `لا يمكن قبول الطلب؛ حالته الحالية: ${order.status}`,
      });
    }

    if (new Date(order.response_deadline).getTime() <= Date.now()) {
      return reply.status(409).send({ success: false, error: 'انتهت مهلة الرد على الطلب' });
    }
    if (await lawyerHasOpenOrder(dbPool, userId, order.id)) {
      return reply.status(409).send({ success: false, error: 'عندك مهمة مفتوحة، خلصها الأول' });
    }

    // Lawyers move around, so the place stored on the map may be old by now
    const body = (request.body || {}) as { latitude?: unknown; longitude?: unknown };
    const lat = typeof body.latitude === 'number' && Number.isFinite(body.latitude) ? body.latitude : null;
    const lon = typeof body.longitude === 'number' && Number.isFinite(body.longitude) ? body.longitude : null;
    const hasFreshLocation = lat !== null && lon !== null;

    await withTransaction(async (client) => {
      const accepted = await client.query(
        `UPDATE service_orders
         SET status = 'ACCEPTED', accepted_at = NOW(), updated_at = NOW(),
             payment_deadline = NOW() + make_interval(mins => $2),
             lawyer_latitude = COALESCE($3, lawyer_latitude),
             lawyer_longitude = COALESCE($4, lawyer_longitude)
         WHERE id = $1 AND status = 'PENDING'`,
        [order.id, PAYMENT_MINUTES, lat, lon]
      );
      if (accepted.rowCount === 0) throw new HttpError(409, 'الطلب اتغيرت حالته، حدّث الصفحة');

      await client.query('UPDATE lawyer_profiles SET missed_orders = 0 WHERE user_id = $1', [userId]);

      if (hasFreshLocation) {
        await client.query(
          `UPDATE lawyer_profiles
           SET latitude = $1, longitude = $2, last_location_updated_at = NOW(), last_active_at = NOW()
           WHERE user_id = $3`,
          [lat, lon, userId]
        );
      }

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'PENDING', 'ACCEPTED', 'وافق المحامي على تولي الطلب')`,
        [order.id, userId]
      );

      await notify(client, order.client_id, 'المحامي وافق', 'ادفع خلال 10 دقايق عشان يبدأ', order.id);
    });

    return reply.send({
      success: true,
      message: 'تم قبول الطلب بنجاح',
      data: { orderId: order.id, status: 'ACCEPTED' },
    });
  });

  // 5. POST /api/v1/orders/:id/reject - Lawyer rejects incoming order
  fastify.post('/:id/reject', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    if (role !== 'lawyer' && role !== 'admin') {
      return reply.status(403).send({ success: false, error: 'الاعتذار عن الطلبات مخصص للمحامي المعني فقط' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );

    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'PENDING') {
      return reply.status(400).send({
        success: false,
        error: `لا يمكن رفض الطلب؛ حالته الحالية: ${order.status}`,
      });
    }

    const cleanReason = body.reason ? sanitizeText(body.reason, 500) : 'المحامي غير متاح حالياً للمهمة';

    await withTransaction(async (client) => {
      const rejected = await client.query(
        `UPDATE service_orders
         SET status = 'REJECTED', rejection_reason = $1, updated_at = NOW()
         WHERE id = $2 AND status = 'PENDING'`,
        [cleanReason, order.id]
      );
      if (rejected.rowCount === 0) throw new HttpError(409, 'الطلب اتغيرت حالته، حدّث الصفحة');

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'PENDING', 'REJECTED', $3)`,
        [order.id, userId, `اعتذر المحامي: ${cleanReason}`]
      );

      await notify(client, order.client_id, 'المحامي اعتذر', 'اختار محامي تاني', order.id);
    });

    return reply.send({
      success: true,
      message: 'تم تسجيل الاعتذار عن الطلب',
      data: { orderId: order.id, status: 'REJECTED' },
    });
  });

  // 6. POST /api/v1/orders/:id/confirm-payment - Client confirms payment and activates order
  fastify.post('/:id/confirm-payment', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    const body = (request.body || {}) as { method?: string };

    const order = await withTransaction(async (client) => {
      // The balance is shared with wallet transfers, which take the same account lock
      await client.query('SELECT id FROM users WHERE id = $1 FOR NO KEY UPDATE', [userId]);
      const locked = await lockOrder(client, id);

      if (!locked || locked.client_id !== userId) throw new HttpError(404, 'الطلب غير موجود');
      if (locked.status !== 'ACCEPTED') throw new HttpError(400, 'لا يمكن الدفع قبل موافقة المحامي على الطلب');
      if (new Date(locked.payment_deadline).getTime() <= Date.now()) throw new HttpError(409, 'انتهت مهلة الدفع لهذا الطلب');

      if (body.method === 'wallet') {
        const balanceRes = await client.query(
          'SELECT COALESCE(SUM(amount), 0) AS balance FROM client_credits WHERE client_id = $1',
          [userId]
        );
        if (Number(balanceRes.rows[0].balance) < Number(locked.price)) throw new HttpError(400, 'رصيدك مش كفاية');
        await addClientCredit(client, userId, locked.id, -Number(locked.price), 'سداد طلب من الرصيد');
      }

      await client.query(
        `UPDATE service_orders
         SET status = 'ACTIVE', paid_at = NOW(), expires_at = NOW() + make_interval(hours => $2), updated_at = NOW()
         WHERE id = $1`,
        [locked.id, ORDER_DEADLINE_HOURS]
      );

      await client.query(
        'INSERT INTO payments (order_id, client_id, amount, method) VALUES ($1, $2, $3, $4) ON CONFLICT (order_id) DO NOTHING',
        [locked.id, userId, locked.price, body.method === 'wallet' ? 'WALLET' : 'DIRECT']
      );

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, $3, 'ACTIVE', 'تم سداد الرسوم وبدء سريان المهمة')`,
        [locked.id, userId, locked.status]
      );

      await notify(client, locked.lawyer_id, 'الموكل دفع', 'ابدأ المهمة، ودوس «وصلت» عند الموكل', locked.id);
      return locked;
    });

    return reply.send({
      success: true,
      message: 'تم تأكيد الدفع وتفعيل الطلب بنجاح',
      data: { orderId: order.id, status: 'ACTIVE' },
    });
  });
}
