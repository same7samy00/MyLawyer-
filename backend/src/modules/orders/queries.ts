import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { query } from '../../database/index.js';
import { REVIEW_WINDOW_DAYS } from '../lifecycle/service.js';
import { OPEN_ORDER_TICKET } from '../support/service.js';
import { hideLiveColumns, livePosition, PAID_STATUSES, paySecondsLeft, visibleLocation, AuthenticatedUser } from './shared.js';

// Building a date format is slow, and this list is read on every refresh
const ORDER_DATE = new Intl.DateTimeFormat('ar-EG', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

/// Reading orders and the lawyer wallet summary
export async function registerOrderQueries(fastify: FastifyInstance) {
  // 2. GET /api/v1/orders - List orders for current user (client or lawyer)
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const { userId, role } = request.user as AuthenticatedUser;
    const queryParams = request.query as { status?: string; id?: string };
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
             lp.rating as lawyer_rating,
             EXISTS (SELECT 1 FROM reviews r WHERE r.order_id = o.id) as has_review,
             (SELECT st.id FROM support_tickets st WHERE st.order_id = o.id AND st.user_id = $1 AND st.status <> 'CLOSED' LIMIT 1) as open_ticket_id,
             ${OPEN_ORDER_TICKET('o.id')} as has_open_complaint,
             EXISTS (SELECT 1 FROM reviews r WHERE r.order_id = o.id AND r.edited = FALSE
                     AND o.completed_at > NOW() - make_interval(days => ${REVIEW_WINDOW_DAYS})) as review_editable
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
      sql += ` WHERE TRUE`;
    }

    if (statusFilter !== 'ALL') {
      params.push(statusFilter);
      sql += ` AND o.status = $${params.length}`;
    }

    // One order in the same shape as the list, for an app that heard only this one changed
    if (queryParams.id) {
      params.push(queryParams.id);
      sql += ` AND o.id::text = $${params.length}`;
    }

    sql += ` ORDER BY o.created_at DESC LIMIT 100`;

    const res = await query(sql, params);

    const formattedOrders = res.rows.map((o) => {
      let statusLabel = 'طلب';
      if (o.status === 'ACCEPTED') statusLabel = 'اخترت المحامي';
      else if (o.status === 'ACTIVE') statusLabel = 'جاري التنفيذ';
      else if (o.status === 'COMPLETED') statusLabel = 'مكتمل بنجاح';
      else if (o.status === 'CANCELLED') statusLabel = 'تم الإلغاء';
      else if (o.status === 'EXPIRED') statusLabel = 'انتهت المهلة';
      else if (o.status === 'PAYMENT_EXPIRED') statusLabel = o.release_reason === 'TAKEN' ? 'المحامي اتشغل' : 'ما كمّلتش الدفع';
      else if (o.status === 'REFUNDED') statusLabel = 'تم رد المبلغ';

      const formattedDate = ORDER_DATE.format(new Date(o.created_at));

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
        ...livePosition(o, userId),
        cancellationReason: o.cancellation_reason,
        rejectionReason: o.rejection_reason,
        acceptedAt: o.accepted_at,
        completedAt: o.completed_at,
        paidAt: o.paid_at,
        arrivedAt: o.arrived_at,
        paymentDeadline: o.payment_deadline,
        // Why a chosen order closed before payment: TAKEN or UNPAID
        releaseReason: o.release_reason,
        paySecondsLeft: paySecondsLeft(o),
        expiresAt: o.expires_at,
        arrivalDeadline: o.arrival_deadline,
        delayNotifiedAt: o.delay_notified_at,
        clientKeepsWaiting: o.client_keeps_waiting,
        postponedAt: o.postponed_at,
        postponedUntil: o.postponed_until,
        postponedReason: o.postponed_reason,
        holdUntil: o.hold_until,
        payoutStatus: o.payout_status,
        hasReview: o.has_review,
        openTicketId: o.open_ticket_id,
        hasOpenComplaint: o.has_open_complaint,
        canEditReview: o.review_editable,
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
              u_lawyer.phone as lawyer_phone,
              lp.full_name as lawyer_name,
              lp.profile_photo_path as lawyer_avatar
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

    order.paySecondsLeft = paySecondsLeft(order);
    Object.assign(order, livePosition(order, userId));
    hideLiveColumns(order);

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
      delete order.tax_percent;
      if (order.client_id === userId) {
        delete order.lawyer_amount;
        delete order.payout_amount;
      }
    }

    // Fetch audit trail logs, without the phone numbers of whoever made each change
    const logsRes = await query(
      `SELECT id, old_status, new_status, note, created_at
       FROM order_status_logs
       WHERE order_id = $1
       ORDER BY created_at ASC`,
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
         COALESCE(SUM(payout_amount) FILTER (WHERE payout_status = 'AVAILABLE'), 0)
           + (SELECT COALESCE(SUM(amount), 0) FROM lawyer_adjustments WHERE lawyer_id = $1) AS available,
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
}
