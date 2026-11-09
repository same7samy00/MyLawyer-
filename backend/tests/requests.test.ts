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
  it('كل تغيير له رقم، والتطبيق يسأل عن اللي فاته بس', async () => {
    const start = (await call('GET', '/events/since', lawyerToken)).body.data;
    assert.equal(start.reset, true);
    await setRange();
    await send();
    const missed = (await call('GET', `/events/since?after=${start.last}`, lawyerToken)).body.data;
    assert.equal(missed.reset, false);
    assert.equal(missed.changes[0].kind, 'requests');
    assert.ok(missed.changes[0].entityId);
    assert.ok(missed.last > start.last);
  });

  it('طلب واحد بنفس شكل القائمة', async () => {
    await setRange();
    const list = (await call('GET', '/orders', clientToken)).body.data;
    const one = (await call('GET', `/orders?id=${list[0]?.orderId ?? '00000000-0000-0000-0000-000000000000'}`, clientToken)).body.data;
    assert.equal(one.length, list.length ? 1 : 0);
  });

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
    // Three one-minute calls: the lawyer has until all of them end
    assert.ok(incoming[0].secondsLeft > 170 && incoming[0].secondsLeft <= 180);
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

  it('طلب مفتوح واحد للموكل', async () => {
    const id = await createRequest();
    assert.equal((await send()).body.data.id, id);
  });

  it('مفيش محامين: الطلب ما يتعملش', async () => {
    await setRange();
    await sql('UPDATE lawyer_profiles SET is_available = FALSE');
    assert.equal((await send()).status, 409);
    assert.equal((await sql('SELECT 1 FROM service_requests')).length, 0);
  });

  it('3 نداءات كل دقيقة لـ 10 محامين، وبتكمل حتى لو فيه عروض، وبعدها من غير عروض يتقفل', async () => {
    const others = [];
    for (let i = 1; i <= 11; i++) others.push(await otherLawyer(30.05 + i * 0.005));
    const far = await otherLawyer(30.05 + 0.15); // about 17 km: outside the first call, inside the second
    const id = await createRequest();

    const firstRound = await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id]);
    assert.equal(firstRound.length, 10);
    assert.equal(firstRound.some((row: any) => row.lawyer_id === others[10].id || row.lawyer_id === far.id), false);
    const client = await follow(id);
    assert.ok(client.secondsLeft > 170 && client.secondsLeft <= 180, 'the app keeps searching for all three calls');

    // An offer does not stop the next call
    assert.equal((await offer(id, 1000)).status, 201);
    await endRound(id);
    await sweepLifecycle();
    assert.equal((await follow(id)).round, 2);
    const second = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1 AND round = 2', [id])).map((r: any) => r.lawyer_id);
    assert.equal(second.includes(others[10].id) && second.includes(far.id), true);
    assert.equal(second.some((lawyer: string) => firstRound.some((row: any) => row.lawyer_id === lawyer)), false, 'nobody is asked twice');
    // A lawyer from the first call can still send a price after his minute
    assert.equal((await offer(id, 900, others[0].token)).status, 201);

    // Nobody new is left inside 50 km: the calls end and the client chooses within 5 minutes
    await endRound(id);
    await sweepLifecycle();
    const open = await follow(id);
    assert.equal(open.status, 'OPEN');
    assert.equal(open.secondsLeft, 0);
    assert.ok(open.chooseSecondsLeft > 290 && open.chooseSecondsLeft <= 300);
    assert.equal((await sql('SELECT 1 FROM request_recipients WHERE request_id = $1', [id])).length, 10 + second.length);
    for (const lawyer of [...others, far]) await removeLawyer(lawyer.id);
  });

  it('من غير ولا عرض بعد النداءات الطلب يتقفل', async () => {
    const id = await createRequest();
    for (let i = 0; i < 3 && (await follow(id)).status === 'OPEN'; i++) {
      await endRound(id);
      await sweepLifecycle();
    }
    assert.equal((await follow(id)).status, 'NO_OFFERS');
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'محدش بعت عرض'`, [clientId])).length, 1);
  });

  it('بعد ما الطلب يتقفل من غير عروض، «بحث جديد» في التطبيق بيبعت طلب جديد للأقرب', async () => {
    const id = await createRequest();
    for (let i = 0; i < 3 && (await follow(id)).status === 'OPEN'; i++) {
      await endRound(id);
      await sweepLifecycle();
    }
    assert.equal((await follow(id)).status, 'NO_OFFERS');
    assert.equal((await call('POST', `/requests/${id}/search`, clientToken, {})).status, 409);
    const again = await send();
    assert.equal(again.status, 201, JSON.stringify(again.body));
    const sent = await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [again.body.data.id]);
    assert.equal(sent.some((row: any) => row.lawyer_id === lawyerId), true);
    await call('POST', `/requests/${again.body.data.id}/cancel`, clientToken, {});
  });

  it('«بحث جديد» بيبعت للـ 10 اللي ما وصلهمش، ولو مفيش حد جديد يرجع للأقرب، والعروض اللي وصلت بتفضل', async () => {
    const others = [];
    for (let i = 1; i <= 11; i++) others.push(await otherLawyer(30.05 + i * 0.005));
    const id = await createRequest();
    const nearest = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1 AND round = 1', [id])).map((r: any) => r.lawyer_id);
    assert.equal(nearest.length, 10);
    assert.equal((await offer(id, 1000)).status, 201);

    const search = () => call('POST', `/requests/${id}/search`, clientToken, {});
    assert.equal((await search()).body.data.round, 2);
    const second = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1 AND round = 2', [id])).map((r: any) => r.lawyer_id);
    // The main lawyer already sent a price, so the second group starts after the other nearest ones
    assert.equal(second.includes(others[10].id), true);
    assert.equal(second.includes(lawyerId), false);

    // Nobody new is left, so the nearest who did not send a price are asked again
    assert.equal((await search()).body.data.round, 3);
    const third = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1 AND round = 3', [id])).map((r: any) => r.lawyer_id);
    assert.equal(third.includes(others[0].id), true, 'back to the nearest');
    assert.equal((await follow(id)).offers.length, 1, 'the price already sent stays');

    assert.equal((await call('POST', `/requests/${id}/search`, lawyerToken, {})).status, 404);
    for (const lawyer of others) await removeLawyer(lawyer.id);
  });

  it('المحامي اللي على بعد أكتر من 50 كم ما يوصلوش الطلب', async () => {
    const far = await otherLawyer(30.05 + 0.6);
    const id = await createRequest();
    const sent = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id])).map((r: any) => r.lawyer_id);
    assert.equal(sent.includes(far.id), false);
    await removeLawyer(far.id);
  });

  it('لو فيه عرض بعد النداءات، وبعد 5 دقايق من غير اختيار الطلب يتلغي ويتبلغ الطرفين', async () => {
    const id = await createRequest();
    await offer(id, 1000);
    for (let i = 0; i < 3 && (await follow(id)).secondsLeft > 0; i++) {
      await endRound(id);
      await sweepLifecycle();
    }
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

  it('اختيار العرض ما بيحجزش المحامي ومفيش مهلة دفع: اللي يدفع الأول ياخده، والتاني يرجع لنفس العروض من غير ما يتخصم منه حاجة', async () => {
    const other = await otherLawyer();
    const firstId = await createRequest();
    await offer(firstId, 1000);
    await offer(firstId, 900, other.token);

    const secondClient = await createUser('01000000888', 'client');
    const secondToken = app.jwt.sign({ userId: secondClient, role: 'client' }) as string;
    const secondId = (await send(secondToken)).body.data.id;
    // The lawyer chosen by the first client still receives and prices other requests
    assert.equal((await offer(secondId, 1100)).status, 201);

    const pick = async (requestId: string, token: string) => {
      const offers = (await call('GET', `/requests/${requestId}`, token)).body.data.offers;
      const mine = offers.find((item: any) => item.lawyerId === lawyerId);
      return (await call('POST', `/requests/${requestId}/offers/${mine.id}/select`, token, {})).body.data.orderId as string;
    };
    const firstOrder = await pick(firstId, clientToken);
    const secondOrder = await pick(secondId, secondToken);
    assert.ok((await sql(`SELECT payment_deadline > NOW() + INTERVAL '23 hours' AS far FROM service_orders WHERE id = $1`, [firstOrder]))[0].far, 'no short time to pay');

    // The second client pays first and gets the lawyer; the first goes back to the same offers, minus that lawyer
    assert.equal((await call('POST', `/orders/${secondOrder}/confirm-payment`, secondToken, {})).status, 200);
    const back = await follow(firstId);
    assert.equal(back.status, 'OPEN');
    assert.deepEqual(back.offers.map((item: any) => item.lawyerId), [other.id]);
    assert.ok(back.chooseSecondsLeft > 280);
    assert.equal((await call('POST', `/orders/${firstOrder}/confirm-payment`, clientToken, {})).status, 409);
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'المحامي اتشغل'`, [clientId])).length, 1);
    assert.equal((await sql('SELECT 1 FROM payments WHERE order_id = $1', [firstOrder])).length, 0, 'nothing charged');
    await removeLawyer(other.id);
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

describe('الطريق ووقت الوصول', () => {
  it('محتاج تسجيل دخول، والمكان لازم يكون في مصر، ومن غير TomTom يرد إن الحساب مش متاح', async () => {
    const q = 'fromLat=30.05&fromLon=31.25&toLat=29.96&toLon=31.26';
    assert.equal((await app.inject({ method: 'GET', url: `/api/v1/routes?${q}` })).statusCode, 401);
    assert.equal((await call('GET', '/routes?fromLat=10&fromLon=31.25&toLat=29.96&toLon=31.26', clientToken)).status, 400);
    // Tests never call TomTom
    assert.equal((await call('GET', `/routes?${q}`, clientToken)).status, 503);
  });
});
