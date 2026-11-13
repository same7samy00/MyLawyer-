import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { app, call, sql, closeOrders, clientToken, lawyerToken, adminToken, clientBalance, wallet, lawyerId } from './harness.js';

const SERVICE = 'محضر في قسم الشرطة';
const PLACE = { placeName: 'قسم شرطة المعادي، المعادي، محافظة القاهرة', placeLat: 30.05, placeLon: 31.25 };

const sendRequest = (extra: object = {}, token = clientToken) => call('POST', '/field/requests', token, {
  serviceTitle: SERVICE, problemDescription: 'صديقي اتحجز في القسم', ...PLACE, forOther: true, personName: 'أحمد', relation: 'صديق', detained: true, ...extra,
});

/// A field request taken to a chosen offer. [pay] also pays it, so the lawyer is on the way
async function fieldOrder(extra: object = {}, pay = true) {
  await closeOrders();
  const sent = await sendRequest(extra);
  assert.equal(sent.status, 201, JSON.stringify(sent.body));
  const requestId = sent.body.data.id as string;
  assert.equal((await call('POST', `/requests/${requestId}/offer`, lawyerToken, { price: 350 })).status, 201);
  const offers = (await call('GET', `/requests/${requestId}`, clientToken)).body.data.offers;
  const chosen = await call('POST', `/requests/${requestId}/offers/${offers[0].id}/select`, clientToken, {});
  assert.equal(chosen.status, 200, JSON.stringify(chosen.body));
  const id = chosen.body.data.orderId as string;
  if (pay) assert.equal((await call('POST', `/orders/${id}/confirm-payment`, clientToken, {})).status, 200);
  return { id, requestId };
}

const listed = async (token: string, orderId: string) => ((await call('GET', '/orders', token)).body.data as any[]).find((o) => o.orderId === orderId);
const arrive = (orderId: string, lat: number, lon: number) => call('POST', `/orders/${orderId}/arrive`, lawyerToken, { latitude: lat, longitude: lon });
const typeCode = (orderId: string, code: string) => call('POST', `/field/orders/${orderId}/code`, lawyerToken, { code });
const secretCode = async (requestId: string) => (await sql('SELECT handover_code FROM field_requests WHERE request_id = $1', [requestId]))[0].handover_code as string;

function proofForm(token: string, orderId: string, bytes: Buffer, name = 'proof.png') {
  const boundary = 'field-proof-boundary';
  return app.inject({
    method: 'POST',
    url: `/api/v1/field/orders/${orderId}/proof`,
    headers: { authorization: `Bearer ${token}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
    payload: Buffer.concat([
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${name}"\r\nContent-Type: image/png\r\n\r\n`),
      bytes,
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]),
  });
}
const PNG = Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), Buffer.alloc(32, 1)]);

describe('الخدمات الميدانية: الطلب', () => {
  it('الخدمة لازم تكون ميدانية، والمكان واسم الشخص مطلوبين', async () => {
    await closeOrders();
    assert.equal((await sendRequest({ serviceTitle: 'مشاجرة أو اعتداء أو تهديد' })).status, 400);
    assert.equal((await sendRequest({ placeName: '' })).status, 400);
    assert.equal((await sendRequest({ placeLat: 10, placeLon: 10 })).status, 400);
    assert.equal((await sendRequest({ personName: '' })).status, 400);
    assert.equal((await sendRequest({ problemDescription: '  ' })).status, 400);
    assert.equal((await call('POST', '/field/requests', lawyerToken, { serviceTitle: SERVICE })).status, 403);
    assert.equal((await call('POST', '/field/requests', null, {})).status, 401);
  });

  it('الطلب بيروح للمحامي، والمحامي يشوف النوع والمحافظة بس قبل السعر', async () => {
    await closeOrders();
    const sent = await sendRequest();
    assert.equal(sent.status, 201, JSON.stringify(sent.body));
    const card = (await call('GET', '/requests/incoming', lawyerToken)).body.data[0];
    assert.equal(card.service, SERVICE);
    assert.equal(card.area, 'محافظة القاهرة');
    assert.deepEqual(card.field, { forOther: true, detained: true, placeKind: 'police' });
    assert.ok(!JSON.stringify(card).includes('أحمد'));
  });

  it('محاميك حالاً ما بيتأثرش: طلبه من غير تفاصيل ميدانية', async () => {
    await closeOrders();
    const sent = await call('POST', '/requests', clientToken, { problemType: 'سرقة أو نصب أو احتيال', problemDescription: 'وصف', clientLat: 30.05, clientLon: 31.25 });
    assert.equal(sent.status, 201);
    const card = (await call('GET', '/requests/incoming', lawyerToken)).body.data[0];
    assert.equal(card.service, 'طلب محامي');
    assert.equal(card.field, null);
    const order = await call('GET', '/orders', clientToken);
    assert.ok((order.body.data as any[]).every((o) => o.field === null));
  });
});

