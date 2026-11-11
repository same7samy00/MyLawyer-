import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createOrder, closeOrders, createArrivedOrder, createCompletedOrder, createUser, wallet, clientBalance } from './harness.js';
import { LAWYER_CAN_WORK } from '../src/modules/requests/service.js';
const canWork = async (id: string) => (await sql(`SELECT 1 FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id WHERE lp.user_id = $1 AND ${LAWYER_CAN_WORK('lp', 'u')}`, [id])).length > 0;

describe('السعر', () => {
  it('الخادم يحدد السعر ويتجاهل ما يرسله التطبيق', async () => {
    const order = await createOrder({ price: 1 });
    assert.equal(order.price, 350);
  });

  it('الرقم العشوائي يثبت للمستخدم في نفس المشكلة', async () => {
    await sql(`UPDATE problem_prices SET min_price = 300, max_price = 900 WHERE problem_type = $1`, [PROBLEM]);
    const first: any = await createOrder();
    assert.ok(first.price >= 300 && first.price <= 900);

    for (let i = 0; i < 5; i++) {
      await closeOrders();
      assert.equal((await createOrder()).price, first.price);
    }
  });

  it('لو الرقم خرج عن النطاق الجديد يتحسب رقم جديد', async () => {
    await sql(`UPDATE problem_prices SET min_price = 300, max_price = 300 WHERE problem_type = $1`, [PROBLEM]);
    assert.equal((await createOrder()).price, 300);
    await closeOrders();

    await sql(`UPDATE problem_prices SET min_price = 500, max_price = 500 WHERE problem_type = $1`, [PROBLEM]);
    assert.equal((await createOrder()).price, 500);
  });

});

