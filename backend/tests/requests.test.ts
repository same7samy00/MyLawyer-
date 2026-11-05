import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, wallet } from './harness.js';

const setRange = () => sql(`UPDATE problem_prices SET min_price = 500, max_price = 1500, commission_percent = 30`);

const send = (token = clientToken) => call('POST', '/requests', token, {
  problemType: PROBLEM, problemDescription: 'وصف المشكلة', clientLat: 30.05, clientLon: 31.25, clientAddress: 'المعادي، محافظة القاهرة',
});

async function createRequest() {
  await setRange();
  const res = await send();
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data.id as string;
}

const offer = (id: string, price: number, token = lawyerToken) => call('POST', `/requests/${id}/offer`, token, { price });
const follow = async (id: string) => (await call('GET', `/requests/${id}`, clientToken)).body.data;
const endRound = (id: string) => sql(`UPDATE service_requests SET round_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [id]);

let phoneCounter = 500;
async function otherLawyer(lat = 30.06) {
  const id = await createUser(`010000${phoneCounter++}`, 'lawyer');
  await sql(
    `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status, latitude, longitude)
     VALUES ($1, 'أ. تاني', $2, 'approved'::lawyer_approval_status, TRUE, 'APPROVED', $3, 31.25)`,
    [id, `S${phoneCounter}`, lat]
  );
  return { id, token: app.jwt.sign({ userId: id, role: 'lawyer' }) as string };
}
const removeLawyer = (id: string) => sql('DELETE FROM users WHERE id = $1', [id]);

describe('الخط المفتوح', () => {
  it('الخط محتاج تسجيل دخول', async () => {
    assert.equal((await app.inject({ method: 'GET', url: '/api/v1/events' })).statusCode, 401);
  });
});

describe('الطلب وعروض الأسعار', () => {
  it('الاستقبال للحالي بس: المختار لحد الدفع، واللي ما اتختارش يختفي', async () => {
    const other = await otherLawyer();
    const id = await createRequest();
    await offer(id, 1000);
    await offer(id, 900, other.token);
    const card = async (token: string) => (await call('GET', '/requests/incoming', token)).body.data[0];
    assert.equal((await card(lawyerToken)).state, 'OPEN');

    const offers = (await follow(id)).offers;
    const mine = offers.find((item: any) => item.lawyerId === lawyerId);
    const selected = await call('POST', `/requests/${id}/offers/${mine.id}/select`, clientToken, {});

    const chosen = await card(lawyerToken);
    assert.equal(chosen.state, 'CHOSEN');
    assert.equal(chosen.orderId, selected.body.data.orderId);
    assert.equal(await card(other.token), undefined);

    await call('POST', `/orders/${selected.body.data.orderId}/confirm-payment`, clientToken, {});
    assert.equal(await card(lawyerToken), undefined);
    await removeLawyer(other.id);
  });

  it('الموكل يشوف الحدود، والطلب يوصل المحامي بصافيه من غير تفاصيل المكان', async () => {
    await setRange();
    const range = await call('GET', `/requests/range?problemType=${encodeURIComponent(PROBLEM)}`, clientToken);
    assert.deepEqual(range.body.data, { minPrice: 500, maxPrice: 1500 });

    const id = await createRequest();
    const incoming = (await call('GET', '/requests/incoming', lawyerToken)).body.data;
    assert.equal(incoming[0].id, id);
    assert.equal(incoming[0].minPrice, 500);
    assert.equal(incoming[0].netRate, 0.7);
    assert.equal(incoming[0].area, 'المعادي، محافظة القاهرة');
    assert.equal(incoming[0].service, 'محاميك حالاً');
    assert.equal(incoming[0].client_latitude, undefined);
    assert.ok(incoming[0].secondsLeft > 110);
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'طلب جديد'`, [lawyerId])).length, 1);
  });

  it('السعر لازم يكون جوه الحدود، وعرض واحد لكل محامي، ويقدر يسحبه', async () => {
    const id = await createRequest();
    assert.equal((await offer(id, 499)).status, 400);
    assert.equal((await offer(id, 1501)).status, 400);
    assert.equal((await offer(id, 700.5)).status, 400);
    assert.equal((await offer(id, 1000)).status, 201);
    assert.equal((await offer(id, 900)).status, 409);
    assert.equal((await follow(id)).offers[0].price, 1000);

    assert.equal((await call('POST', `/requests/${id}/offer/withdraw`, lawyerToken, {})).status, 200);
    assert.equal((await follow(id)).offers.length, 0);
    assert.equal((await offer(id, 900)).status, 201);
  });

  it('محامي ما وصلهوش الطلب ما يقدرش يبعت عرض', async () => {
    const id = await createRequest();
    const late = await otherLawyer();
    assert.equal((await offer(id, 1000, late.token)).status, 404);
    await removeLawyer(late.id);
  });

  it('اختيار العرض يعمل طلب بسعر المحامي والعمولة منه، والدورة تكمل بالدفع', async () => {
    const id = await createRequest();
    await offer(id, 1000);
    const offerId = (await follow(id)).offers[0].id;

    const selected = await call('POST', `/requests/${id}/offers/${offerId}/select`, clientToken, {});
    assert.equal(selected.status, 200, JSON.stringify(selected.body));
    const orderId = selected.body.data.orderId;

    const order = (await sql('SELECT * FROM service_orders WHERE id = $1', [orderId]))[0];
    assert.equal(order.status, 'ACCEPTED');
    assert.equal(Number(order.price), 1000);
    assert.equal(Number(order.lawyer_amount), 700);
    assert.equal(order.lawyer_id, lawyerId);

    assert.equal((await call('POST', `/requests/${id}/offers/${offerId}/select`, clientToken, {})).status, 409);
    assert.equal((await call('POST', `/orders/${orderId}/confirm-payment`, clientToken, {})).status, 200);
    assert.equal((await call('POST', `/orders/${orderId}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 })).status, 200);
    assert.equal((await call('POST', `/orders/${orderId}/complete`, lawyerToken, {})).status, 200);
    assert.equal((await wallet()).heldBalance, 700);

    const admin = await call('GET', `/admin/orders/${orderId}`, adminToken);
    assert.equal(admin.body.data.offers.length, 1);
  });

  it('المحامي اللي أخد مهمة تانية عرضه يختفي وما ينفعش يتختار', async () => {
    const id = await createRequest();
    await offer(id, 1000);
    const offerId = (await follow(id)).offers[0].id;
    await sql(`UPDATE lawyer_profiles SET is_available = FALSE WHERE user_id = $1`, [lawyerId]);

    assert.equal((await follow(id)).offers.length, 0);
    assert.equal((await call('POST', `/requests/${id}/offers/${offerId}/select`, clientToken, {})).status, 409);
  });

  it('طلب مفتوح واحد للموكل، والطلب القديم يمنع المسار القديم', async () => {
    const id = await createRequest();
    assert.equal((await send()).body.data.id, id);
    const old = await call('POST', '/orders', clientToken, { lawyerId, problemType: PROBLEM, problemDescription: 'وصف', clientLat: 30.05, clientLon: 31.25 });
    assert.equal(old.status, 409);
  });

  it('مفيش محامين: الطلب ما يتعملش', async () => {
    await setRange();
    await sql('UPDATE lawyer_profiles SET is_available = FALSE');
    assert.equal((await send()).status, 409);
    assert.equal((await sql('SELECT 1 FROM service_requests')).length, 0);
  });

  it('أقرب 5 بس، ولو محدش بعت عرض يروح للي بعدهم، وبعد 3 محاولات يتقفل', async () => {
    const others = [];
    for (let i = 1; i <= 5; i++) others.push(await otherLawyer(30.05 + i * 0.01));
    const id = await createRequest();

    const firstRound = await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id]);
    assert.equal(firstRound.length, 5);
    const farthest = others[4];
    assert.equal(firstRound.some((row: any) => row.lawyer_id === farthest.id), false);

    await endRound(id);
    await sweepLifecycle();
    assert.equal((await follow(id)).round, 2);
    assert.equal((await sql('SELECT round FROM request_recipients WHERE request_id = $1 AND lawyer_id = $2', [id, farthest.id]))[0].round, 2);

    await endRound(id);
    await sweepLifecycle();
    assert.equal((await follow(id)).status, 'NO_OFFERS');
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'مفيش محامي متاح'`, [clientId])).length, 1);
    for (const lawyer of others) await removeLawyer(lawyer.id);
  });

  it('لو فيه عرض الجولة ما تتغيرش، وبعد 5 دقايق من غير اختيار الطلب يتلغي ويتبلغ الطرفين', async () => {
    const id = await createRequest();
    await offer(id, 1000);
    await endRound(id);
    await sweepLifecycle();
    const open = await follow(id);
    assert.equal(open.status, 'OPEN');
    assert.equal(open.offers.length, 1);
    assert.ok(open.chooseSecondsLeft > 200 && open.chooseSecondsLeft <= 300);

    await sql(`UPDATE service_requests SET round_deadline = NOW() - INTERVAL '6 minutes' WHERE id = $1`, [id]);
    await sweepLifecycle();
    assert.equal((await follow(id)).status, 'EXPIRED');
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'الطلب اتلغى'`, [clientId])).length, 1);
    // The lawyer's card just disappears, with no extra notification
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'الطلب اتقفل'`, [lawyerId])).length, 0);
  });

  it('الإلغاء يقفل الطلب، وغير صاحبه ما يشوفوش', async () => {
    const id = await createRequest();
    const stranger = app.jwt.sign({ userId: await createUser('01000000777', 'client'), role: 'client' });
    assert.equal((await call('GET', `/requests/${id}`, stranger)).status, 404);
    await call('POST', `/requests/${id}/cancel`, stranger, {});
    assert.equal((await follow(id)).status, 'OPEN');

    await call('POST', `/requests/${id}/cancel`, clientToken, {});
    assert.equal((await follow(id)).status, 'CANCELLED');
    assert.equal((await offer(id, 1000)).status, 409);
    assert.equal((await call('GET', '/requests/incoming', lawyerToken)).body.data.length, 0);
  });
});
