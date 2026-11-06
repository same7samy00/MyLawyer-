import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createOrder, closeOrders, createArrivedOrder, createCompletedOrder, wallet, clientBalance } from './harness.js';

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

  it('تعديل السعر من لوحة التحكم يلغي الأسعار المحفوظة للموكلين', async () => {
    await sql(`UPDATE problem_prices SET min_price = 300, max_price = 900 WHERE problem_type = $1`, [PROBLEM]);
    await createOrder();
    await closeOrders();
    assert.equal((await sql('SELECT 1 FROM client_problem_prices')).length, 1);

    const res = await call('PUT', '/admin/prices', adminToken, { problemType: PROBLEM, minPrice: 300, maxPrice: 900 });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal((await sql('SELECT 1 FROM client_problem_prices')).length, 0);
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
  it('الموكل يشوف السعر قبل الطلب، وهو نفس سعر الطلب', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1000, max_price = 1200 WHERE problem_type = $1`, [PROBLEM]);
    const quote = await call('POST', '/orders/quote', clientToken, { problemType: PROBLEM });
    assert.ok(quote.body.data.price >= 1000 && quote.body.data.price <= 1200);
    assert.equal((await createOrder()).price, quote.body.data.price);
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
    const visible = async () => (await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25', null)).body.data.some((l: any) => l.id === lawyerId);

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
  const refund = (amount: number) => sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, $2, 'مبلغ مرتجع')`, [clientId, amount]);
  // Money that reached the client by transfer can be withdrawn, so it can be transferred again
  const credit = async (amount: number) => {
    await sql('INSERT INTO wallet_transfers (sender_id, recipient_id, amount, created_at) VALUES ($1, $2, $3, NOW() - INTERVAL \'2 days\')', [lawyerId, clientId, amount]);
    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, $2, 'تحويل تجريبي')`, [clientId, amount]);
  };

  it('المبالغ المرتجعة ما بتتحولش، والمتاح للسحب بس هو اللي بيتحول', async () => {
    await refund(500);
    const blocked = await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 100 });
    assert.equal(blocked.status, 400);
    assert.match(blocked.body.error, /المبالغ المرتجعة/);
    assert.equal((await call('GET', '/wallet/limits', clientToken)).body.data.transferable, 0);

    await credit(200);
    assert.equal((await call('GET', '/wallet/limits', clientToken)).body.data.transferable, 200);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 250 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 200 })).status, 200);
    assert.equal(await clientBalance(), 500);
  });

  it('أي حد يحوّل لأي حد: الموكل للمحامي والمحامي للموكل', async () => {
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

  it('أقل من 100، أو أكتر من الرصيد، أو لنفسك، أو رقم مش موجود: مرفوض', async () => {
    await credit(500);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 99 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 600 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000001', amount: 100 })).status, 400);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01099999999', amount: 100 })).status, 404);
    assert.equal((await call('POST', '/wallet/transfer', clientToken, { phone: '01000000003', amount: 100 })).status, 404);
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
