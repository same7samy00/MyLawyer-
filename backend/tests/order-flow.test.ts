import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, createOrder, closeOrders, createPaidOrder, createArrivedOrder, openTicket, wallet, clientBalance } from './harness.js';
import { arrivalMargin } from '../src/modules/lifecycle/service.js';
import { LAWYER_CAN_WORK } from '../src/modules/requests/service.js';
const canWork = async (id: string) => (await sql(`SELECT 1 FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id WHERE lp.user_id = $1 AND ${LAWYER_CAN_WORK('lp', 'u')}`, [id])).length > 0;

describe('الدفع والإنهاء بعد الالتقاء', () => {
  it('لا إنهاء لطلب لم يُدفع', async () => {
    const order = await createOrder();
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 400);
  });

  it('الوصول بيتسجل في حدود 50 متر بس، والإنهاء بعده من غير كود', async () => {
    const order = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 409);

    // About 110 meters away is too far
    const far = await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.051, longitude: 31.25 });
    assert.equal(far.status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 409);

    assert.equal((await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 })).status, 200);
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 200);
    assert.equal((await wallet()).heldBalance, 350);
  });

  it('الطلب مش بيرجع كود لأي حد', async () => {
    const order = await createPaidOrder();
    const list = await call('GET', '/orders', clientToken);
    assert.equal(list.body.data[0].completionCode, undefined);
    assert.equal((await call('GET', `/orders/${order.id}`, lawyerToken)).body.data.order.completion_code, undefined);
  });

  it('الإلغاء بعد الدفع للموكل فقط في أول 5 دقايق، والمبلغ يرجع كامل', async () => {
    const order = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${order.id}/cancel`, lawyerToken, {})).status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/cancel`, clientToken, {})).status, 200);
    assert.equal(await clientBalance(), 350);

    const late = await createPaidOrder();
    await sql(`UPDATE service_orders SET paid_at = NOW() - INTERVAL '6 minutes' WHERE id = $1`, [late.id]);
    assert.equal((await call('POST', `/orders/${late.id}/cancel`, clientToken, {})).status, 400);
  });

  it('بعد الوصول الإلغاء ممنوع', async () => {
    const order = await createArrivedOrder();
    assert.equal((await call('POST', `/orders/${order.id}/cancel`, clientToken, {})).status, 400);
  });
});

