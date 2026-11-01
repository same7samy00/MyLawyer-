import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { dbPool, query, withTransaction } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';
import {
  addClientCredit,
  addLawyerStrike,
  approximateCoordinate,
  APPEAL_WINDOW_DAYS,
  ARRIVAL_RADIUS_KM,
  COMPLAINT_WINDOW_DAYS,
  generateCompletionCode,
  HOLD_HOURS,
  LAWYER_RESPONSE_SECONDS,
  lawyerHasOpenOrder,
  MAX_CODE_ATTEMPTS,
  notify,
  ORDER_DEADLINE_HOURS,
  PAYMENT_MINUTES,
  resolveClientQuote,
  REVIEW_WINDOW_DAYS,
} from '../lifecycle/service.js';

interface AuthenticatedUser {
  userId: string;
  role: 'client' | 'lawyer' | 'admin';
}

// Contact details stay hidden until payment so the deal stays on the platform
const PAID_STATUSES = ['ACTIVE', 'COMPLETED'];

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Seconds come from the server so a wrong phone clock can't change the countdown
function responseSecondsLeft(order: { status: string; response_deadline: string | Date | null }): number {
  if (order.status !== 'PENDING' || !order.response_deadline) return 0;
  const left = (new Date(order.response_deadline).getTime() - Date.now()) / 1000;
  return Math.max(0, Math.ceil(left));
}

// Before payment the lawyer reads only the governorate from the general area name
function governorateOf(area: string | null): string | null {
  if (!area) return null;
  return area.split('،').pop()?.trim() || null;
}

// Each side sees the other's exact place and area only after payment
function visibleLocation(order: any, viewerId: string, role: string) {
  const isShared = role === 'admin' || PAID_STATUSES.includes(order.status);
  const coarse = (value: unknown) => (value == null ? null : isShared ? Number(value) : approximateCoordinate(Number(value)));
  const isClient = order.client_id === viewerId;
  const isLawyer = order.lawyer_id === viewerId;

  return {
    clientLatitude: isClient ? Number(order.client_latitude) : coarse(order.client_latitude),
    clientLongitude: isClient ? Number(order.client_longitude) : coarse(order.client_longitude),
    clientAddress: isClient || isShared ? order.client_address : governorateOf(order.client_address),
    lawyerLatitude: isLawyer ? (order.lawyer_latitude == null ? null : Number(order.lawyer_latitude)) : coarse(order.lawyer_latitude),
    lawyerLongitude: isLawyer ? (order.lawyer_longitude == null ? null : Number(order.lawyer_longitude)) : coarse(order.lawyer_longitude),
  };
}

