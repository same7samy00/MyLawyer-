import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query, withTransaction } from '../../database/index.js';
import { HttpError } from '../../utils/http.js';
import { addClientCredit, arrivalMinutes, lawyerHasOpenOrder, notify, ORDER_DEADLINE_HOURS } from '../lifecycle/service.js';
import { releaseChoice } from '../requests/service.js';
import { AuthenticatedUser, lockOrder } from './shared.js';

/// The client payment: whoever pays first gets the lawyer
export async function registerOrderDecisions(fastify: FastifyInstance) {
  // 6. POST /api/v1/orders/:id/confirm-payment - Client confirms payment and activates order
  fastify.post('/:id/confirm-payment', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    const body = (request.body || {}) as { method?: string };

    // The road time is asked before the transaction, so no lock waits for the network
    const places = await query(
      `SELECT lawyer_latitude, lawyer_longitude, client_latitude, client_longitude FROM service_orders
       WHERE (id::text = $1 OR order_number = $1) AND client_id = $2`,
      [id, userId]
    );
    const place = places.rows[0];
    const minutesToArrive = place
      ? await arrivalMinutes(
          place.lawyer_latitude != null && place.lawyer_longitude != null
            ? { lat: Number(place.lawyer_latitude), lon: Number(place.lawyer_longitude) }
            : null,
          { lat: Number(place.client_latitude), lon: Number(place.client_longitude) }
        )
      : 0;

    const method = body.method === 'wallet' ? 'WALLET' : 'DIRECT';
    // A payment that did not go through is kept, so the client sees it in their payments page
    let failed: { orderId: string; amount: number; reason: string } | null = null;
    const failPayment = (locked: any, reason: string, status: number) => {
      failed = { orderId: locked.id, amount: Number(locked.price), reason };
      return new HttpError(status, reason);
    };

    let taken = false;
    const order = await withTransaction(async (client) => {
      // The balance is shared with wallet transfers, which take the same account lock. The lawyer's account is locked
      // too, so two clients paying for the same lawyer at once are served one after the other
      const owner = await client.query('SELECT lawyer_id FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND client_id = $2', [id, userId]);
      const people = [userId, owner.rows[0]?.lawyer_id].filter(Boolean).sort();
      await client.query('SELECT id FROM users WHERE id = ANY($1::uuid[]) ORDER BY id FOR NO KEY UPDATE', [people]);
      const locked = await lockOrder(client, id);

      if (!locked || locked.client_id !== userId) throw new HttpError(404, 'الطلب غير موجود');
      if (locked.status === 'PENDING') throw new HttpError(400, 'لا يمكن الدفع قبل موافقة المحامي على الطلب');
      if (locked.status !== 'ACCEPTED') throw new HttpError(409, 'المحامي ده اتشغل أو المهلة خلصت، اختار محامي تاني من العروض');
      // Someone else paid for this lawyer first: this choice goes, and the client picks again from the same offers
      if (await lawyerHasOpenOrder(client, locked.lawyer_id, locked.id)) {
        await releaseChoice(client, locked, true);
        taken = true;
        return locked;
      }
      if (new Date(locked.payment_deadline).getTime() <= Date.now()) throw failPayment(locked, 'انتهت مهلة الدفع لهذا الطلب', 409);

      if (body.method === 'wallet') {
        const balanceRes = await client.query(
          'SELECT COALESCE(SUM(amount), 0) AS balance FROM client_credits WHERE client_id = $1',
          [userId]
        );
        if (Number(balanceRes.rows[0].balance) < Number(locked.price)) throw failPayment(locked, 'رصيدك مش كفاية', 400);
        await addClientCredit(client, userId, locked.id, -Number(locked.price), 'سداد طلب من الرصيد');
      }

      await client.query(
        `UPDATE service_orders
         SET status = 'ACTIVE', paid_at = NOW(), expires_at = NOW() + make_interval(hours => $2),
             arrival_deadline = NOW() + make_interval(mins => $3), updated_at = NOW()
         WHERE id = $1`,
        [locked.id, ORDER_DEADLINE_HOURS, minutesToArrive]
      );

      await client.query(
        'INSERT INTO payments (order_id, client_id, amount, method) VALUES ($1, $2, $3, $4) ON CONFLICT (order_id) DO NOTHING',
        [locked.id, userId, locked.price, method]
      );

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, $3, 'ACTIVE', 'تم سداد الرسوم وبدء سريان المهمة')`,
        [locked.id, userId, locked.status]
      );

      await notify(client, locked.lawyer_id, 'الموكل دفع', 'ابدأ المهمة، ودوس «وصلت» عند الموكل', locked.id);
      // With their 3 places now taken, other clients who chose this lawyer and did not pay go back to their offers
      const full = await lawyerHasOpenOrder(client, locked.lawyer_id);
      const others = !full ? { rows: [] as any[] } : await client.query(
        `SELECT id, client_id, lawyer_id FROM service_orders WHERE lawyer_id = $1 AND status = 'ACCEPTED' AND id <> $2 FOR UPDATE`,
        [locked.lawyer_id, locked.id]
      );
      for (const other of others.rows) await releaseChoice(client, other, true);
      return locked;
    }).catch(async (error) => {
      const attempt = failed as { orderId: string; amount: number; reason: string } | null;
      if (attempt) {
        await query(
          'INSERT INTO failed_payments (order_id, client_id, amount, method, reason) VALUES ($1, $2, $3, $4, $5)',
          [attempt.orderId, userId, attempt.amount, method, attempt.reason]
        );
      }
      throw error;
    });

    // Nothing was charged: the client is back on the offers
    if (taken) throw new HttpError(409, 'المحامي ده اتشغل، اختار محامي تاني من العروض');

    return reply.send({
      success: true,
      message: 'تم تأكيد الدفع وتفعيل الطلب بنجاح',
      data: { orderId: order.id, status: 'ACTIVE' },
    });
  });
}
