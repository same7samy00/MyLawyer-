import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, wallet } from './harness.js';
import { useRoadSeconds } from '../src/modules/requests/service.js';
import { useRoadSource } from '../src/services/roadRoutes.js';

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
    `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status, latitude, longitude, last_location_updated_at, last_active_at)
     VALUES ($1, 'أ. تاني', $2, 'approved'::lawyer_approval_status, TRUE, 'APPROVED', $3, 31.25, NOW(), NOW())`,
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

  it('المحامي اللي موبايله ساكت من أكتر من 5 دقايق ما يوصلوش الطلب', async () => {
    const quiet = await otherLawyer(30.051);
    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '6 minutes', last_active_at = NOW() - INTERVAL '6 minutes' WHERE user_id = $1`, [quiet.id]);
    const id = await createRequest();
    const sent = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id])).map((r: any) => r.lawyer_id);
    assert.equal(sent.includes(quiet.id), false);
    assert.equal(sent.includes(lawyerId), true);
    await removeLawyer(quiet.id);
  });

  it('النداء اللي فيه أقل من 10 بيكمّل العشرة من الدايرة الأوسع، ومش أبعد من 50 كم', async () => {
    const mid = await otherLawyer(30.05 + 0.15); // about 17 km: outside the first distance
    const outside = await otherLawyer(30.05 + 0.6); // about 67 km: never asked
    const id = await createRequest();
    const sent = (await sql('SELECT lawyer_id, round FROM request_recipients WHERE request_id = $1', [id]));
    assert.equal(sent.some((row: any) => row.lawyer_id === mid.id && row.round === 1), true, 'asked in the first call');
    assert.equal(sent.some((row: any) => row.lawyer_id === outside.id), false);
    await removeLawyer(mid.id);
    await removeLawyer(outside.id);
  });

  it('مع أكتر من 10 في المنطقة، العشرة هم الأقرب بوقت الطريق مش بالخط المستقيم', async () => {
    const others = [];
    for (let i = 1; i <= 11; i++) others.push(await otherLawyer(30.05 + i * 0.005));
    // The two nearest by straight line are across the river: an hour by road. Everyone else is five minutes away
    const slow = others[0];
    useRoadSeconds(async (from) => (from.lat > 30.0501 && from.lat < 30.0625 ? 3600 : 300));
    try {
      const id = await createRequest();
      const sent = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id])).map((r: any) => r.lawyer_id);
      assert.equal(sent.length, 10);
      assert.equal(sent.includes(slow.id) || sent.includes(others[1].id), false, 'near on the map, far by road');
      assert.equal(sent.includes(others[10].id), true, 'further on the map, near by road');
    } finally {
      useRoadSeconds(async () => null);
      for (const lawyer of others) await removeLawyer(lawyer.id);
    }
  });

  it('سؤال وقت الطريق بيتم وقاعدة البيانات مش مقفولة، في الطلب الجديد وفي النداء اللي بعده', async () => {
    const others = [];
    for (let i = 1; i <= 21; i++) others.push(await otherLawyer(30.05 + i * 0.002));
    // The tests have one database connection. A road answer asked for inside a transaction would wait for
    // that connection forever, so this read only finishes when nothing is locked
    let asked = 0;
    useRoadSeconds(async () => {
      asked++;
      await sql('SELECT 1');
      return 300;
    });
    try {
      const id = await createRequest();
      assert.ok(asked > 0, 'the road time was asked for the new request');
      assert.equal((await sql('SELECT 1 FROM request_recipients WHERE request_id = $1', [id])).length, 10);
      assert.equal((await sql(`SELECT 1 FROM notifications WHERE request_id = $1 AND title = 'طلب جديد'`, [id])).length, 10);

      asked = 0;
      await endRound(id);
      await sweepLifecycle();
      assert.ok(asked > 0, 'and again for the next call');
      const sent = await sql('SELECT round FROM request_recipients WHERE request_id = $1', [id]);
      assert.equal(sent.length, 20, 'ten new lawyers, nobody asked twice');
      assert.equal(sent.filter((row: any) => row.round === 2).length, 10);
    } finally {
      useRoadSeconds(async () => null);
      for (const lawyer of others) await removeLawyer(lawyer.id);
    }
  });

  it('بين اتنين قريبين من بعض، اللي بيرد على الطلبات يدخل الأول', async () => {
    const others = [];
    for (let i = 1; i <= 11; i++) others.push(await otherLawyer(30.05 + i * 0.005));
    // Everyone is the same time away. The last one answered every request this month, the first one never did
    useRoadSeconds(async () => 600);
    await setRange();
    for (let i = 0; i < 5; i++) {
      const old = await sql(
        `INSERT INTO service_requests (client_id, service_title, problem_description, client_latitude, client_longitude, min_price, max_price, commission_percent, tax_percent, round_deadline, status)
         VALUES ($1, 'محاميك حالاً', 'قديم', 30.05, 31.25, 500, 1500, 30, 0, NOW(), 'CANCELLED') RETURNING id`,
        [clientId]
      );
      for (const lawyer of [others[0], others[10]]) {
        await sql('INSERT INTO request_recipients (request_id, lawyer_id, round, distance_km) VALUES ($1, $2, 1, 1)', [old[0].id, lawyer.id]);
      }
      await sql('INSERT INTO request_offers (request_id, lawyer_id, price, lawyer_amount) VALUES ($1, $2, 1000, 700)', [old[0].id, others[10].id]);
    }
    try {
      const id = await createRequest();
      const sent = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [id])).map((r: any) => r.lawyer_id);
      assert.equal(sent.length, 10);
      assert.equal(sent.includes(others[10].id), true, 'always answers');
      assert.equal(sent.includes(others[0].id), false, 'never answers');
    } finally {
      useRoadSeconds(async () => null);
      for (const lawyer of others) await removeLawyer(lawyer.id);
    }
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

  it('اختيار العرض ما بيحجزش المحامي: اللي يدفع الأول ياخده، والتاني يرجع لنفس العروض من غير ما يتخصم منه حاجة', async () => {
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

  it('صفحة الطلبات بتعرض الطلب من أول لحظة بحالته، ولما يتختار محامي يظهر كطلب بدلها', async () => {
    const id = await createRequest();
    let mine = (await call('GET', '/requests', clientToken)).body.data;
    assert.equal(mine[0].id, id);
    assert.equal(mine[0].status, 'OPEN');
    assert.equal(mine[0].offers, 0);
    await offer(id, 1000);
    assert.equal((await call('GET', '/requests', clientToken)).body.data[0].offers, 1);
    assert.deepEqual((await call('GET', '/requests', lawyerToken)).body.data, []);

    const chosen = (await follow(id)).offers[0];
    const orderId = (await call('POST', `/requests/${id}/offers/${chosen.id}/select`, clientToken, {})).body.data.orderId;
    assert.deepEqual((await call('GET', '/requests', clientToken)).body.data, []);
    const order = (await call('GET', '/orders', clientToken)).body.data.find((o: any) => o.orderId === orderId);
    assert.equal(order.statusLabel, 'اخترت المحامي');
    assert.ok(order.paySecondsLeft > 590 && order.paySecondsLeft <= 600);

    // 10 minutes without paying: the request closes, and the order says why
    await sql(`UPDATE service_orders SET payment_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [orderId]);
    await sweepLifecycle();
    const closed = (await call('GET', '/orders', clientToken)).body.data.find((o: any) => o.orderId === orderId);
    assert.equal(closed.statusLabel, 'ما كمّلتش الدفع');
    assert.equal(closed.releaseReason, 'UNPAID');
    assert.equal((await follow(id)).status, 'EXPIRED');
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'الطلب اتلغى'`, [clientId])).length, 1);
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

  it('كارت العرض فيه وقت الطريق الحقيقي: من النداء لو اتحسب، وإلا بيتسأل مرة وقت إرسال السعر', async () => {
    // One lawyer around: nothing was asked at the call, so the offer asks once
    useRoadSource(async () => ({ distanceMeters: 9000, durationSeconds: 1500, trafficDelaySeconds: 0 }));
    try {
      const id = await createRequest();
      assert.equal((await sql('SELECT road_seconds FROM request_recipients WHERE request_id = $1', [id]))[0].road_seconds, null);
      await offer(id, 1000);
      assert.equal((await follow(id)).offers[0].minutesAway, 25);
    } finally {
      useRoadSource(null);
    }

    // Many lawyers around: the road time worked out for the call is the one shown
    await sql(`UPDATE service_requests SET status = 'CANCELLED' WHERE status = 'OPEN'`);
    const others = [];
    for (let i = 1; i <= 11; i++) others.push(await otherLawyer(30.05 + i * 0.002));
    useRoadSeconds(async () => 420);
    try {
      const id = await createRequest();
      const asked = (await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1 AND road_seconds = 420', [id])).map((row: any) => row.lawyer_id);
      assert.equal(asked.length, 10);
      const one = others.find((lawyer) => asked.includes(lawyer.id))!;
      await offer(id, 1000, one.token);
      assert.equal((await follow(id)).offers[0].minutesAway, 7);
    } finally {
      useRoadSeconds(async () => null);
      for (const lawyer of others) await removeLawyer(lawyer.id);
    }
  });

  it('موبايل الموكل والمحامي بيسألوا عن نفس الطريق: سؤال واحد بس بيطلع لشركة الخرايط', async () => {
    let asked = 0;
    useRoadSource(async () => {
      asked++;
      await new Promise((resolve) => setTimeout(resolve, 30));
      return { distanceMeters: 9000, durationSeconds: 900, trafficDelaySeconds: 60 };
    });
    try {
      // Both phones ask at the same moment, a few meters apart, then one asks again a little later
      const [lawyerAnswer, clientAnswer] = await Promise.all([
        call('GET', '/routes?fromLat=30.05&fromLon=31.25&toLat=29.96&toLon=31.26', lawyerToken),
        call('GET', '/routes?fromLat=30.0501&fromLon=31.2501&toLat=29.96&toLon=31.26', clientToken),
      ]);
      const later = await call('GET', '/routes?fromLat=30.0502&fromLon=31.25&toLat=29.96&toLon=31.26', clientToken);
      assert.equal(lawyerAnswer.body.data.durationSeconds, 900);
      assert.equal(clientAnswer.body.data.durationSeconds, 900);
      assert.equal(later.body.data.durationSeconds, 900);
      assert.equal(asked, 1);
    } finally {
      useRoadSource(null);
    }
  });
});

describe('حسابات مراجعة جوجل في «محاميك حالاً»', () => {
  it('طلب موكل حقيقي ما بيوصلش محامي المراجعة، وطلب موكل المراجعة ما بيوصلش غيره', async () => {
    const review = await otherLawyer(30.051);
    await sql('UPDATE users SET is_review_account = TRUE WHERE id = $1', [review.id]);
    try {
      const realRequest = await createRequest();
      const reached = await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [realRequest]);
      assert.ok(reached.some((row: any) => row.lawyer_id === lawyerId), 'a real lawyer still gets it');
      assert.ok(!reached.some((row: any) => row.lawyer_id === review.id), 'the review lawyer does not');
      assert.equal((await call('POST', `/requests/${realRequest}/cancel`, clientToken, {})).status, 200);

      const reviewClient = await createUser(`010009${phoneCounter++}`, 'client');
      await sql('UPDATE users SET is_review_account = TRUE WHERE id = $1', [reviewClient]);
      const reviewToken = app.jwt.sign({ userId: reviewClient, role: 'client' }) as string;
      const sent = await send(reviewToken);
      assert.equal(sent.status, 201, JSON.stringify(sent.body));
      const got = await sql('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [sent.body.data.id]);
      assert.deepEqual(got.map((row: any) => row.lawyer_id), [review.id]);
      await call('POST', `/requests/${sent.body.data.id}/cancel`, reviewToken, {});
      await sql('DELETE FROM service_requests WHERE client_id = $1', [reviewClient]);
      await sql('DELETE FROM users WHERE id = $1', [reviewClient]);
    } finally {
      await sql('DELETE FROM request_recipients WHERE lawyer_id = $1', [review.id]);
      await removeLawyer(review.id);
    }
  });
});