describe('المحفظة', () => {
  it('الأتعاب معلقة 24 ساعة ثم تتاح', async () => {
    const order = await createCompletedOrder();
    let balance = await wallet();
    assert.equal(balance.heldBalance, 350);
    assert.equal(balance.availableBalance, 0);

    await sweepLifecycle();
    assert.equal((await wallet()).availableBalance, 0);

    await sql(`UPDATE service_orders SET hold_until = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    balance = await wallet();
    assert.equal(balance.heldBalance, 0);
    assert.equal(balance.availableBalance, 350);
  });
});

describe('السعر قبل الطلب والنسبة', () => {
  it('الموكل يشوف حدود السعر قبل الطلب، والطلب بسعر المحامي اللي اختاره', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1000, max_price = 1200 WHERE problem_type = $1`, [PROBLEM]);
    const range = await call('GET', `/requests/range?problemType=${encodeURIComponent(PROBLEM)}`, clientToken);
    assert.deepEqual(range.body.data, { minPrice: 1000, maxPrice: 1200 });
    assert.equal((await createOrder()).price, 1000);
  });

  it('المحامي يشوف الصافي بس والموكل يشوف السعر الكامل', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1100, max_price = 1100, commission_percent = 20 WHERE problem_type = $1`, [PROBLEM]);
    const order = await createCompletedOrder();

    assert.equal((await call('GET', '/orders', clientToken)).body.data[0].price, 1100);
    assert.equal((await call('GET', '/orders', lawyerToken)).body.data[0].price, 880);
    assert.equal(Number((await call('GET', `/orders/${order.id}`, lawyerToken)).body.data.order.price), 880);
    assert.equal((await call('GET', `/orders/${order.id}`, clientToken)).body.data.order.lawyer_amount, undefined);
    assert.equal((await wallet()).heldBalance, 880);
  });

  it('الضريبة تتخصم أولاً ونسبة المنصة من الصافي، وتثبت في الطلب', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1000, max_price = 1000, commission_percent = 30 WHERE problem_type = $1`, [PROBLEM]);
    await sql('UPDATE platform_settings SET tax_percent = 10');
    const order = await createArrivedOrder();
    await sql('UPDATE platform_settings SET tax_percent = 0');

    await call('POST', `/orders/${order.id}/complete`, lawyerToken, {});
    assert.equal((await wallet()).heldBalance, 630);
  });

  it('المحامي يظهر بعد موافقة الإدارة فقط، ويوصله إشعار', async () => {
    await sql(`UPDATE lawyer_profiles SET urgent_status = 'NONE' WHERE user_id = $1`, [lawyerId]);
    const visible = () => canWork(lawyerId);

    assert.equal((await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: true })).status, 403);

    // No photo or card means no application
    await sql('UPDATE users SET profile_photo_path = NULL WHERE id = $1', [lawyerId]);
    await sql('UPDATE lawyer_profiles SET profile_photo_path = NULL WHERE user_id = $1', [lawyerId]);
    await sql('DELETE FROM lawyer_documents');
    assert.equal((await call('POST', '/lawyers/me/urgent-terms', lawyerToken, {})).status, 400);

    await sql(`UPDATE lawyer_profiles SET profile_photo_path = '/uploads/avatars/test.jpg' WHERE user_id = $1`, [lawyerId]);
    assert.equal((await call('POST', '/lawyers/me/urgent-terms', lawyerToken, {})).status, 400);

    // The phone sends the card with no file type, the server reads the file itself
    const boundary = 'card-boundary';
    const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(40)]);
    const upload = await app.inject({
      method: 'POST',
      url: '/api/v1/lawyers/me/documents',
      headers: { authorization: `Bearer ${lawyerToken}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
      payload: Buffer.concat([
        Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="card"\r\nContent-Type: application/octet-stream\r\n\r\n`),
        jpeg,
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ]),
    });
    assert.equal(upload.statusCode, 201, upload.body);

    assert.equal((await call('POST', '/lawyers/me/urgent-terms', lawyerToken, {})).status, 200);
    const pending = (await call('GET', '/admin/urgent-applications', adminToken)).body.data.find((item: any) => item.user_id === lawyerId);
    assert.equal(pending.photo, '/uploads/avatars/test.jpg');
    const card = await app.inject({ method: 'GET', url: `/api/v1/lawyers/documents/${pending.card_id}`, headers: { authorization: `Bearer ${adminToken}` } });
    assert.equal(card.statusCode, 200);
    assert.equal(card.headers['content-type'], 'image/jpeg');
    assert.equal(await visible(), false);

    const decision = await call('POST', `/admin/urgent-applications/${lawyerId}/decision`, adminToken, { approve: true });
    assert.equal(decision.status, 200);
    assert.equal(await visible(), true);
    const notes = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'تمت الموافقة على تقديمك'`, [lawyerId]);
    assert.equal(notes.length, 1);
  });

  it('تغيير النسبة لا يأثر على طلب مفتوح', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1000, max_price = 1000, commission_percent = 10 WHERE problem_type = $1`, [PROBLEM]);
    const order = await createArrivedOrder();
    await call('POST', '/admin/commission', adminToken, { percent: 50 });

    await call('POST', `/orders/${order.id}/complete`, lawyerToken, {});
    assert.equal((await wallet()).heldBalance, 900);
  });

  it('الإدارة تضيف وتخصم من الرصيد بسبب، والخصم الزيادة بيبقى دين', async () => {
    assert.equal((await call('POST', `/admin/users/${clientId}/balance`, adminToken, { amount: 100 })).status, 400);
    assert.equal((await call('POST', `/admin/users/${clientId}/balance`, adminToken, { amount: 100, reason: 'تعويض عن مشكلة' })).status, 200);
    assert.equal(await clientBalance(), 100);

    assert.equal((await call('POST', `/admin/users/${lawyerId}/balance`, adminToken, { amount: -50, reason: 'خصم بقرار الإدارة' })).status, 200);
    assert.equal((await wallet()).availableBalance, -50);

    const profile = (await call('GET', `/admin/users/${lawyerId}`, adminToken)).body.data;
    assert.equal(profile.adjustments.length, 1);
    assert.equal(Number(profile.wallet.available), -50);
  });

  it('الإدارة تجمد أتعاب طلب وتفكها', async () => {
    const order = await createCompletedOrder();
    assert.equal((await call('POST', `/admin/orders/${order.id}/freeze`, adminToken, { freeze: true })).status, 200);
    assert.equal((await wallet()).frozenBalance, 350);
    assert.equal((await call('POST', `/admin/orders/${order.id}/freeze`, adminToken, { freeze: false })).status, 200);
    assert.equal((await wallet()).heldBalance, 350);
  });
});

