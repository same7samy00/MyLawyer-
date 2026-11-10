import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, closeOrders, createPaidOrder, createArrivedOrder, createCompletedOrder, openTicket } from './harness.js';

describe('التقييمات', () => {
  it('لا تقييم قبل الإنهاء، وتقييم واحد لكل طلب', async () => {
    const paid = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${paid.id}/review`, clientToken, { rating: 5 })).status, 400);
    await closeOrders();

    const done = await createCompletedOrder();
    assert.equal((await call('POST', `/orders/${done.id}/review`, clientToken, { rating: 5 })).status, 201);
    assert.equal((await call('POST', `/orders/${done.id}/review`, clientToken, { rating: 1 })).status, 409);
  });

  it('التعديل مرة واحدة قبل النشر', async () => {
    const order = await createCompletedOrder();
    await call('POST', `/orders/${order.id}/review`, clientToken, { rating: 2 });

    assert.equal((await call('PUT', `/orders/${order.id}/review`, clientToken, { rating: 4 })).status, 200);
    assert.equal((await call('PUT', `/orders/${order.id}/review`, clientToken, { rating: 5 })).status, 400);
  });

  it('التقييم يظهر فوراً ويحسب تقييم المحامي', async () => {
    const order = await createCompletedOrder();
    await call('POST', `/orders/${order.id}/review`, clientToken, { rating: 4, comment: 'خدمة ممتازة' });

    const reviews = await call('GET', `/lawyers/${lawyerId}/reviews`, clientToken);
    assert.equal(reviews.body.data.length, 1);
    assert.equal(reviews.body.data[0].comment, 'خدمة ممتازة');
    assert.ok(reviews.body.data[0].publishedAt);
    assert.ok('authorPhoto' in reviews.body.data[0]);
    await sql(`UPDATE users SET full_name = 'أحمد محمد علي' WHERE id = (SELECT client_id FROM reviews WHERE order_id = $1)`, [order.id]);
    assert.equal((await call('GET', `/lawyers/${lawyerId}/reviews`, clientToken)).body.data[0].authorName, 'أحمد م.');
    assert.equal(Number((await sql('SELECT rating FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].rating), 4);
  });

  it('لوحة التحكم تعرض الحساب وطلباته ودورة حياة الطلب والبحث', async () => {
    const order = await createCompletedOrder();

    const profile = await call('GET', `/admin/users/${lawyerId}`, adminToken);
    assert.equal(profile.status, 200);
    assert.equal(profile.body.data.orders.some((o: any) => o.id === order.id), true);

    const life = await call('GET', `/admin/orders/${order.id}`, adminToken);
    assert.equal(life.status, 200);
    assert.equal(life.body.data.order.completion_code, undefined);
    assert.equal(life.body.data.logs.length > 0, true);

    const found = await call('GET', `/admin/orders?q=${encodeURIComponent(life.body.data.order.order_number)}`, adminToken);
    assert.equal(found.body.data.length, 1);
    assert.equal((await call('GET', '/admin/overview', clientToken)).status, 403);

    await openTicket(lawyerToken, order.id, 'ORDER');
    const stats = (await call('GET', `/admin/orders/${order.id}`, adminToken)).body.data;
    assert.equal(stats.order.client_against >= 1, true);
    assert.equal(stats.order.lawyer_filed >= 1, true);
    assert.equal(typeof stats.order.lawyer_orders, 'number');
    assert.equal(stats.tickets.length, 1);
  });

  it('المحامي يبلغ والإدارة تخفي التعليق', async () => {
    const order = await createCompletedOrder();
    await call('POST', `/orders/${order.id}/review`, clientToken, { rating: 1, comment: 'تعليق مسيء' });

    const review = (await call('GET', `/lawyers/${lawyerId}/reviews`, clientToken)).body.data[0];
    await call('POST', `/lawyers/me/reviews/${review.id}/report`, lawyerToken, { reason: 'إساءة' });

    const reported = await call('GET', '/admin/reviews/reported', adminToken);
    assert.equal(reported.body.data.length, 1);
    await call('POST', `/admin/reviews/${review.id}/moderate`, adminToken, { hide: true });

    assert.equal((await call('GET', `/lawyers/${lawyerId}/reviews`, clientToken)).body.data.length, 0);
    assert.equal(Number((await sql('SELECT reviews_count FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].reviews_count), 0);
  });
});

describe('تذكير التقييم', () => {
  it('بعد يوم من إنهاء المهمة يوصل للموكل تذكير واحد بس، ومش بيوصل لو قيّم', async () => {
    const order = await createCompletedOrder();
    await sql(`UPDATE service_orders SET completed_at = NOW() - INTERVAL '25 hours' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    await sweepLifecycle();
    const reminders = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'قيّم المحامي'`, [clientId]);
    assert.equal(reminders.length, 1);

    await sql('DELETE FROM notifications');
    await closeOrders();
    const rated = await createCompletedOrder();
    await call('POST', `/orders/${rated.id}/review`, clientToken, { rating: 5 });
    await sql(`UPDATE service_orders SET completed_at = NOW() - INTERVAL '25 hours' WHERE id = $1`, [rated.id]);
    await sweepLifecycle();
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE title = 'قيّم المحامي'`)).length, 0);
  });

});
