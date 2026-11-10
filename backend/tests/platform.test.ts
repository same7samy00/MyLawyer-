import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PROBLEM, app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, createOrder, createPaidOrder, createArrivedOrder } from './harness.js';
import { LAWYER_CAN_WORK } from '../src/modules/requests/service.js';
const canWork = async (id: string) => (await sql(`SELECT 1 FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id WHERE lp.user_id = $1 AND ${LAWYER_CAN_WORK('lp', 'u')}`, [id])).length > 0;

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

describe('استقبال المحامي للطلبات', () => {
  it('المحامي المتاح يفضل بيستقبل طلبات لو مكانه حديث، و«غير متاح» يوقفه', async () => {
    const visible = () => canWork(lawyerId);

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '5 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await visible(), true);

    await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: false });
    assert.equal(await visible(), false);
  });

  it('الموبايل الساكت بيوصله تنبيهين صامتين، وبعد 8 دقايق من غير رد المحامي يتقفل ويتبلغ، والتحديث ما يرجعوش', async () => {
    const available = async () =>
      (await sql('SELECT is_available, wake_count FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0];
    const quiet = (minutes: number, wokeMinutesAgo: number | null) => sql(
      `UPDATE lawyer_profiles SET last_location_updated_at = NOW() - make_interval(mins => $2),
         last_wake_at = CASE WHEN $3::int IS NULL THEN last_wake_at ELSE NOW() - make_interval(mins => $3::int) END WHERE user_id = $1`,
      [lawyerId, minutes, wokeMinutesAgo]
    );

    await sql('UPDATE lawyer_profiles SET wake_count = 0, last_wake_at = NULL WHERE user_id = $1', [lawyerId]);
    await quiet(4, null);
    await sweepLifecycle();
    assert.equal((await available()).wake_count, 0);

    await quiet(5, null);
    await sweepLifecycle();
    assert.deepEqual(await available(), { is_available: true, wake_count: 1 });

    await quiet(7, 2);
    await sweepLifecycle();
    assert.deepEqual(await available(), { is_available: true, wake_count: 2 });

    await quiet(8, 1);
    await sweepLifecycle();
    assert.equal((await available()).is_available, false);

    const update = await call('POST', '/lawyers/me/location', lawyerToken, { latitude: 30.05, longitude: 31.25 });
    assert.equal(update.body.data.isAvailable, false);
    assert.deepEqual(await available(), { is_available: false, wake_count: 0 });
    const notes = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'خرجت من الخدمة'`, [lawyerId]);
    assert.equal(notes.length, 1);
  });

  it('الموبايل الساكت: صاحب المهمة الشغالة ما يتقفلش، وصاحب المهمة المؤجلة يتقفل زي أي حد', async () => {
    const order = await createArrivedOrder();
    const silent = () => sql(
      `UPDATE lawyer_profiles SET is_available = TRUE, wake_count = 2, last_wake_at = NOW() - INTERVAL '2 minutes',
         last_location_updated_at = NOW() - INTERVAL '9 minutes', last_active_at = NOW() - INTERVAL '9 minutes' WHERE user_id = $1`,
      [lawyerId]
    );
    const isAvailable = async () => (await sql('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].is_available;

    await silent();
    await sweepLifecycle();
    assert.equal(await isAvailable(), true, 'a running task keeps the lawyer on');

    assert.equal((await call('POST', `/orders/${order.id}/postpone`, lawyerToken, {})).status, 200);
    await silent();
    await sweepLifecycle();
    assert.equal(await isAvailable(), false, 'only a postponed task: a silent phone is turned off');
  });

  it('التحديث لا يرجع المحامي اللي قفل الزر بنفسه', async () => {
    await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: false });
    const update = await call('POST', '/lawyers/me/location', lawyerToken, { latitude: 30.05, longitude: 31.25 });
    assert.equal(update.body.data.isAvailable, false);
  });
});

describe('الترتيب والإشعارات والصلاحيات', () => {
  it('عداد مهمة المحامي الشغالة وقراءة الإشعارات', async () => {
    await createPaidOrder();

    const summary = await call('GET', '/notifications/summary', lawyerToken);
    assert.equal(summary.body.data.pendingOrders, 1);
    assert.ok(summary.body.data.unread >= 1);

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

  it('من غير الذاكرة السريعة الخادم شغال عادي، وفحص الحالة بيقول إنها مقفولة', async () => {
    const health = (await app.inject({ method: 'GET', url: '/api/v1/health' })).json();
    assert.equal(health.status, 'UP');
    assert.equal(health.fastMemory, 'OFF');
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