describe('مهلة المهمة', () => {
  it('كل طلب ليه سطر إشعار واحد، والجديد يحل محل القديم', async () => {
    const order = await createArrivedOrder();
    await call('POST', `/orders/${order.id}/complete`, lawyerToken, {});
    const rows = await sql(`SELECT title FROM notifications WHERE user_id = $1 AND order_id = $2`, [clientId, order.id]);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].title, 'انتهت المهمة');
  });

  it('المهلة خلصت والمحامي ما وصلش: الفلوس ترجع للموكل لوحدها', async () => {
    const order = await createPaidOrder();
    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    await sweepLifecycle();

    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'REFUNDED');
    assert.equal(await clientBalance(), 350);
    assert.equal((await wallet()).availableBalance, 0);
  });

  it('المحامي وصل وما أنهاش: الفلوس تفضل محجوزة ومش بتتحرك لوحدها', async () => {
    const order = await createArrivedOrder();
    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '40 days' WHERE id = $1`, [order.id]);
    await sweepLifecycle();

    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'ACTIVE');
    assert.equal(await clientBalance(), 0);
    assert.equal((await wallet()).availableBalance, 0);
  });
});

describe('تأخر المحامي عن الوصول', () => {
  const passDeadline = (id: string) =>
    sql(`UPDATE service_orders SET arrival_deadline = NOW() - INTERVAL '1 minute', paid_at = NOW() - INTERVAL '1 hour' WHERE id = $1`, [id]);

  it('مهلة الوصول بتتحسب عند الدفع: وقت الطريق وهامش على قده', async () => {
    const order = await createPaidOrder();
    // Same spot in the test, so the road is about zero and the margin is the short one
    const rows = await sql(`SELECT arrival_deadline > NOW() + INTERVAL '9 minutes' AND arrival_deadline < NOW() + INTERVAL '12 minutes' AS ok FROM service_orders WHERE id = $1`, [order.id]);
    assert.equal(rows[0].ok, true);
    assert.deepEqual([10, 20, 21, 60, 61, 90].map(arrivalMargin), [10, 10, 15, 15, 20, 20]);
  });

  it('المحامي يوصله تذكير قبل نهاية المهلة بـ 5 دقايق مرة واحدة', async () => {
    const order = await createPaidOrder();
    await sql(`UPDATE service_orders SET arrival_deadline = NOW() + INTERVAL '4 minutes' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    await sweepLifecycle();
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'مهلة الوصول قربت تخلص'`, [lawyerId])).length, 1);
  });

  it('بعد المهلة الموكل يتسأل مرة واحدة، ويقدر يلغي وفلوسه ترجع فورًا', async () => {
    const order = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${order.id}/keep-waiting`, clientToken, {})).status, 400);
    await passDeadline(order.id);
    await sweepLifecycle();
    await sweepLifecycle();
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'المحامي اتأخر'`, [clientId])).length, 1);

    assert.equal((await call('POST', `/orders/${order.id}/cancel`, clientToken, {})).status, 200);
    assert.equal(await clientBalance(), 350);
  });

  it('الموكل ما ردش: الفلوس ترجع بعد 5 دقايق', async () => {
    const order = await createPaidOrder();
    await passDeadline(order.id);
    await sweepLifecycle();
    assert.equal(await clientBalance(), 0);

    await sql(`UPDATE service_orders SET delay_notified_at = NOW() - INTERVAL '6 minutes' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'REFUNDED');
    assert.equal(await clientBalance(), 350);
  });

  it('الموكل اختار يستنى: مفيش رد بعد 5 دقايق، والرد عند 24 ساعة من الدفع', async () => {
    const order = await createPaidOrder();
    await passDeadline(order.id);
    await sweepLifecycle();
    assert.equal((await call('POST', `/orders/${order.id}/keep-waiting`, clientToken, {})).status, 200);

    await sql(`UPDATE service_orders SET delay_notified_at = NOW() - INTERVAL '3 hours' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal(await clientBalance(), 0);

    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal(await clientBalance(), 350);
  });

  it('الوصول بعد المهلة مقبول طول ما الطلب مفتوح، وبعده الإلغاء ممنوع', async () => {
    const order = await createPaidOrder();
    await passDeadline(order.id);
    await sweepLifecycle();
    assert.equal((await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 })).status, 200);
    assert.equal((await call('POST', `/orders/${order.id}/cancel`, clientToken, {})).status, 400);
  });

  it('التذكرة المفتوحة توقف الرد التلقائي والإلغاء المتأخر', async () => {
    const order = await createPaidOrder();
    await openTicket(clientToken, order.id);
    await passDeadline(order.id);
    await sweepLifecycle();
    await sql(`UPDATE service_orders SET delay_notified_at = NOW() - INTERVAL '3 hours' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal(await clientBalance(), 0);
    assert.equal((await call('POST', `/orders/${order.id}/cancel`, clientToken, {})).status, 409);
  });
});