export async function orderRoutes(fastify: FastifyInstance) {
  // Authentication hook for all order endpoints
  fastify.addHook('onRequest', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: 'غير مصرح: يرجى تسجيل الدخول' });
    }
  });

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
              lp.suspended_until
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
    if (!targetLawyer.is_available || targetLawyer.suspended_until || await lawyerHasOpenOrder(dbPool, targetLawyer.user_id)) {
      return reply.status(409).send({ success: false, error: 'المحامي مشغول دلوقتي، اختار محامي تاني' });
    }

    // Generate unique order number
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const orderNumber = `ORD-${Date.now().toString().slice(-6)}-${randomSuffix}`;

    const cleanServiceTitle = sanitizeText(body.serviceTitle || 'محاميك حالاً', 255);
    const cleanProblemType = body.problemType ? sanitizeText(body.problemType, 100) : null;
    const cleanDescription = sanitizeText(body.problemDescription, 3000);
    const cleanAddress = body.clientAddress ? sanitizeText(body.clientAddress, 500) : null;

    const newOrder = await withTransaction(async (client) => {
      // The server owns the price, so a client request cannot change it
      const quote = await resolveClientQuote(client, userId, cleanProblemType);

      const orderRes = await client.query(
        `INSERT INTO service_orders (
          order_number, client_id, lawyer_id, service_type,
          service_title, problem_type, problem_description,
          client_latitude, client_longitude, client_address,
          lawyer_latitude, lawyer_longitude, price, commission_percent, lawyer_amount,
          response_deadline, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
          NOW() + make_interval(secs => $16), 'PENDING')
        RETURNING *`,
        [
          orderNumber,
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

      await notify(client, targetLawyer.user_id, 'طلب جديد', cleanProblemType || cleanServiceTitle, createdOrder.id);

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

  // 2. GET /api/v1/orders - List orders for current user (client or lawyer)
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const queryParams = request.query as { status?: string };
    const statusFilter = queryParams.status ? queryParams.status.toUpperCase() : 'ALL';

    let sql = `
      SELECT o.*,
             u_client.phone as client_phone,
             u_client.email as client_email,
             COALESCE(u_client.full_name, 'موكل') as client_name,
             (SELECT COUNT(*)::int FROM service_orders done WHERE done.client_id = o.client_id AND done.status = 'COMPLETED') as client_completed_orders,
             u_lawyer.phone as lawyer_phone,
             lp.full_name as lawyer_name,
             lp.profile_photo_path as lawyer_avatar,
             lp.specialty as lawyer_specialty,
             lp.rating as lawyer_rating,
             EXISTS (SELECT 1 FROM reviews r WHERE r.order_id = o.id) as has_review,
             EXISTS (SELECT 1 FROM complaints c WHERE c.order_id = o.id) as has_complaint,
             EXISTS (SELECT 1 FROM complaints c WHERE c.order_id = o.id AND c.status = 'OPEN') as has_open_complaint,
             EXISTS (SELECT 1 FROM order_appeals a WHERE a.order_id = o.id) as has_appeal,
             EXISTS (SELECT 1 FROM lawyer_reports lr WHERE lr.order_id = o.id) as has_report,
             EXISTS (SELECT 1 FROM reviews r WHERE r.order_id = o.id AND r.published_at IS NULL AND r.edited = FALSE) as review_editable
      FROM service_orders o
      JOIN users u_client ON o.client_id = u_client.id
      JOIN users u_lawyer ON o.lawyer_id = u_lawyer.id
      JOIN lawyer_profiles lp ON u_lawyer.id = lp.user_id
    `;

    const params: any[] = [userId];

    if (role === 'lawyer') {
      sql += ` WHERE o.lawyer_id = $1`;
    } else if (role === 'client') {
      sql += ` WHERE o.client_id = $1`;
    } else {
      // admin can view all
      sql = sql.replace('WHERE o.client_id = $1', '');
      params.pop();
    }

    if (statusFilter !== 'ALL') {
      if (params.length > 0) {
        params.push(statusFilter);
        sql += ` AND o.status = $${params.length}`;
      } else {
        params.push(statusFilter);
        sql += ` WHERE o.status = $1`;
      }
    }

    sql += ` ORDER BY o.created_at DESC LIMIT 100`;

    const res = await query(sql, params);

    const formattedOrders = res.rows.map((o) => {
      let statusLabel = 'طلب وارد';
      if (o.status === 'PENDING') statusLabel = 'قيد انتظار الموافقة';
      else if (o.status === 'ACCEPTED') statusLabel = 'تم قبول الطلب';
      else if (o.status === 'ACTIVE') statusLabel = 'جاري التنفيذ';
      else if (o.status === 'COMPLETED') statusLabel = 'مكتمل بنجاح';
      else if (o.status === 'CANCELLED') statusLabel = 'تم الإلغاء';
      else if (o.status === 'REJECTED') statusLabel = 'تم الاعتذار';
      else if (o.status === 'EXPIRED') statusLabel = 'انتهت المهلة';
      else if (o.status === 'NO_RESPONSE') statusLabel = 'المحامي ما ردش';
      else if (o.status === 'PAYMENT_EXPIRED') statusLabel = 'انتهت مهلة الدفع';
      else if (o.status === 'REFUNDED') statusLabel = 'تم رد المبلغ';

      const createdAtDate = new Date(o.created_at);
      const formattedDate = createdAtDate.toLocaleDateString('ar-EG', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });

      return {
        id: o.order_number,
        orderId: o.id,
        orderNumber: o.order_number,
        serviceTitle: o.service_title,
        clientName: o.client_name,
        clientCompletedOrders: o.client_completed_orders,
        clientPhone: PAID_STATUSES.includes(o.status) ? o.client_phone : null,
        clientChoice: o.problem_type || o.service_title,
        problemDescription: o.problem_description,
        specialty: o.lawyer_specialty || 'محامٍ معتمد',
        lawyerName: o.lawyer_name,
        lawyerPhone: PAID_STATUSES.includes(o.status) ? o.lawyer_phone : null,
        lawyerAvatar: o.lawyer_avatar,
        status: o.status,
        statusLabel,
        // The lawyer sees only the net amount, the client only the full price
        price: Number(role === 'lawyer' ? o.lawyer_amount : o.price),
        date: formattedDate,
        createdAt: o.created_at,
        ...visibleLocation(o, userId, role),
        cancellationReason: o.cancellation_reason,
        rejectionReason: o.rejection_reason,
        acceptedAt: o.accepted_at,
        completedAt: o.completed_at,
        paidAt: o.paid_at,
        arrivedAt: o.arrived_at,
        paymentDeadline: o.payment_deadline,
        responseDeadline: o.response_deadline,
        responseSecondsLeft: responseSecondsLeft(o),
        expiresAt: o.expires_at,
        holdUntil: o.hold_until,
        payoutStatus: o.payout_status,
        hasReview: o.has_review,
        hasComplaint: o.has_complaint,
        hasOpenComplaint: o.has_open_complaint,
        hasAppeal: o.has_appeal,
        canEditReview: o.review_editable,
        hasReport: o.has_report,
        isCodeLocked: o.code_attempts >= MAX_CODE_ATTEMPTS,
        // The code proves the client's approval, so only the client ever receives it
        completionCode: role === 'client' && o.status === 'ACTIVE' ? o.completion_code : null,
      };
    });

    return reply.send({
      success: true,
      data: formattedOrders,
    });
  });

  // 3. GET /api/v1/orders/:id - Get single order details with ownership verification
  fastify.get('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    const orderRes = await query(
      `SELECT o.*,
              u_client.phone as client_phone,
              u_client.email as client_email,
              u_lawyer.phone as lawyer_phone,
              lp.full_name as lawyer_name,
              lp.profile_photo_path as lawyer_avatar,
              lp.specialty as lawyer_specialty
       FROM service_orders o
       JOIN users u_client ON o.client_id = u_client.id
       JOIN users u_lawyer ON o.lawyer_id = u_lawyer.id
       JOIN lawyer_profiles lp ON u_lawyer.id = lp.user_id
       WHERE o.id::text = $1 OR o.order_number = $1`,
      [id]
    );

    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });
    }

    const order = orderRes.rows[0];

    // Authorization check
    if (role !== 'admin' && order.client_id !== userId && order.lawyer_id !== userId) {
      return reply.status(403).send({ success: false, error: 'غير مصرح لك بعرض تفاصيل هذا الطلب' });
    }

    // Only the client may read the code that ends the mission
    if (order.client_id !== userId) {
      delete order.completion_code;
    }

    if (!PAID_STATUSES.includes(order.status)) {
      order.client_phone = null;
      order.lawyer_phone = null;
    }

    order.responseSecondsLeft = responseSecondsLeft(order);

    const location = visibleLocation(order, userId, role);
    order.client_latitude = location.clientLatitude;
    order.client_longitude = location.clientLongitude;
    order.client_address = location.clientAddress;
    order.lawyer_latitude = location.lawyerLatitude;
    order.lawyer_longitude = location.lawyerLongitude;
    if (role !== 'admin' && !PAID_STATUSES.includes(order.status)) {
      delete order.arrived_latitude;
      delete order.arrived_longitude;
    }

    if (order.lawyer_id === userId) {
      order.price = order.lawyer_amount;
    }
    if (role !== 'admin') {
      delete order.commission_percent;
      if (order.client_id === userId) delete order.lawyer_amount;
    }

    // Fetch audit trail logs
    const logsRes = await query(
      `SELECT l.id, l.old_status, l.new_status, l.note, l.created_at, u.phone as changed_by_phone
       FROM order_status_logs l
       JOIN users u ON l.changed_by_user_id = u.id
       WHERE l.order_id = $1
       ORDER BY l.created_at ASC`,
      [order.id]
    );

    return reply.send({
      success: true,
      data: {
        order,
        statusHistory: logsRes.rows,
      }
    });
  });

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
      await client.query(
        `UPDATE service_orders
         SET status = 'ACCEPTED', accepted_at = NOW(), updated_at = NOW(),
             payment_deadline = NOW() + make_interval(mins => $2),
             lawyer_latitude = COALESCE($3, lawyer_latitude),
             lawyer_longitude = COALESCE($4, lawyer_longitude)
         WHERE id = $1`,
        [order.id, PAYMENT_MINUTES, lat, lon]
      );

      await client.query('UPDATE lawyer_profiles SET missed_orders = 0 WHERE user_id = $1', [userId]);

      if (hasFreshLocation) {
        await client.query(
          `UPDATE lawyer_profiles
           SET latitude = $1, longitude = $2, last_location_updated_at = NOW(), last_active_at = NOW(),
               stale_reminder_sent = FALSE
           WHERE user_id = $3`,
          [lat, lon, userId]
        );
      }

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'PENDING', 'ACCEPTED', 'وافق المحامي على تولي الطلب')`,
        [order.id, userId]
      );

      await notify(client, order.client_id, 'المحامي وافق', 'كمّل الدفع عشان يبدأ المحامي المهمة', order.id);
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
    const body = request.body as { reason?: string };

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
      await client.query(
        `UPDATE service_orders
         SET status = 'REJECTED', rejection_reason = $1, updated_at = NOW()
         WHERE id = $2`,
        [cleanReason, order.id]
      );

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'PENDING', 'REJECTED', $3)`,
        [order.id, userId, `اعتذر المحامي: ${cleanReason}`]
      );

      await notify(client, order.client_id, 'المحامي اعتذر', 'تقدر تختار محامي تاني', order.id);
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

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND client_id = $2`,
      [id, userId]
    );

    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'ACCEPTED') {
      return reply.status(400).send({
        success: false,
        error: 'لا يمكن الدفع قبل موافقة المحامي على الطلب',
      });
    }

    if (new Date(order.payment_deadline).getTime() <= Date.now()) {
      return reply.status(409).send({ success: false, error: 'انتهت مهلة الدفع لهذا الطلب' });
    }

    const body = (request.body || {}) as { method?: string };
    if (body.method === 'wallet') {
      const balanceRes = await query(
        'SELECT COALESCE(SUM(amount), 0) AS balance FROM client_credits WHERE client_id = $1',
        [userId]
      );
      if (Number(balanceRes.rows[0].balance) < Number(order.price)) {
        return reply.status(400).send({ success: false, error: 'رصيدك مش كفاية' });
      }
    }

    await withTransaction(async (client) => {
      if (body.method === 'wallet') {
        await addClientCredit(client, userId, order.id, -Number(order.price), 'سداد طلب من الرصيد');
      }

      await client.query(
        `UPDATE service_orders
         SET status = 'ACTIVE', paid_at = NOW(), completion_code = $2,
             expires_at = NOW() + make_interval(hours => $3), updated_at = NOW()
         WHERE id = $1`,
        [order.id, generateCompletionCode(), ORDER_DEADLINE_HOURS]
      );

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, $3, 'ACTIVE', 'تم سداد الرسوم وبدء سريان المهمة')`,
        [order.id, userId, order.status]
      );

      await notify(client, order.lawyer_id, 'الموكل دفع', 'ابدأ المهمة، وفي الآخر هتحتاج كود الموكل لإنهائها', order.id);
    });

    return reply.send({
      success: true,
      message: 'تم تأكيد الدفع وتفعيل الطلب بنجاح',
      data: { orderId: order.id, status: 'ACTIVE' },
    });
  });

  // 7. POST /api/v1/orders/:id/complete - Lawyer completes active order
  fastify.post('/:id/complete', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };

    if (role !== 'lawyer' && role !== 'admin') {
      return reply.status(403).send({ success: false, error: 'إنهاء الطلبات مخصص للمحامي المعني فقط' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );

    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'ACTIVE') {
      return reply.status(400).send({ success: false, error: 'لا يمكن إنهاء المهمة قبل سداد الموكل' });
    }
    if (!order.arrived_at) {
      return reply.status(409).send({ success: false, error: 'سجل وصولك الأول عند الموكل' });
    }

    const openComplaint = await query(
      `SELECT 1 FROM complaints WHERE order_id = $1 AND status = 'OPEN'`,
      [order.id]
    );
    if (openComplaint.rows.length > 0) {
      return reply.status(409).send({ success: false, error: 'الطلب قيد مراجعة شكوى من الإدارة' });
    }

    if (order.code_attempts >= MAX_CODE_ATTEMPTS) {
      return reply.status(429).send({ success: false, error: 'تم تجاوز عدد المحاولات، الإدارة هتراجع الطلب' });
    }

    const body = (request.body || {}) as { code?: string };
    if (String(body.code ?? '').trim() !== order.completion_code) {
      await query('UPDATE service_orders SET code_attempts = code_attempts + 1 WHERE id = $1', [order.id]);
      return reply.status(400).send({ success: false, error: 'كود الإنهاء غير صحيح' });
    }

    const completedOrder = await withTransaction(async (client) => {
      const res = await client.query(
        `UPDATE service_orders
         SET status = 'COMPLETED', completed_at = NOW(), payout_status = 'HELD', payout_amount = lawyer_amount,
             hold_until = NOW() + make_interval(hours => $2), completion_code = NULL, updated_at = NOW()
         WHERE id = $1 RETURNING hold_until`,
        [order.id, HOLD_HOURS]
      );

      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, $3, 'COMPLETED', 'تم إنهاء المهمة بكود الموكل')`,
        [order.id, userId, order.status]
      );

      await notify(client, order.client_id, 'المهمة اتقفلت', 'قيّم المحامي، ولو فيه مشكلة قدم شكوى خلال 24 ساعة', order.id);

      return res.rows[0];
    });

    return reply.send({
      success: true,
      message: 'تم إنهاء المهمة بنجاح',
      data: { orderId: order.id, status: 'COMPLETED', holdUntil: completedOrder.hold_until },
    });
  });

  // 8. POST /api/v1/orders/:id/cancel - Client or Lawyer cancels order
  fastify.post('/:id/cancel', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = request.body as { reason?: string };

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1)`,
      [id]
    );

    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });
    }

    const order = orderRes.rows[0];

    // Authorization
    if (role !== 'admin' && order.client_id !== userId && order.lawyer_id !== userId) {
      return reply.status(403).send({ success: false, error: 'غير مصرح لك بإلغاء هذا الطلب' });
    }

    if (order.status === 'CANCELLED') {
      return reply.status(400).send({ success: false, error: 'الطلب ملغى بالفعل مسبقاً' });
    }
    // After payment only the client may cancel, and only before the lawyer arrives
    const refundOnCancel = order.status === 'ACTIVE' && order.client_id === userId && !order.arrived_at;
    if (order.status !== 'PENDING' && order.status !== 'ACCEPTED' && !refundOnCancel) {
      return reply.status(400).send({ success: false, error: 'لا يمكن إلغاء الطلب في حالته الحالية' });
    }

    const cleanReason = body.reason ? sanitizeText(body.reason, 500) : 'تم الإلغاء بناءً على طلب المستخدم';

    await withTransaction(async (client) => {
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
      await notify(client, otherParty, 'الطلب اتلغى', order.service_title, order.id);
    });

    return reply.send({
      success: true,
      message: 'تم إلغاء الطلب بنجاح',
      data: { orderId: order.id, status: 'CANCELLED' },
    });
  });

  // 9. GET /api/v1/orders/wallet/me - Lawyer balances or client balance
  fastify.get('/wallet/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;

    if (role === 'client') {
      const creditRes = await query(
        'SELECT COALESCE(SUM(amount), 0) AS balance FROM client_credits WHERE client_id = $1',
        [userId]
      );
      const itemsRes = await query(
        'SELECT id, amount, reason, created_at FROM client_credits WHERE client_id = $1 ORDER BY created_at DESC LIMIT 50',
        [userId]
      );

      return reply.send({
        success: true,
        data: {
          balance: Number(creditRes.rows[0].balance),
          items: itemsRes.rows.map((row) => ({
            id: row.id,
            amount: Number(row.amount),
            reason: row.reason,
            createdAt: row.created_at,
          })),
        },
      });
    }

    const res = await query(
      `SELECT
         COALESCE(SUM(payout_amount) FILTER (WHERE payout_status = 'HELD'), 0) AS held,
         COALESCE(SUM(payout_amount) FILTER (WHERE payout_status = 'FROZEN'), 0) AS frozen,
         COALESCE(SUM(payout_amount) FILTER (WHERE payout_status = 'AVAILABLE'), 0) AS available,
         MIN(hold_until) FILTER (WHERE payout_status = 'HELD') AS next_release_at
       FROM service_orders WHERE lawyer_id = $1`,
      [userId]
    );

    const row = res.rows[0];
    return reply.send({
      success: true,
      data: {
        heldBalance: Number(row.held),
        frozenBalance: Number(row.frozen),
        availableBalance: Number(row.available),
        nextReleaseAt: row.next_release_at,
      },
    });
  });

  // 10. POST /api/v1/orders/:id/complaint - Client files a complaint
  fastify.post('/:id/complaint', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    const reason = body.reason ? sanitizeText(body.reason, 2000) : '';
    if (reason.trim().length < 10) {
      return reply.status(400).send({ success: false, error: 'اكتب تفاصيل الشكوى في 10 أحرف على الأقل' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND client_id = $2`,
      [id, userId]
    );
    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'ACTIVE' && order.status !== 'COMPLETED') {
      return reply.status(400).send({ success: false, error: 'لا يمكن تقديم شكوى على هذا الطلب' });
    }

    const openRes = await query(`SELECT 1 FROM complaints WHERE order_id = $1 AND status = 'OPEN'`, [order.id]);
    if (openRes.rows.length > 0) {
      return reply.status(409).send({ success: false, error: 'لديك شكوى مفتوحة على هذا الطلب' });
    }

    // After the hold ends the money is no longer frozen automatically
    const filedAfterHold = order.status === 'COMPLETED' && order.payout_status !== 'HELD';

    if (filedAfterHold && Date.now() > new Date(order.completed_at).getTime() + COMPLAINT_WINDOW_DAYS * 86400000) {
      return reply.status(400).send({ success: false, error: 'انتهت مدة تقديم الشكوى' });
    }

    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO complaints (order_id, client_id, lawyer_id, reason, filed_after_hold)
         VALUES ($1, $2, $3, $4, $5)`,
        [order.id, userId, order.lawyer_id, reason, filedAfterHold]
      );

      if (!filedAfterHold && order.status === 'COMPLETED') {
        await client.query(`UPDATE service_orders SET payout_status = 'FROZEN' WHERE id = $1`, [order.id]);
      }

      await notify(client, order.lawyer_id, 'شكوى على طلب', 'الأتعاب متوقفة لحد ما الإدارة تراجع الشكوى', order.id);
    });

    return reply.status(201).send({
      success: true,
      message: filedAfterHold ? 'تم تسجيل شكواك وستراجعها الإدارة' : 'تم استلام شكواك وإيقاف الأتعاب لحين المراجعة',
    });
  });

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
      `INSERT INTO reviews (order_id, client_id, lawyer_id, rating, comment, publish_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (order_id) DO NOTHING RETURNING id`,
      [order.id, userId, order.lawyer_id, rating, comment, order.hold_until]
    );

    if (res.rows.length === 0) {
      return reply.status(409).send({ success: false, error: 'تم تقييم هذا الطلب من قبل' });
    }

    return reply.status(201).send({ success: true, message: 'شكراً لتقييمك' });
  });

  // 12. POST /api/v1/orders/:id/appeal - Lawyer appeals an expired order
  fastify.post('/:id/appeal', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    const reason = body.reason ? sanitizeText(body.reason, 2000) : '';
    if (reason.trim().length < 10) {
      return reply.status(400).send({ success: false, error: 'اكتب تفاصيل الاعتراض في 10 أحرف على الأقل' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );
    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'EXPIRED') {
      return reply.status(400).send({ success: false, error: 'الاعتراض متاح للطلبات منتهية المهلة فقط' });
    }

    const windowEnd = new Date(order.expires_at).getTime() + APPEAL_WINDOW_DAYS * 86400000;
    if (Date.now() > windowEnd) {
      return reply.status(400).send({ success: false, error: 'انتهت مدة الاعتراض' });
    }

    const res = await query(
      `INSERT INTO order_appeals (order_id, lawyer_id, reason) VALUES ($1, $2, $3)
       ON CONFLICT (order_id) DO NOTHING RETURNING id`,
      [order.id, userId, reason]
    );

    if (res.rows.length === 0) {
      return reply.status(409).send({ success: false, error: 'تم تقديم اعتراض على هذا الطلب من قبل' });
    }

    return reply.status(201).send({ success: true, message: 'تم استلام اعتراضك وستراجعه الإدارة' });
  });

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

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );
    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'ACTIVE' || order.arrived_at) {
      return reply.status(400).send({ success: false, error: 'لا يمكن تسجيل الوصول لهذا الطلب' });
    }

    const distance = distanceKm(lat, lon, Number(order.client_latitude), Number(order.client_longitude));
    if (distance > ARRIVAL_RADIUS_KM) {
      return reply.status(400).send({ success: false, error: 'لسه بعيد عن موقع الموكل' });
    }

    await withTransaction(async (client) => {
      await client.query(
        `UPDATE service_orders SET arrived_at = NOW(), arrived_latitude = $1, arrived_longitude = $2 WHERE id = $3`,
        [lat, lon, order.id]
      );
      await client.query(
        `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
         VALUES ($1, $2, 'ACTIVE', 'ACTIVE', 'وصل المحامي إلى موقع الموكل')`,
        [order.id, userId]
      );
      await notify(client, order.client_id, 'المحامي وصل', 'المحامي وصل لموقعك', order.id);
    });

    return reply.send({ success: true, message: 'تم تسجيل وصولك' });
  });

  // 14. POST /api/v1/orders/:id/withdraw - Lawyer steps down after payment
  fastify.post('/:id/withdraw', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );
    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    if (order.status !== 'ACTIVE') {
      return reply.status(400).send({ success: false, error: 'لا يمكن الاعتذار عن هذا الطلب' });
    }

    const reason = sanitizeText(body.reason || 'اعتذر المحامي بعد الدفع', 500);

    await withTransaction(async (client) => {
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
      await notify(client, order.client_id, 'المحامي اعتذر', 'رجعلك المبلغ في رصيدك وتقدر تختار محامي تاني', order.id);
    });

    return reply.send({ success: true, message: 'تم تسجيل الاعتذار ورد المبلغ للموكل' });
  });

  // 15. POST /api/v1/orders/:id/report - Lawyer reports a problem with the client
  fastify.post('/:id/report', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId } = request.user as AuthenticatedUser;
    const { id } = request.params as { id: string };
    const body = (request.body || {}) as { reason?: string };

    const reason = body.reason ? sanitizeText(body.reason, 2000) : '';
    if (reason.trim().length < 10) {
      return reply.status(400).send({ success: false, error: 'اكتب التفاصيل في 10 أحرف على الأقل' });
    }

    const orderRes = await query(
      `SELECT * FROM service_orders WHERE (id::text = $1 OR order_number = $1) AND lawyer_id = $2`,
      [id, userId]
    );
    if (orderRes.rows.length === 0) {
      return reply.status(404).send({ success: false, error: 'الطلب غير موجود أو غير مسند إليك' });
    }

    const order = orderRes.rows[0];
    await query(
      'INSERT INTO lawyer_reports (order_id, lawyer_id, client_id, reason) VALUES ($1, $2, $3, $4)',
      [order.id, userId, order.client_id, reason]
    );

    return reply.status(201).send({ success: true, message: 'تم إرسال البلاغ للإدارة' });
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
         AND r.published_at IS NULL AND r.edited = FALSE
       RETURNING r.id`,
      [rating, body.comment ? sanitizeText(body.comment, 1000) : null, id, userId]
    );

    if (res.rows.length === 0) {
      return reply.status(400).send({ success: false, error: 'لا يمكن تعديل هذا التقييم' });
    }

    return reply.send({ success: true, message: 'تم تعديل تقييمك' });
  });
}
