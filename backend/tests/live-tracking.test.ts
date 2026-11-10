import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { call, sql, closeOrders, createOrder, createPaidOrder, clientToken, lawyerToken } from './harness.js';

const send = (token: string, orderId: string, latitude: number, longitude: number) =>
  call('POST', `/orders/${orderId}/position`, token, { latitude, longitude });
const listed = async (token: string, orderId: string) =>
  ((await call('GET', '/orders', token)).body.data as any[]).find((o) => o.orderId === orderId);
// Each side may share once every few seconds, so tests clear the last time instead of waiting
const allowNextPoint = (orderId: string) =>
  sql('UPDATE service_orders SET lawyer_live_at = lawyer_live_at - INTERVAL \'1 minute\', client_live_at = client_live_at - INTERVAL \'1 minute\' WHERE id = $1', [orderId]);

describe('التتبع اللحظي', () => {
  it('مفيش تتبع قبل الدفع', async () => {
    await closeOrders();
    const order = await createOrder();
    const res = await send(lawyerToken, order.id, 30.06, 31.26);
    assert.equal(res.status, 200);
    assert.equal(res.body.data.tracking, false);
    assert.equal((await listed(clientToken, order.id)).liveLatitude, null);
  });

  it('بعد الدفع كل طرف بيشوف آخر نقطة للطرف التاني بس، ومحدش غيرهم', async () => {
    await closeOrders();
    const order = await createPaidOrder();

    assert.equal((await send(lawyerToken, order.id, 30.06, 31.26)).body.data.tracking, true);
    const forClient = await listed(clientToken, order.id);
    assert.equal(forClient.liveLatitude, 30.06);
    assert.equal(forClient.liveLongitude, 31.26);
    // The lawyer does not get their own point back, only the client's, which is not shared yet
    assert.equal((await listed(lawyerToken, order.id)).liveLatitude, null);

    // Too soon after the last point: accepted, but the stored point stays
    await send(lawyerToken, order.id, 30.07, 31.27);
    assert.equal((await listed(clientToken, order.id)).liveLatitude, 30.06);

    await allowNextPoint(order.id);
    await send(lawyerToken, order.id, 30.07, 31.27);
    assert.equal((await listed(clientToken, order.id)).liveLatitude, 30.07);

    const detail = (await call('GET', `/orders/${order.id}`, clientToken)).body.data.order;
    assert.equal(detail.liveLatitude, 30.07);
    assert.equal('lawyer_live_latitude' in detail, false);
  });

  it('إحداثيات بره مصر أو طلب مش بتاعك بيترفضوا', async () => {
    await closeOrders();
    const order = await createPaidOrder();
    assert.equal((await send(lawyerToken, order.id, 48.8, 2.3)).status, 400);
    assert.equal((await call('POST', '/orders/00000000-0000-0000-0000-000000000000/position', lawyerToken, { latitude: 30.06, longitude: 31.26 })).status, 404);
  });

  it('«وصلت» بيتقبل جنب مكان الموكل الحالي، وبعد الوصول التتبع بيقف', async () => {
    await closeOrders();
    const order = await createPaidOrder();
    // The client walked about 1 km away from where they asked (30.05, 31.25)
    const now = { lat: 30.059, lon: 31.25 };
    const arrive = () => call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: now.lat + 0.0002, longitude: now.lon });

    assert.equal((await arrive()).status, 400, 'far from the first point, and no live point yet');
    await send(clientToken, order.id, now.lat, now.lon);
    assert.equal((await arrive()).status, 200);

    const after = await send(lawyerToken, order.id, now.lat, now.lon);
    assert.equal(after.body.data.tracking, false);
    assert.equal((await listed(clientToken, order.id)).liveLatitude, null);
  });

  it('المكان المزيف بيترفض: لا مكان المحامي، ولا نقطة الطريق، ولا «وصلت»', async () => {
    await closeOrders();
    const order = await createPaidOrder();
    const fake = { latitude: 30.0501, longitude: 31.25, mocked: true };
    assert.equal((await call('POST', '/lawyers/me/location', lawyerToken, fake)).status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/position`, lawyerToken, fake)).status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/arrive`, lawyerToken, fake)).status, 400);
    assert.equal((await sql('SELECT arrived_at FROM service_orders WHERE id = $1', [order.id]))[0].arrived_at, null);
    // The same point from a phone with no fake-location app is taken
    assert.equal((await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { ...fake, mocked: false })).status, 200);
  });

  it('محامي كان بعيد من ثواني ما يقدرش يدوس «وصلت»: المكان نطّ', async () => {
    await closeOrders();
    const order = await createPaidOrder();
    // 11 km away a few seconds ago, then suddenly at the client's door
    await send(lawyerToken, order.id, 30.15, 31.25);
    const arrive = () => call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0501, longitude: 31.25 });
    assert.equal((await arrive()).status, 400);
    // The same distance over twenty minutes is a normal drive
    await sql(`UPDATE service_orders SET lawyer_live_at = NOW() - INTERVAL '20 minutes' WHERE id = $1`, [order.id]);
    assert.equal((await arrive()).status, 200);
  });

  it('لو موبايل الموكل بطّل يبعت، «وصلت» بيتقبل جنب آخر نقطة بعتها مهما كانت قديمة', async () => {
    await closeOrders();
    const order = await createPaidOrder();
    await send(clientToken, order.id, 30.059, 31.25);
    await sql(`UPDATE service_orders SET client_live_at = NOW() - INTERVAL '3 hours' WHERE id = $1`, [order.id]);
    const res = await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0592, longitude: 31.25 });
    assert.equal(res.status, 200, JSON.stringify(res.body));
  });
});