describe('الخدمات الميدانية: الكود والوصول', () => {
  it('الكود للموكل بس وبعد الدفع، واسم الشخص للمحامي بعد الدفع', async () => {
    const { id, requestId } = await fieldOrder({}, false);
    assert.equal((await listed(lawyerToken, id)).field.personName, null);
    assert.equal((await listed(clientToken, id)).field.code, null);

    await call('POST', `/orders/${id}/confirm-payment`, clientToken, {});
    const forClient = (await listed(clientToken, id)).field;
    assert.equal(forClient.code, await secretCode(requestId));
    assert.match(forClient.code, /^\d{4}$/);
    const forLawyer = (await listed(lawyerToken, id)).field;
    assert.equal(forLawyer.code, null);
    assert.equal(forLawyer.personName, 'أحمد');
    assert.equal(forLawyer.detained, true);
    assert.equal(forLawyer.placeName, PLACE.placeName);
  });

  it('لنفسي: من غير كود ولا اسم شخص', async () => {
    const { id } = await fieldOrder({ forOther: false, detained: true, personName: 'تجاهل' });
    const field = (await listed(clientToken, id)).field;
    assert.equal(field.forOther, false);
    assert.equal(field.code, null);
    assert.equal(field.personName, null);
    assert.equal(field.detained, false);
    assert.equal((await typeCode(id, '1234')).status, 400);
  });

  it('الوصول بمنطقة المكان: جوه 150 متر للقسم، وبعيد مرفوض', async () => {
    const { id } = await fieldOrder();
    // About 330 meters away
    assert.equal((await arrive(id, 30.053, 31.25)).status, 400);
    // About 110 meters away: outside the 50 meters of the other service, inside a police station's area
    assert.equal((await arrive(id, 30.051, 31.25)).status, 200);
    const field = (await listed(lawyerToken, id)).field;
    assert.equal(field.arrivalMethod, 'area');
    assert.equal((await listed(clientToken, id)).field.code, null);
  });

  it('المكان اللي اتكتب بالإيد منطقته أوسع', async () => {
    const { id } = await fieldOrder({ placeVerified: false });
    assert.equal((await sql(`SELECT arrival_radius_m FROM field_requests f JOIN service_requests r ON r.id = f.request_id WHERE r.order_id = $1`, [id]))[0].arrival_radius_m, 300);
    // About 220 meters away
    assert.equal((await arrive(id, 30.052, 31.25)).status, 200);
  });

  it('الكود الصح بيسجل الوصول، والغلط بيتعد وبيتقفل بعد 5', async () => {
    const { id, requestId } = await fieldOrder();
    const code = await secretCode(requestId);
    const wrong = code === '0000' ? '1111' : '0000';

    for (let i = 0; i < 5; i++) assert.equal((await typeCode(id, wrong)).status, 400);
    assert.equal((await typeCode(id, code)).status, 423);
    assert.equal((await listed(lawyerToken, id)).field.codeLocked, true);
    assert.equal((await listed(lawyerToken, id)).arrivedAt, null);

    // Locked code: the client's confirmation still works
    assert.equal((await call('POST', `/orders/${id}/ask-arrival`, lawyerToken, {})).status, 200);
    assert.equal((await call('POST', `/orders/${id}/confirm-arrival`, clientToken, {})).status, 200);
    assert.equal((await listed(clientToken, id)).field.arrivalMethod, 'client');
  });

  it('كتابة الكود الصح بتسجل الوصول وتبلّغ الموكل', async () => {
    const { id, requestId } = await fieldOrder();
    assert.equal((await typeCode(id, await secretCode(requestId))).status, 200);
    const after = await listed(lawyerToken, id);
    assert.ok(after.arrivedAt);
    assert.equal(after.field.arrivalMethod, 'code');
    // The code is no longer shown once the lawyer has arrived
    assert.equal((await listed(clientToken, id)).field.code, null);
    assert.equal((await typeCode(id, await secretCode(requestId))).status, 400);
    const noticed = await sql(`SELECT 1 FROM notifications WHERE user_id = (SELECT client_id FROM service_orders WHERE id = $1) AND title = 'المحامي قابل الشخص'`, [id]);
    assert.equal(noticed.length, 1);
  });

  it('الموكل مش بيكتب الكود', async () => {
    const { id, requestId } = await fieldOrder();
    assert.equal((await call('POST', `/field/orders/${id}/code`, clientToken, { code: await secretCode(requestId) })).status, 403);
  });

  it('تأكيد الموكل لوصول المحامي بيتسجل طريقة «الموكل»', async () => {
    const { id } = await fieldOrder();
    assert.equal((await call('POST', `/orders/${id}/confirm-arrival`, clientToken, {})).status, 400);
    await call('POST', `/orders/${id}/ask-arrival`, lawyerToken, {});
    assert.equal((await call('POST', `/orders/${id}/confirm-arrival`, clientToken, {})).status, 200);
    assert.equal((await listed(lawyerToken, id)).field.arrivalMethod, 'client');
  });
});

