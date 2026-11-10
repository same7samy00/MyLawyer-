import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { sweepLifecycle, lawyerId, clientId, clientToken, lawyerToken, call, sql, createOrder, createPaidOrder, createCompletedOrder } from './harness.js';

const unreadOn = async (userId: string, orderId: string) =>
  (await sql('SELECT COUNT(*)::int AS total FROM notifications WHERE user_id = $1 AND order_id = $2 AND read_at IS NULL', [userId, orderId]))[0].total;

describe('ترتيب الإشعارات', () => {
  it('أي إجراء على الطلب بيعلّم إشعاراته مقروءة لصاحب الإجراء', async () => {
    const order = await createPaidOrder();
    assert.equal(await unreadOn(lawyerId, order.id), 1, '«الموكل دفع» وصل المحامي');
    assert.equal((await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 })).status, 200);
    assert.equal(await unreadOn(lawyerId, order.id), 0, 'المحامي اتصرف، فإشعاره بقى مقروء');
    assert.equal(await unreadOn(clientId, order.id), 1, '«المحامي وصل» لسه جديد للموكل');
  });

  it('الإجراء اللي فشل ما بيعلّمش حاجة', async () => {
    const order = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 409);
    assert.equal(await unreadOn(lawyerId, order.id), 1);
  });

  it('لو الموكل ما دفعش، المحامي بيعرف', async () => {
    const order = await createOrder();
    await sql(`UPDATE service_orders SET payment_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    const rows = await sql('SELECT title, body, read_at FROM notifications WHERE user_id = $1 AND order_id = $2', [lawyerId, order.id]);
    assert.equal(rows.length, 1, 'سطر واحد للطلب: آخر خبر');
    assert.equal(rows[0].title, 'الطلب اتلغى');
    assert.match(rows[0].body, /ما دفعش/);
  });

  it('«طلب جديد» اللي وقته خلص بيبقى مقروء لوحده', async () => {
    const sent = await call('POST', '/requests', clientToken, { problemType: 'محضر في قسم الشرطة', problemDescription: 'وصف', clientLat: 30.05, clientLon: 31.25 });
    assert.equal(sent.status, 201, JSON.stringify(sent.body));
    const requestId = sent.body.data.id as string;
    const before = await sql('SELECT read_at FROM notifications WHERE user_id = $1 AND request_id = $2', [lawyerId, requestId]);
    assert.equal(before.length, 1);
    assert.equal(before[0].read_at, null);
    await sql(`UPDATE service_requests SET status = 'CANCELLED' WHERE id = $1`, [requestId]);
    const summary = await call('GET', '/notifications/summary', lawyerToken);
    assert.equal(summary.status, 200);
    const after = await sql('SELECT read_at FROM notifications WHERE user_id = $1 AND request_id = $2', [lawyerId, requestId]);
    assert.notEqual(after[0].read_at, null);
  });

  it('«تقييم جديد» بيفتح تقييمات المحامي', async () => {
    const order = await createCompletedOrder();
    assert.equal((await call('POST', `/orders/${order.id}/review`, clientToken, { rating: 5 })).status, 201);
    const list = await call('GET', '/notifications', lawyerToken);
    const item = list.body.data.find((row: any) => row.title === 'تقييم جديد');
    assert.equal(item.screen, 'reviews');
    const orders = await call('GET', `/orders?id=${order.id}`, lawyerToken);
    assert.equal(orders.body.data[0].reviewRating, 5, 'المحامي شايف النجوم على الطلب');
    const mine = await call('GET', `/orders?id=${order.id}`, clientToken);
    assert.equal(mine.body.data[0].lawyerId, lawyerId, 'الموكل يقدر يفتح ملف المحامي من الطلب');
  });
});