describe('تأجيل المهمة', () => {
  const postpone = (id: string, token = lawyerToken) => call('POST', `/orders/${id}/postpone`, token, {});

  it('التأجيل بعد «وصلت» بس، ومن غير سبب ولا ميعاد', async () => {
    const paid = await createPaidOrder();
    assert.equal((await postpone(paid.id)).status, 400);
    await closeOrders();

    const order = await createArrivedOrder();
    assert.equal((await postpone(order.id, clientToken)).status, 404);
    assert.equal((await postpone(order.id)).status, 200);
    assert.equal((await postpone(order.id)).status, 409, 'already postponed');
    await closeOrders();
  });

  it('مهمة مؤجلة واحدة بس للمحامي، والمؤجلة بتتنهي على طول من غير «إلغاء التأجيل»', async () => {
    const first = await createArrivedOrder();
    assert.equal((await postpone(first.id)).status, 200);

    // The lawyer is free while the first task waits, takes a second one, and can't postpone it too
    const second = await createArrivedOrder();
    const refused = await postpone(second.id);
    assert.equal(refused.status, 409);
    assert.equal(refused.body.error, 'عندك مهمة مؤجلة تانية، أنهيها الأول');

    // The postponed task finishes straight away, and then the second one may be postponed
    assert.equal((await call('POST', `/orders/${first.id}/complete`, lawyerToken, {})).status, 200);
    assert.equal((await postpone(second.id)).status, 200);

    assert.equal((await call('POST', `/orders/${second.id}/resume`, lawyerToken, {})).status, 404, 'no resume route');
    await closeOrders();
  });

  it('المؤجل يفضل محجوز، ويكمل بـ «إنهاء»، والمحامي يقدر يستقبل طلبات', async () => {
    const order = await createArrivedOrder();
    assert.equal((await postpone(order.id)).status, 200);

    const listed = (await call('GET', '/orders', clientToken)).body.data[0];
    assert.ok(listed.postponedAt);
    assert.equal(listed.postponedReason, null);
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'المحامي أجّل المهمة'`, [clientId])).length, 1);

    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '40 days' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'ACTIVE');

    // A postponed task leaves the lawyer free for new requests
    assert.equal(await canWork(lawyerId), true);

    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 200);
    assert.equal((await wallet()).heldBalance, 350);
  });
});

describe('المهل والمخالفات', () => {
  it('مفيش مهلة دفع، والاختيار اللي يفضل يوم من غير دفع بيتشال والموكل يرجع لعروضه', async () => {
    const order = await createOrder();
    assert.ok((await sql(`SELECT payment_deadline > NOW() + INTERVAL '23 hours' AS far FROM service_orders WHERE id = $1`, [order.id]))[0].far);
    await sql(`UPDATE service_orders SET payment_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'PAYMENT_EXPIRED');
    assert.equal((await sql('SELECT status FROM service_requests WHERE order_id IS NULL ORDER BY created_at DESC LIMIT 1'))[0].status, 'OPEN');
  });

  it('طلب مفتوح واحد للموكل، ومهمة واحدة للمحامي', async () => {
    const order = await createOrder();
    assert.equal(await canWork(lawyerId), true, 'choosing does not hold the lawyer');
    assert.equal((await call('POST', '/requests', clientToken, { problemType: PROBLEM, problemDescription: 'وصف', clientLat: 30.05, clientLon: 31.25 })).status, 409);
    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {})).status, 200);
    assert.equal(await canWork(lawyerId), false, 'one paid task holds the lawyer');
  });

  it('اعتذار المحامي بعد الدفع يرجع المبلغ، و3 اعتذارات توقفه أسبوع', async () => {
    for (let i = 0; i < 3; i++) {
      const order = await createPaidOrder();
      assert.equal((await call('POST', `/orders/${order.id}/withdraw`, lawyerToken, {})).status, 200);
    }

    assert.equal(await clientBalance(), 1050);
    const rows = await sql('SELECT suspended_until FROM lawyer_profiles WHERE user_id = $1', [lawyerId]);
    assert.ok(rows[0].suspended_until);
    assert.equal((await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: true })).status, 403);
  });

  it('الموكل يدفع من رصيده لو كفاية', async () => {
    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 350, 'اختبار')`, [clientId]);
    const order = await createOrder();

    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, { method: 'wallet' })).status, 200);
    assert.equal(await clientBalance(), 0);
  });

  it('الرصيد غير الكافي يرفض الدفع', async () => {
    const order = await createOrder();
    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, { method: 'wallet' })).status, 400);
  });

  it('رقم كل طرف يظهر بعد الدفع بس', async () => {
    const order = await createOrder();
    assert.equal((await call('GET', '/orders', lawyerToken)).body.data[0].clientPhone, null);
    assert.equal((await call('GET', '/orders', clientToken)).body.data[0].lawyerPhone, null);

    await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
    assert.equal((await call('GET', '/orders', lawyerToken)).body.data[0].clientPhone, '01000000001');
  });

  it('3 إنذارات في شهر توقف الحساب أسبوع، وإلغاء إنذار يقلل العدد', async () => {
    for (let i = 0; i < 2; i++) {
      assert.equal((await call('POST', `/admin/users/${clientId}/warnings`, adminToken, { reason: 'تعامل غير لائق' })).status, 200);
    }
    const warnings = (await call('GET', `/admin/users/${clientId}`, adminToken)).body.data.warnings;
    assert.equal(warnings.length, 2);
    assert.equal((await call('POST', `/admin/warnings/${warnings[0].id}/revoke`, adminToken, {})).status, 200);

    for (let i = 0; i < 2; i++) await call('POST', `/admin/users/${clientId}/warnings`, adminToken, { reason: 'تعامل غير لائق' });
    const user = (await sql('SELECT status, suspended_until FROM users WHERE id = $1', [clientId]))[0];
    assert.equal(user.status, 'suspended');
    assert.notEqual(user.suspended_until, null);

    await sql(`UPDATE users SET suspended_until = NOW() - INTERVAL '1 minute' WHERE id = $1`, [clientId]);
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM users WHERE id = $1', [clientId]))[0].status, 'active');
  });

});

describe('خصوصية الموقع قبل الدفع', () => {
  const orderOf = async (token: string, id: string) =>
    (await call('GET', '/orders', token)).body.data.find((o: any) => o.orderId === id);

  it('كل طرف يشوف مكان تقريبي ومن غير عنوان لحد الدفع', async () => {
    const order = await createOrder({ clientLat: 30.05678, clientLon: 31.25678, clientAddress: 'أبو صير بنا، محافظة الغربية' });
    await sql(`UPDATE service_orders SET lawyer_latitude = 30.04321, lawyer_longitude = 31.24321 WHERE id = $1`, [order.id]);

    const forLawyer = await orderOf(lawyerToken, order.id);
    assert.notEqual(forLawyer.clientLatitude, 30.05678);
    assert.equal(forLawyer.clientAddress, 'محافظة الغربية');

    const forClient = await orderOf(clientToken, order.id);
    assert.equal(forClient.clientLatitude, 30.05678);
    assert.notEqual(forClient.lawyerLatitude, 30.04321);

    const single = await call('GET', `/orders/${order.id}`, lawyerToken);
    assert.notEqual(Number(single.body.data.order.client_latitude), 30.05678);
    assert.equal(single.body.data.order.client_address, 'محافظة الغربية');
    assert.equal((await orderOf(lawyerToken, order.id)).clientAddress, 'محافظة الغربية');

    await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
    const paid = await orderOf(lawyerToken, order.id);
    assert.equal(paid.clientLatitude, 30.05678);
    assert.equal(paid.clientAddress, 'أبو صير بنا، محافظة الغربية');
    assert.equal((await orderOf(clientToken, order.id)).lawyerLatitude, 30.04321);
  });

});

describe('ترقيم ML الموحد', () => {
  it('الطلب والتذكرة والتحويل ياخدوا أرقام ML متسلسلة', async () => {
    const first = await createOrder();
    const number = (await sql('SELECT order_number FROM service_orders WHERE id = $1', [first.id]))[0].order_number;
    await closeOrders();
    assert.match(number, /^ML-ORD-\d{6}$/);

    const order = await createArrivedOrder();
    const ticket = await openTicket(clientToken, order.id, 'ORDER');
    assert.match(ticket.body.data.reference, /^ML-TKT-\d{6}$/);
    assert.ok(ticket.body.message.includes(ticket.body.data.reference));

    const listed = await call('GET', '/admin/support?role=client', adminToken);
    assert.equal(listed.body.data[0].reference, ticket.body.data.reference);

    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 500, 'شحن تجريبي')`, [clientId]);
    const transfer = await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 100 });
    assert.match(transfer.body.data.reference, /^ML-TRF-\d{6}$/);
  });
});

