import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, createOrder } from './harness.js';

describe('أجهزة الإشعارات', () => {
  it('الجهاز يتسجل لصاحبه ويتشال عند الخروج', async () => {
    const saved = await call('POST', '/notifications/device-token', lawyerToken, { token: 'device-1' });
    assert.equal(saved.status, 200);
    assert.equal((await sql('SELECT user_id FROM device_tokens WHERE token = $1', ['device-1']))[0].user_id, lawyerId);

    await call('POST', '/notifications/device-token', clientToken, { token: 'device-1' });
    assert.equal((await sql('SELECT user_id FROM device_tokens WHERE token = $1', ['device-1']))[0].user_id, clientId);

    await call('POST', '/notifications/device-token/remove', lawyerToken, { token: 'device-1' });
    assert.equal((await sql('SELECT 1 FROM device_tokens')).length, 1);

    await call('POST', '/notifications/device-token/remove', clientToken, { token: 'device-1' });
    assert.equal((await sql('SELECT 1 FROM device_tokens')).length, 0);
  });

  it('رمز فاضي مرفوض', async () => {
    assert.equal((await call('POST', '/notifications/device-token', lawyerToken, {})).status, 400);
  });
});

describe('ظهور المحامي على الخريطة', () => {
  it('المحامي المتاح يفضل ظاهر لو مكانه حديث، و«غير متاح» يخفيه', async () => {
    const visible = async () => (await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25', null)).body.data.some((l: any) => l.id === lawyerId);

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '5 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await visible(), true);

    await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: false });
    assert.equal(await visible(), false);
  });

  it('توقف تحديث الموقع 10 دقايق يخفي المحامي ويبلغه، والتحديث ما يرجعوش', async () => {
    const available = async () =>
      (await sql('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].is_available;

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '5 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await available(), true);

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '11 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await available(), false);

    const update = await call('POST', '/lawyers/me/location', lawyerToken, { latitude: 30.05, longitude: 31.25 });
    assert.equal(update.body.data.isAvailable, false);
    assert.equal(await available(), false);
    const notes = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'خرجت من الخدمة'`, [lawyerId]);
    assert.equal(notes.length, 1);
  });

  it('التحديث لا يرجع المحامي اللي قفل الزر بنفسه', async () => {
    await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: false });
    const update = await call('POST', '/lawyers/me/location', lawyerToken, { latitude: 30.05, longitude: 31.25 });
    assert.equal(update.body.data.isAvailable, false);
  });

  it('المحامي بدون موقع حقيقي لا يظهر على الخريطة', async () => {
    await sql(`UPDATE lawyer_profiles SET latitude = NULL, longitude = NULL WHERE user_id = $1`, [lawyerId]);
    const res = await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25&radius_km=1500', null);
    await sql(`UPDATE lawyer_profiles SET latitude = 30.05, longitude = 31.25 WHERE user_id = $1`, [lawyerId]);
    assert.equal(res.body.data.some((l: any) => l.id === lawyerId), false);
  });

  it('الخريطة بتجيب محامي المنطقة الظاهرة بس، وبحد للعدد', async () => {
    const inArea = await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25&north=30.2&south=29.9&east=31.4&west=31.1&limit=5', null);
    assert.equal(inArea.body.data.some((l: any) => l.id === lawyerId), true);
    assert.ok(inArea.body.data.length <= 5);
    const away = await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25&north=25&south=24&east=33&west=32', null);
    assert.equal(away.body.data.some((l: any) => l.id === lawyerId), false);
    const bad = await call('GET', "/lawyers/nearby?lat=30.05&lon=31.25&limit=1;DROP&sort=x", null);
    assert.equal(bad.status, 200);
  });

  it('المحامي البعيد يظهر على الخريطة بنطاق مصر كلها', async () => {
    const res = await call('GET', '/lawyers/nearby?lat=23.9&lon=32.9&radius_km=1500', null);
    assert.equal(res.body.data.some((l: any) => l.id === lawyerId), true);
  });

  it('القبول يحدث مكان المحامي في الطلب', async () => {
    const order = await createOrder();
    const accepted = await call('POST', `/orders/${order.id}/accept`, lawyerToken, { latitude: 30.79, longitude: 31.0 });
    assert.equal(accepted.status, 200);

    const row = (await sql('SELECT lawyer_latitude FROM service_orders WHERE id = $1', [order.id]))[0];
    assert.equal(Number(row.lawyer_latitude), 30.79);
    await sql(`UPDATE lawyer_profiles SET latitude = 30.05, longitude = 31.25 WHERE user_id = $1`, [lawyerId]);
  });

  it('تصفح الخريطة يوصل لمحامين أبعد من نطاق الطلب', async () => {
    const res = await call('GET', '/lawyers/nearby?lat=30.05&lon=30.45&radius_km=100', null);
    assert.equal(res.body.data.some((l: any) => l.id === lawyerId), true);
  });
});

describe('الترتيب والإشعارات والصلاحيات', () => {
  it('كل المحامين بالترتيب من الأقرب للأبعد', async () => {
    const near = await createUser('01000000011', 'lawyer');
    const nearTop = await createUser('01000000012', 'lawyer');
    const far = await createUser('01000000013', 'lawyer');
    const rows: [string, number, number, number][] = [
      [near, 28.0, 33.001, 3.0],
      [nearTop, 28.0, 33.002, 4.9],
      [far, 28.0, 33.1, 5.0],
    ];
    for (const [id, lat, lon, rating] of rows) {
      await sql(
        `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, latitude, longitude, rating, last_active_at, urgent_status)
         VALUES ($1, 'ترتيب', $2, 'approved'::lawyer_approval_status, TRUE, $3, $4, $5, NOW(), 'APPROVED')`,
        [id, id.slice(0, 8), lat, lon, rating]
      );
    }

    const res = await call('GET', '/lawyers/nearby?lat=28.0&lon=33.0&radius_km=50', null);
    assert.deepEqual(res.body.data.map((l: any) => l.id), [near, nearTop, far]);
  });

  it('عداد الطلبات للمحامي وقراءة الإشعارات', async () => {
    await createOrder();

    const summary = await call('GET', '/notifications/summary', lawyerToken);
    assert.equal(summary.body.data.pendingOrders, 1);
    assert.equal(summary.body.data.unread, 1);

    await call('POST', '/notifications/read-all', lawyerToken, {});
    assert.equal((await call('GET', '/notifications/summary', lawyerToken)).body.data.unread, 0);
  });

  it('الموكل والمحامي لا يصلان لمسارات الإدارة', async () => {
    assert.equal((await call('GET', '/admin/support', clientToken)).status, 403);
    assert.equal((await call('PUT', '/admin/prices', lawyerToken, { problemType: PROBLEM, minPrice: 1, maxPrice: 2 })).status, 403);
  });

  it('الإدارة تحدد نطاق السعر', async () => {
    const res = await call('PUT', '/admin/prices', adminToken, { problemType: PROBLEM, minPrice: 400, maxPrice: 400 });
    assert.equal(res.status, 200);
    assert.equal((await createOrder()).price, 400);
  });
});

describe('حماية السيرفر', () => {
  it('تحديثات قاعدة البيانات مش متاحة من رابط عام', async () => {
    for (const url of ['/health/migrate', '/api/v1/health/migrate']) {
      assert.equal((await app.inject({ method: 'GET', url })).statusCode, 404);
    }
  });
});

describe('إيقاف الحساب', () => {
  it('الحساب الموقوف يترفض في كل العمليات ويرجع بعد التفعيل', async () => {
    const stop = await call('POST', `/admin/users/${clientId}/status`, adminToken, { suspend: true });
    assert.equal(stop.status, 200);

    for (const [method, url] of [['GET', '/users/me'], ['GET', '/orders'], ['GET', '/notifications']]) {
      const res = await call(method, url, clientToken);
      assert.equal(res.status, 403, url);
      assert.equal(res.body.data.status, 'suspended');
    }
    assert.equal((await call('POST', '/notifications/device-token/remove', clientToken, { token: 'x' })).status, 200);

    await call('POST', `/admin/users/${clientId}/status`, adminToken, { suspend: false });
    assert.equal((await call('GET', '/users/me', clientToken)).status, 200);
  });
});
