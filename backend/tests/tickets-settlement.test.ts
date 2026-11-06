import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, createPaidOrder, createArrivedOrder, createCompletedOrder, openTicket, wallet, clientBalance } from './harness.js';

describe('تذاكر الفلوس والتسوية بالالتقاء', () => {
  const settlement = async (orderId: string) => (await call('GET', `/admin/orders/${orderId}/settlement`, adminToken)).body.data;
  const settle = (orderId: string, body: object = {}) => call('POST', `/admin/orders/${orderId}/settle`, adminToken, body);

  it('المحامي ما وصلش: الفلوس ترجع للموكل كاملة', async () => {
    const order = await createPaidOrder();
    assert.equal((await openTicket(clientToken, order.id)).status, 201);
    assert.equal((await settlement(order.id)).outcome, 'REFUND');

    assert.equal((await settle(order.id)).status, 200);
    assert.equal(await clientBalance(), 350);
    assert.equal((await wallet()).availableBalance, 0);
  });

  it('المحامي أنهى المهمة: الأتعاب للمحامي حتى لو فيه تذكرة فلوس', async () => {
    const order = await createCompletedOrder();
    await openTicket(clientToken, order.id);
    assert.equal((await wallet()).frozenBalance, 350);
    assert.equal((await settlement(order.id)).outcome, 'LAWYER');

    await settle(order.id);
    assert.equal((await wallet()).availableBalance, 350);
    assert.equal(await clientBalance(), 0);
  });

  it('المحامي ما يفتحش تذكرة على طلب مدفوع قبل وصوله، فرد فلوس الموكل ما يتوقفش (SEC-04)', async () => {
    const order = await createPaidOrder();
    assert.equal((await openTicket(lawyerToken, order.id, 'ORDER')).status, 409);
    assert.equal((await sql('SELECT COUNT(*)::int AS total FROM support_tickets WHERE order_id = $1', [order.id]))[0].total, 0);

    // The client still can, and after arriving the lawyer can too
    assert.equal((await openTicket(clientToken, order.id, 'ORDER')).status, 201);
    await sql(`UPDATE support_tickets SET status = 'CLOSED' WHERE order_id = $1`, [order.id]);
    assert.equal((await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 })).status, 200);
    assert.equal((await openTicket(lawyerToken, order.id, 'ORDER')).status, 201);
  });

  it('المحامي وصل وما أنهاش المهمة: الأتعاب للمحامي، والنسبة على نصيبه', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1000, max_price = 1000, commission_percent = 20 WHERE problem_type = $1`, [PROBLEM]);
    const order = await createArrivedOrder();
    await openTicket(lawyerToken, order.id);
    assert.equal((await settlement(order.id)).outcome, 'LAWYER');

    await settle(order.id);
    assert.equal(await clientBalance(), 0);
    assert.equal((await wallet()).availableBalance, 800);
  });

  it('التقسيم مناصفة مش موجود', async () => {
    const order = await createArrivedOrder();
    assert.equal((await settle(order.id, { outcome: 'SPLIT' })).status, 400);
  });

  it('تذكرة الفلوس توقف الإنهاء والمهلة لحد القرار', async () => {
    const order = await createArrivedOrder();
    await openTicket(clientToken, order.id);
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 409);

    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'ACTIVE');
  });

  it('مفيش تذكرة على طلب بعد 24 ساعة من إنهائه، لا للموكل ولا للمحامي', async () => {
    const order = await createCompletedOrder();
    await sql(`UPDATE service_orders SET completed_at = NOW() - INTERVAL '25 hours', hold_until = NOW() - INTERVAL '1 hour', payout_status = 'AVAILABLE' WHERE id = $1`, [order.id]);
    assert.equal((await openTicket(clientToken, order.id, 'ORDER')).status, 409);
    assert.equal((await openTicket(lawyerToken, order.id, 'ORDER')).status, 409);
    assert.equal((await wallet()).frozenBalance, 0);
    assert.equal((await wallet()).availableBalance, 350);
  });

  it('التذكرة خلال 24 ساعة من الإنهاء بتجمد الأتعاب، وبتوصل للطرف التاني إشعار', async () => {
    const order = await createCompletedOrder();
    assert.equal((await openTicket(clientToken, order.id, 'ORDER')).status, 201);
    assert.equal((await wallet()).frozenBalance, 350);
    // One line per order: the latest step about this order replaces the earlier ones
    const notes = await sql(`SELECT title FROM notifications WHERE user_id = $1 AND order_id = $2`, [lawyerId, order.id]);
    assert.equal(notes.length, 1);
    assert.ok(['مراجعة على طلب', 'أتعابك اتجمدت'].includes(notes[0].title));
  });

  it('التذكرة محتاجة نوع، والغريب ما يفتحش على طلب', async () => {
    const order = await createCompletedOrder();
    assert.equal((await call('POST', '/support/tickets', clientToken, { title: 'مشكلة', body: 'تفاصيل المشكلة بالكامل' })).status, 400);

    const other = await createUser('01000000009', 'client');
    assert.equal((await openTicket(app.jwt.sign({ userId: other, role: 'client' }), order.id)).status, 404);
  });

  it('الإشعار بيقول يفتح إيه: رد الإدارة بيفتح التذكرة، وفيه رقم التذكرة', async () => {
    const order = await createCompletedOrder();
    const ticket = (await openTicket(lawyerToken, order.id, 'ORDER')).body.data;
    const mine = (await call('GET', '/orders', lawyerToken)).body.data.find((o: any) => o.orderId === order.id);
    assert.equal(mine.openTicketId, ticket.id);

    await call('POST', `/admin/support/${ticket.id}/reply`, adminToken, { body: 'بنراجع' });
    const list = (await call('GET', '/notifications', lawyerToken)).body.data;
    const reply = list.find((n: any) => n.title === 'رد من الدعم الفني');
    assert.equal(reply.ticketId, ticket.id);
  });
});