describe('التحويل بين الحسابات', () => {
  const credit = (amount: number) => sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, $2, 'شحن تجريبي')`, [clientId, amount]);

  it('الموكل يحوّل للمحامي برقم الموبايل، والرصيد يتنقل للطرفين', async () => {
    await credit(500);
    const who = await call('GET', '/wallet/recipient?phone=01000000002', clientToken);
    assert.equal(who.status, 200);
    assert.equal(who.body.data.role, 'lawyer');

    const res = await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 150 });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal(await clientBalance(), 350);
    assert.equal((await wallet()).availableBalance, 150);

    const back = await call('POST', '/wallet/transfer', lawyerToken, { phone: '01000000001', amount: 100 });
    assert.equal(back.status, 200);
    assert.equal(await clientBalance(), 450);
    assert.equal((await wallet()).availableBalance, 50);
  });

  it('الأتعاب المحجوزة ما بتتحولش، والمحامي يحوّل لمحامي من المتاح', async () => {
    await createCompletedOrder();
    assert.equal((await wallet()).heldBalance, 350);
    const otherLawyer = '01550000077';
    await createUser(otherLawyer, 'lawyer');
    assert.equal((await call('POST', '/wallet/transfer', lawyerToken, { phone: otherLawyer, amount: 100 })).status, 400);

    await sql(`UPDATE service_orders SET hold_until = NOW() - INTERVAL '1 minute' WHERE lawyer_id = $1 AND payout_status = 'HELD'`, [lawyerId]);
    await sweepLifecycle();
    const sent = await call('POST', '/wallet/transfer', lawyerToken, { phone: otherLawyer, amount: 100 });
    assert.equal(sent.status, 200, JSON.stringify(sent.body));
    assert.equal((await wallet()).availableBalance, 250);
  });

  it('أقل من 100، أو أكتر من الرصيد، أو لنفسك، أو رقم مش موجود: مرفوض', async () => {
    await credit(500);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 99 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 600 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000001', amount: 100 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01099999999', amount: 100 })).status, 404);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000003', amount: 100 })).status, 404);
    assert.equal(await clientBalance(), 500);
  });

  it('من غير WALLET_TRANSFERS=on التحويل مقفول، والرصيد ما بيتحركش', async () => {
    await credit(500);
    process.env.WALLET_TRANSFERS = 'off';
    try {
      assert.equal((await call('GET', '/wallet/recipient?phone=01000000002', clientToken)).status, 403);
      assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 150 })).status, 403);
    } finally {
      process.env.WALLET_TRANSFERS = 'on';
    }
    assert.equal(await clientBalance(), 500);
  });

  it('أقصى مجموع 10,000 في اليوم', async () => {
    await credit(20000);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 9950 })).status, 200);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 100 })).status, 400);
    assert.equal((await call('GET', '/wallet/limits', clientToken)).body.data.remainingToday, 50);

    await sql(`UPDATE wallet_transfers SET created_at = NOW() - INTERVAL '25 hours'`);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 100 })).status, 200);
  });
});

describe('صفحة المدفوعات', () => {
  const payments = async () => (await call('GET', '/wallet/payments', clientToken)).body.data as any[];

  it('الدفعة الناجحة والمرتجعة والفاشلة بتظهر للموكل بس', async () => {
    const order = await createOrder();
    const noBalance = await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, { method: 'wallet' });
    assert.equal(noBalance.status, 400);

    let list = await payments();
    assert.equal(list.length, 1);
    assert.equal(list[0].status, 'FAILED');
    assert.equal(list[0].reason, 'رصيدك مش كفاية');
    assert.equal(list[0].method, 'WALLET');

    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {})).status, 200);
    list = await payments();
    assert.equal(list.length, 2);
    assert.equal(list[0].status, 'PAID');
    assert.match(list[0].reference, /^ML-PAY-\d{6}$/);
    assert.equal(list[0].amount, 350);

    assert.equal((await call('POST', `/orders/${order.id}/cancel`, clientToken, {})).status, 200);
    list = await payments();
    assert.equal(list[0].status, 'REFUNDED');
    assert.equal(list[0].refunded, 350);

    assert.equal((await call('GET', '/wallet/payments', lawyerToken)).body.data.length, 0);
  });
});
