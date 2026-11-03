import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import { LAWYER_RESPONSE_SECONDS, lawyerHasOpenOrder, notify, resolveClientQuote } from '../lifecycle/service.js';
import { responseSecondsLeft, AuthenticatedUser } from './shared.js';

/// Pricing a request and sending it to a lawyer
export async function registerOrderCreation(fastify: FastifyInstance) {
  // POST /api/v1/orders/quote - Price shown to the client before sending the request
  fastify.post('/quote', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const body = (request.body || {}) as { problemType?: string };

    const quote = await resolveClientQuote(dbPool, userId, body.problemType ? sanitizeText(body.problemType, 100) : null);
    return reply.send({ success: true, data: { price: quote.price } });
  });

  // 1. POST /api/v1/orders - Create a new service order
  fastify.post('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;

    const body = request.body as {
      lawyerId?: string;
      serviceType?: string;
      serviceTitle?: string;
      problemType?: string;
      problemDescription?: string;
      clientLat?: number;
      clientLon?: number;
      clientAddress?: string;
    };

    if (!body.lawyerId) {
      return reply.status(400).send({ success: false, error: 'يجب تحديد المحامي المطلوب' });
    }

    if (!body.problemDescription || body.problemDescription.trim().length === 0) {
      return reply.status(400).send({ success: false, error: 'يرجى كتابة وصف تفصيلي للمشكلة أو المهمة' });
    }

    const clientLat = Number(body.clientLat);
    const clientLon = Number(body.clientLon);
    if (!Number.isFinite(clientLat) || !Number.isFinite(clientLon)) {
      return reply.status(400).send({ success: false, error: 'إحداثيات موقع العميل غير صالحة' });
    }

    const openRes = await query(
      `SELECT 1 FROM service_orders WHERE client_id = $1 AND status IN ('PENDING', 'ACCEPTED', 'ACTIVE') LIMIT 1`,
      [userId]
    );
    if (openRes.rows.length > 0) {
      return reply.status(409).send({ success: false, error: 'عندك طلب مفتوح بالفعل، كمله من صفحة الطلبات' });
    }

    // Verify target lawyer exists, is active, approved, and available
    const lawyerRes = await query(
      `SELECT u.id as user_id, u.status, lp.full_name, lp.approval_status, lp.is_available, lp.latitude, lp.longitude,
              lp.suspended_until, lp.urgent_status
       FROM users u
       JOIN lawyer_profiles lp ON u.id = lp.user_id
       WHERE u.id = $1 AND u.role = 'lawyer'`,
      [body.lawyerId]
    );

    if (lawyerRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'المحامي المحدد غير موجود' });
    }

    const targetLawyer = lawyerRes.rows[0];
    if (targetLawyer.approval_status !== 'approved' || targetLawyer.status !== 'active') {
      return reply.status(400).send({ success: false, error: 'عذراً، المحامي المحدد ليس في حالة نشطة ومعتمدة حالياً' });
    }
    if (targetLawyer.urgent_status !== 'APPROVED' || !targetLawyer.is_available || targetLawyer.suspended_until || await lawyerHasOpenOrder(dbPool, targetLawyer.user_id)) {
      return reply.status(409).send({ success: false, error: 'المحامي مشغول دلوقتي، اختار محامي تاني' });
    }

    const cleanServiceTitle = sanitizeText(body.serviceTitle || 'محاميك حالاً', 255);
    const cleanProblemType = body.problemType ? sanitizeText(body.problemType, 100) : null;
    const cleanDescription = sanitizeText(body.problemDescription, 3000);
    const cleanAddress = body.clientAddress ? sanitizeText(body.clientAddress, 500) : null;

    const newOrder = await withTransaction(async (client) => {
      // The server owns the price, so a client request cannot change it
      const quote = await resolveClientQuote(client, userId, cleanProblemType);

      const orderRes = await client.query(
        // The database gives the order its ML-ORD number
        `INSERT INTO service_orders (
          client_id, lawyer_id, service_type,
          service_title, problem_type, problem_description,
          client_latitude, client_longitude, client_address,
          lawyer_latitude, lawyer_longitude, price, commission_percent, tax_percent, lawyer_amount,
          response_deadline, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
          NOW() + make_interval(secs => $16), 'PENDING')
        RETURNING *`,
        [
          userId,
          targetLawyer.user_id,
          body.serviceType || 'lawyer_now',
          cleanServiceTitle,
          cleanProblemType,
          cleanDescription,
          clientLat,
          clientLon,
          cleanAddress,
          targetLawyer.latitude,
          targetLawyer.longitude,
          quote.price,
          quote.commissionPercent,
          quote.taxPercent,
          quote.lawyerAmount,
          LAWYER_RESPONSE_SECONDS,
        ]
      );

      const createdOrder = orderRes.rows[0];

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, NULL, 'PENDING', 'تم إنشاء الطلب بنجاح وإرساله للمحامي')`,
        [createdOrder.id, userId]
      );

      await notify(client, targetLawyer.user_id, 'طلب جديد', `${cleanProblemType || cleanServiceTitle}. رد خلال دقيقتين`, createdOrder.id);

      return createdOrder;
    });

    return reply.status(201).send({
      success: true,
      message: 'تم إرسال طلبك إلى المحامي بنجاح',
      data: {
        id: newOrder.id,
        orderNumber: newOrder.order_number,
        serviceTitle: newOrder.service_title,
        problemType: newOrder.problem_type,
        problemDescription: newOrder.problem_description,
        price: Number(newOrder.price),
        status: newOrder.status,
        createdAt: newOrder.created_at,
        responseSecondsLeft: responseSecondsLeft(newOrder),
        lawyer: {
          id: targetLawyer.user_id,
          name: targetLawyer.full_name,
        }
      }
    });
  });
}
