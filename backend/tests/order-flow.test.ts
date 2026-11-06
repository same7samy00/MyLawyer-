import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, createOrder, closeOrders, createPaidOrder, createArrivedOrder, openTicket, wallet, clientBalance } from './harness.js';

describe('مهلة رد المحامي', () => {
  it('الخادم يرسل الثواني الباقية للطرفين', async () => {
    const order = await createOrder() as { id: string; responseSecondsLeft?: number };
    assert.ok(order.responseSecondsLeft! > 110 && order.responseSecondsLeft! <= 120);

    const list = await call('GET', '/orders', lawyerToken);
    const left = list.body.data.find((o: any) => o.orderId === order.id).responseSecondsLeft;
    assert.ok(left > 110 && left <= 120);

    const single = await call('GET', `/orders/${order.id}`, clientToken);
    assert.ok(single.body.data.order.responseSecondsLeft > 110);
  });

  it('انتهاء المهلة يقفل الطلب ويبلغ الموكل', async () => {
    const order = await createOrder();
    await sql(`UPDATE service_orders SET response_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [order.id]);
    await sweepLifecycle();

    const single = await call('GET', `/orders/${order.id}`, clientToken);
    assert.equal(single.body.data.order.status, 'NO_RESPONSE');
    assert.equal(single.body.data.order.responseSecondsLeft, 0);

    const notes = await sql('SELECT 1 FROM notifications WHERE user_id = $1', [clientId]);
    assert.equal(notes.length, 1);
  });
});

describe('الدفع والإنهاء بعد الالتقاء', () => {
  it('لا دفع قبل موافقة المحامي', async () => {
    const order = await createOrder();
    const res = await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
    assert.equal(res.status, 400);
  });

  it('لا إنهاء لطلب لم يُدفع', async () => {
    const order = await createOrder();
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
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

  it('مهلة الوصول بتتحسب عند الدفع', async () => {
    const order = await createPaidOrder();
    const rows = await sql(`SELECT arrival_deadline > NOW() + INTERVAL '29 minutes' AS ok FROM service_orders WHERE id = $1`, [order.id]);
    assert.equal(rows[0].ok, true);
  });

  it('المحامي يوصله تذكير قبل نهاية المهلة بـ 10 دقايق مرة واحدة', async () => {
    const order = await createPaidOrder();
    await sql(`UPDATE service_orders SET arrival_deadline = NOW() + INTERVAL '5 minutes' WHERE id = $1`, [order.id]);
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
  const later = () => new Date(Date.now() + 3 * 86400000).toISOString();

  it('التأجيل بعد «وصلت» بس، وبسبب وميعاد صحيحين', async () => {
    const paid = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${paid.id}/postpone`, lawyerToken, { reason: 'الجلسة', until: later() })).status, 400);
    await closeOrders();

    const order = await createArrivedOrder();
    assert.equal((await call('POST', `/orders/${order.id}/postpone`, lawyerToken, { until: later() })).status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/postpone`, lawyerToken, { reason: 'الجلسة', until: '2020-01-01' })).status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/postpone`, clientToken, { reason: 'الجلسة', until: later() })).status, 404);
  });

  it('المؤجل يفضل محجوز، ويكمل بـ «إنهاء»، والمحامي يقدر يستقبل طلبات', async () => {
    const order = await createArrivedOrder();
    assert.equal((await call('POST', `/orders/${order.id}/postpone`, lawyerToken, { reason: 'الجلسة يوم الخميس', until: later() })).status, 200);

    const listed = (await call('GET', '/orders', clientToken)).body.data[0];
    assert.equal(listed.postponedReason, 'الجلسة يوم الخميس');
    assert.ok(listed.postponedUntil);
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'المحامي أجّل المهمة'`, [clientId])).length, 1);

    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '40 days' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'ACTIVE');

    const nearby = await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25', null);
    assert.equal(nearby.body.data.some((l: any) => l.id === lawyerId), true);

    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 200);
    assert.equal((await wallet()).heldBalance, 350);
  });
});

describe('المهل والمخالفات', () => {
  it('المحامي عنده دقيقتين، وبعد طلبين يتحول لغير متاح', async () => {
    for (let i = 0; i < 2; i++) {
      await sql(`UPDATE lawyer_profiles SET is_available = TRUE WHERE user_id = $1`, [lawyerId]);
      const order = await createOrder();
      await sql(`UPDATE service_orders SET response_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [order.id]);
      await sweepLifecycle();
      assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'NO_RESPONSE');
    }

    assert.equal((await sql('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].is_available, false);
    const notes = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'اتحولت لغير متاح'`, [lawyerId]);
    assert.equal(notes.length, 1);
  });

  it('مهلة الدفع 10 دقايق وبعدها المحامي يتحرر', async () => {
    const order = await createOrder();
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
    await sql(`UPDATE service_orders SET payment_deadline = NOW() - INTERVAL '1 second' WHERE id = $1`, [order.id]);

    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {})).status, 409);
    await sweepLifecycle();

    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'PAYMENT_EXPIRED');
    await createOrder();
  });

  it('طلب مفتوح واحد للموكل، ومهمة واحدة للمحامي', async () => {
    await createOrder();
    const second = await call('POST', '/orders', clientToken, {
      lawyerId, problemType: PROBLEM, problemDescription: 'وصف', clientLat: 30.05, clientLon: 31.25,
    });
    assert.equal(second.status, 409);

    const otherClient = await createUser('01000000021', 'client');
    const busy = await call('POST', '/orders', app.jwt.sign({ userId: otherClient, role: 'client' }), {
      lawyerId, problemType: PROBLEM, problemDescription: 'وصف', clientLat: 30.05, clientLon: 31.25,
    });
    assert.equal(busy.status, 409);

    const nearby = await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25', null);
    assert.equal(nearby.body.data.some((l: any) => l.id === lawyerId), false);
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
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});

    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, { method: 'wallet' })).status, 200);
    assert.equal(await clientBalance(), 0);
  });

  it('الرصيد غير الكافي يرفض الدفع', async () => {
    const order = await createOrder();
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, { method: 'wallet' })).status, 400);
  });

  it('رقم كل طرف يظهر بعد الدفع بس', async () => {
    const order = await createOrder();
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
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

    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
    assert.equal((await orderOf(lawyerToken, order.id)).clientAddress, 'محافظة الغربية');

    await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
    const paid = await orderOf(lawyerToken, order.id);
    assert.equal(paid.clientLatitude, 30.05678);
    assert.equal(paid.clientAddress, 'أبو صير بنا، محافظة الغربية');
    assert.equal((await orderOf(clientToken, order.id)).lawyerLatitude, 30.04321);
  });

  it('موقع المحامي على الخريطة تقريبي للموكل', async () => {
    await sql(`UPDATE lawyer_profiles SET latitude = 30.05678, longitude = 31.25678 WHERE user_id = $1`, [lawyerId]);
    const res = await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25', null);
    const lawyer = res.body.data.find((l: any) => l.id === lawyerId);
    assert.notEqual(lawyer.coordinates[0], 30.05678);
    await sql(`UPDATE lawyer_profiles SET latitude = 30.05, longitude = 31.25 WHERE user_id = $1`, [lawyerId]);
  });
});

describe('ترقيم ML الموحد', () => {
  it('الطلب والتذكرة والتحويل ياخدوا أرقام ML متسلسلة', async () => {
    const first: any = await createOrder();
    await closeOrders();
    assert.match(first.order_number ?? first.orderNumber, /^ML-ORD-\d{6}$/);

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