describe('الخدمات الميدانية: رفض الشخص وصورة الإثبات', () => {
  it('الشخص رفض بعد الوصول: الأتعاب للمحامي كاملة ومفيش رد للموكل', async () => {
    const { id, requestId } = await fieldOrder();
    const before = await clientBalance();
    assert.equal((await call('POST', `/field/orders/${id}/refused`, lawyerToken, {})).status, 409);

    await typeCode(id, await secretCode(requestId));
    assert.equal((await call('POST', `/field/orders/${id}/refused`, clientToken, {})).status, 403);
    assert.equal((await call('POST', `/field/orders/${id}/refused`, lawyerToken, {})).status, 200);

    const order = (await sql(`SELECT status, payout_status, payout_amount, lawyer_amount FROM service_orders WHERE id = $1`, [id]))[0];
    assert.equal(order.status, 'COMPLETED');
    assert.equal(order.payout_status, 'HELD');
    assert.equal(Number(order.payout_amount), Number(order.lawyer_amount));
    assert.equal(await clientBalance(), before);
    assert.equal((await wallet()).heldBalance, Number(order.lawyer_amount));
    assert.equal((await listed(clientToken, id)).field.refused, true);
    assert.equal((await call('POST', `/field/orders/${id}/refused`, lawyerToken, {})).status, 400);
    assert.equal((await sql(`SELECT 1 FROM lawyer_strikes WHERE lawyer_id = $1`, [lawyerId])).length, 0);
  });

  it('صورة الإثبات: المحامي يرفع، والإدارة بس تشوف', async () => {
    const { id } = await fieldOrder();
    assert.equal((await proofForm(clientToken, id, PNG)).statusCode, 403);
    assert.equal((await proofForm(lawyerToken, id, Buffer.from('not an image'))).statusCode, 400);
    const saved = await proofForm(lawyerToken, id, PNG);
    assert.equal(saved.statusCode, 201, saved.body);
    assert.equal(saved.json().data.proofs, 1);
    assert.equal((await listed(lawyerToken, id)).field.proofs, 1);
    assert.equal((await listed(clientToken, id)).field.proofs, 0);

    const proofs = (await call('GET', `/field/orders/${id}/proofs`, adminToken)).body.data;
    assert.equal(proofs.length, 1);
    const file = await app.inject({ method: 'GET', url: `/api/v1${proofs[0].url}`, headers: { authorization: `Bearer ${adminToken}` } });
    assert.equal(file.statusCode, 200);
    assert.equal(file.headers['content-type'], 'image/png');
    assert.equal((await call('GET', `/field/orders/${id}/proofs`, clientToken)).status, 403);
    assert.equal((await call('GET', proofs[0].url, lawyerToken)).status, 403);
  });

  it('خمس صور بالكتير للطلب', async () => {
    const { id } = await fieldOrder();
    for (let i = 0; i < 5; i++) assert.equal((await proofForm(lawyerToken, id, PNG)).statusCode, 201);
    assert.equal((await proofForm(lawyerToken, id, PNG)).statusCode, 409);
  });
});