describe('مخالفات المحامي', () => {
  it('المحامي يعرف من أول مخالفة، والإدارة تلغيها فتفضل متسجلة وتترفع الإيقاف', async () => {
    for (let i = 0; i < 3; i++) {
      const order = await createPaidOrder();
      await call('POST', `/orders/${order.id}/withdraw`, lawyerToken, {});
      if (i === 0) assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'اتسجلت عليك مخالفة'`, [lawyerId])).length, 1);
    }
    assert.ok((await sql('SELECT suspended_until FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].suspended_until);

    const profile = (await call('GET', `/admin/users/${lawyerId}`, adminToken)).body.data;
    assert.equal(profile.strikes.length, 3);
    assert.equal((await call('POST', `/admin/strikes/${profile.strikes[0].id}/revoke`, adminToken, {})).status, 200);
    assert.equal((await call('POST', `/admin/strikes/${profile.strikes[0].id}/revoke`, adminToken, {})).status, 404);

    assert.equal((await sql('SELECT suspended_until FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].suspended_until, null);
    const after = (await call('GET', `/admin/users/${lawyerId}`, adminToken)).body.data.strikes;
    assert.equal(after.length, 3);
    assert.equal(after.filter((item: any) => item.revoked_at).length, 1);
    await sql('DELETE FROM lawyer_strikes');
  });
});
