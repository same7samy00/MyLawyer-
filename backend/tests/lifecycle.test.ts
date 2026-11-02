import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { uuid_ossp } from '@electric-sql/pglite/contrib/uuid_ossp';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

// Runs against an in-memory PostgreSQL, so no real data is involved
const PORT = 55433;
process.env.DATABASE_URL = `postgresql://postgres:postgres@127.0.0.1:${PORT}/postgres?sslmode=disable`;
process.env.NODE_ENV = 'test';
process.env.PRIVATE_STORAGE_PATH = (await import('node:path')).join((await import('node:os')).tmpdir(), 'mylawyer-test-docs');

const PROBLEM = 'محضر في قسم الشرطة';

let db: PGlite;
let socket: PGLiteSocketServer;
let app: any;
let dbPool: any;
let sweepLifecycle: () => Promise<void>;

let clientId: string;
let lawyerId: string;
let adminId: string;
let clientToken: string;
let lawyerToken: string;
let adminToken: string;

async function call(method: string, url: string, token: string | null, payload?: object) {
  const res = await app.inject({
    method,
    url: `/api/v1${url}`,
    headers: token ? { authorization: `Bearer ${token}` } : {},
    payload,
  });
  return { status: res.statusCode, body: res.json() };
}

async function sql(text: string, params: any[] = []) {
  return (await dbPool.query(text, params)).rows;
}

async function createUser(phone: string, role: string) {
  const rows = await sql(
    `INSERT INTO users (phone, email, role, status, email_verified_at)
     VALUES ($1, $2, $3::user_role, 'active'::user_status, NOW()) RETURNING id`,
    [phone, `${phone}@example.test`, role]
  );
  return rows[0].id as string;
}

async function createOrder(overrides: object = {}) {
  const res = await call('POST', '/orders', clientToken, {
    lawyerId,
    problemType: PROBLEM,
    problemDescription: 'وصف المشكلة',
    clientLat: 30.05,
    clientLon: 31.25,
    ...overrides,
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data as { id: string; price: number };
}

async function closeOrders() {
  await sql(`UPDATE service_orders SET status = 'CANCELLED' WHERE status IN ('PENDING', 'ACCEPTED', 'ACTIVE')`);
}

async function createPaidOrder() {
  const order = await createOrder();
  await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
  const paid = await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
  assert.equal(paid.status, 200);
  return order;
}

async function createArrivedOrder() {
  const order = await createPaidOrder();
  const arrived = await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 });
  assert.equal(arrived.status, 200, JSON.stringify(arrived.body));
  return order;
}

async function createCompletedOrder() {
  const order = await createArrivedOrder();
  const done = await call('POST', `/orders/${order.id}/complete`, lawyerToken, {});
  assert.equal(done.status, 200, JSON.stringify(done.body));
  return order;
}

async function wallet() {
  return (await call('GET', '/orders/wallet/me', lawyerToken)).body.data;
}

async function clientBalance() {
  return (await call('GET', '/orders/wallet/me', clientToken)).body.data.balance as number;
}

before(async () => {
  db = await PGlite.create({ extensions: { pgcrypto, uuid_ossp } });
  socket = new PGLiteSocketServer({ db, port: PORT, host: '127.0.0.1' });
  await socket.start();

  const database = await import('../src/database/index.js');
  dbPool = database.dbPool;
  dbPool.options.max = 1;

  const { runMigrations } = await import('../src/database/migrate.js');
  await runMigrations(false);

  const { buildApp } = await import('../src/app.js');
  sweepLifecycle = (await import('../src/modules/lifecycle/service.js')).sweepLifecycle;
  app = buildApp();
  await app.ready();

  clientId = await createUser('01000000001', 'client');
  lawyerId = await createUser('01000000002', 'lawyer');
  adminId = await createUser('01000000003', 'admin');
  await sql(
    `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, latitude, longitude)
     VALUES ($1, 'أ. اختبار', '99001', 'approved'::lawyer_approval_status, TRUE, 30.05, 31.25)`,
    [lawyerId]
  );

  clientToken = app.jwt.sign({ userId: clientId, role: 'client' });
  lawyerToken = app.jwt.sign({ userId: lawyerId, role: 'lawyer' });
  adminToken = app.jwt.sign({ userId: adminId, role: 'admin' });
});

beforeEach(async () => {
  for (const table of ['wallet_transfers', 'reviews', 'order_appeals', 'complaints', 'lawyer_reports', 'lawyer_strikes', 'client_credits', 'account_warnings', 'lawyer_adjustments', 'notifications', 'client_problem_prices', 'order_status_logs']) {
    await sql(`DELETE FROM ${table}`);
  }
  await sql('DELETE FROM service_orders');
  await sql(`UPDATE problem_prices SET min_price = 350, max_price = 350, commission_percent = 0`);
  await sql(`UPDATE lawyer_profiles SET is_available = TRUE, urgent_status = 'APPROVED', availability_off_reason = NULL, missed_orders = 0, suspended_until = NULL, last_active_at = NOW(), last_location_updated_at = NOW() WHERE user_id = $1`, [lawyerId]);
  await sql(`UPDATE users SET warnings_count = 0, suspended_until = NULL, status = 'active'::user_status WHERE id = ANY($1)`, [[clientId, lawyerId]]);
});

after(async () => {
  await app.close();
  await dbPool.end();
  await socket.stop();
  await db.close();
});

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

describe('الشكاوى والتسوية بالالتقاء', () => {
  const settlement = async (orderId: string) => (await call('GET', `/admin/orders/${orderId}/settlement`, adminToken)).body.data;
  const settle = (orderId: string, body: object = {}) => call('POST', `/admin/orders/${orderId}/settle`, adminToken, body);

  it('المحامي ما وصلش: الفلوس ترجع للموكل كاملة', async () => {
    const order = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${order.id}/complaint`, clientToken, { kind: 'MONEY' })).status, 201);
    assert.equal((await settlement(order.id)).outcome, 'REFUND');

    assert.equal((await settle(order.id)).status, 200);
    assert.equal(await clientBalance(), 350);
    assert.equal((await wallet()).availableBalance, 0);
  });

  it('المحامي أنهى المهمة: الأتعاب للمحامي حتى لو فيه شكوى فلوس', async () => {
    const order = await createCompletedOrder();
    await call('POST', `/orders/${order.id}/complaint`, clientToken, { kind: 'MONEY' });
    assert.equal((await wallet()).frozenBalance, 350);
    assert.equal((await settlement(order.id)).outcome, 'LAWYER');

    await settle(order.id);
    assert.equal((await wallet()).availableBalance, 350);
    assert.equal(await clientBalance(), 0);
  });

  it('المحامي وصل وما أنهاش المهمة: الأتعاب للمحامي، والنسبة على نصيبه', async () => {
    await sql(`UPDATE problem_prices SET min_price = 1000, max_price = 1000, commission_percent = 20 WHERE problem_type = $1`, [PROBLEM]);
    const order = await createArrivedOrder();
    await call('POST', `/orders/${order.id}/report`, lawyerToken, { kind: 'MONEY' });
    assert.equal((await settlement(order.id)).outcome, 'LAWYER');

    await settle(order.id);
    assert.equal(await clientBalance(), 0);
    assert.equal((await wallet()).availableBalance, 800);
    assert.equal((await call('GET', '/admin/reports', adminToken)).body.data.length, 0);
  });

  it('الإدارة تقدر تختار التقسيم مناصفة بنفسها', async () => {
    const order = await createArrivedOrder();
    assert.equal((await settle(order.id, { outcome: 'SPLIT' })).status, 200);
    assert.equal(await clientBalance(), 175);
    assert.equal((await wallet()).availableBalance, 175);
  });

  it('شكوى الفلوس توقف الإنهاء والمهلة لحد القرار', async () => {
    const order = await createArrivedOrder();
    await call('POST', `/orders/${order.id}/complaint`, clientToken, { kind: 'MONEY' });
    assert.equal((await call('POST', `/orders/${order.id}/complete`, lawyerToken, {})).status, 409);

    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal((await sql('SELECT status FROM service_orders WHERE id = $1', [order.id]))[0].status, 'ACTIVE');
  });

  it('شكوى التعامل ما بتلمسش الفلوس، والإدارة توجه إنذار', async () => {
    const order = await createCompletedOrder();
    assert.equal((await call('POST', `/orders/${order.id}/complaint`, clientToken, { kind: 'BEHAVIOR' })).status, 201);
    assert.equal((await wallet()).heldBalance, 350);

    const list = await call('GET', '/admin/complaints', adminToken);
    assert.equal(list.body.data[0].kind, 'BEHAVIOR');
    assert.equal((await call('POST', `/admin/complaints/${list.body.data[0].id}/close`, adminToken, { warn: true })).status, 200);
    assert.equal((await sql('SELECT COUNT(*)::int AS n FROM account_warnings WHERE user_id = $1', [lawyerId]))[0].n, 1);
  });

  it('الشكوى محتاجة نوع، وبتتقفل بعد 24 ساعة، والغريب ما يشتكيش', async () => {
    const order = await createCompletedOrder();
    assert.equal((await call('POST', `/orders/${order.id}/complaint`, clientToken, {})).status, 400);

    const other = await createUser('01000000009', 'client');
    assert.equal((await call('POST', `/orders/${order.id}/complaint`, app.jwt.sign({ userId: other, role: 'client' }), { kind: 'MONEY' })).status, 404);

    await sql(`UPDATE service_orders SET completed_at = NOW() - INTERVAL '25 hours' WHERE id = $1`, [order.id]);
    assert.equal((await call('POST', `/orders/${order.id}/complaint`, clientToken, { kind: 'MONEY' })).status, 400);
    assert.equal((await call('POST', `/orders/${order.id}/report`, lawyerToken, { kind: 'BEHAVIOR' })).status, 400);
  });
});

describe('مهلة المهمة', () => {
  it('التذكيرات تتبعت مرة واحدة', async () => {
    const order = await createPaidOrder();
    await sql(`UPDATE service_orders SET expires_at = NOW() + INTERVAL '10 hours' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    await sweepLifecycle();

    const rows = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'تذكير بإنهاء المهمة'`, [lawyerId]);
    assert.equal(rows.length, 1);
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

  it('المهلة خلصت والمحامي وصل: الأتعاب للمحامي لوحدها', async () => {
    const order = await createArrivedOrder();
    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();

    assert.equal(await clientBalance(), 0);
    assert.equal((await wallet()).availableBalance, 350);
  });
});

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

    const reviews = await call('GET', `/lawyers/${lawyerId}/reviews`, null);
    assert.equal(reviews.body.data.length, 1);
    assert.equal(reviews.body.data[0].comment, 'خدمة ممتازة');
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

    await call('POST', `/orders/${order.id}/report`, lawyerToken, { kind: 'BEHAVIOR', reason: 'الموكل ما ادانيش الكود في الميعاد' });
    const reports = await call('GET', '/admin/reports', adminToken);
    const report = reports.body.data.find((r: any) => r.order_id === order.id);
    assert.equal(report.client_against >= 1, true);
    assert.equal(report.lawyer_filed >= 1, true);
    assert.equal(typeof report.lawyer_orders, 'number');
  });

  it('المحامي يبلغ والإدارة تخفي التعليق', async () => {
    const order = await createCompletedOrder();
    await call('POST', `/orders/${order.id}/review`, clientToken, { rating: 1, comment: 'تعليق مسيء' });

    const review = (await call('GET', `/lawyers/${lawyerId}/reviews`, null)).body.data[0];
    await call('POST', `/lawyers/me/reviews/${review.id}/report`, lawyerToken, { reason: 'إساءة' });

    const reported = await call('GET', '/admin/reviews/reported', adminToken);
    assert.equal(reported.body.data.length, 1);
    await call('POST', `/admin/reviews/${review.id}/moderate`, adminToken, { hide: true });

    assert.equal((await call('GET', `/lawyers/${lawyerId}/reviews`, null)).body.data.length, 0);
    assert.equal(Number((await sql('SELECT reviews_count FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].reviews_count), 0);
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

  it('شكوى المحامي على التعامل تتقفل بإنذار للموكل', async () => {
    const order = await createPaidOrder();
    assert.equal((await call('POST', `/orders/${order.id}/report`, lawyerToken, { kind: 'BEHAVIOR' })).status, 201);

    const reports = await call('GET', '/admin/reports', adminToken);
    assert.equal(reports.body.data[0].kind, 'BEHAVIOR');
    assert.equal((await call('POST', `/admin/reports/${reports.body.data[0].id}/close`, adminToken, { warn: true })).status, 200);
    assert.equal((await sql('SELECT COUNT(*)::int AS n FROM account_warnings WHERE user_id = $1', [clientId]))[0].n, 1);
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
  it('المحامي المتاح يفضل ظاهر حتى لو التطبيق مقفول', async () => {
    const visible = async () => (await call('GET', '/lawyers/nearby?lat=30.05&lon=31.25', null)).body.data.some((l: any) => l.id === lawyerId);

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '30 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await visible(), true);

    await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: false });
    assert.equal(await visible(), false);
  });

  it('توقف تحديث الموقع ساعة يخفي المحامي ويبلغه، والتحديث ما يرجعوش', async () => {
    const available = async () =>
      (await sql('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [lawyerId]))[0].is_available;

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '30 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await available(), true);

    await sql(`UPDATE lawyer_profiles SET last_location_updated_at = NOW() - INTERVAL '70 minutes' WHERE user_id = $1`, [lawyerId]);
    await sweepLifecycle();
    assert.equal(await available(), false);

    const update = await call('POST', '/lawyers/me/location', lawyerToken, { latitude: 30.05, longitude: 31.25 });
    assert.equal(update.body.data.isAvailable, false);
    assert.equal(await available(), false);
    const notes = await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'اتحولت لغير متاح'`, [lawyerId]);
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
    assert.equal((await call('GET', '/admin/complaints', clientToken)).status, 403);
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

describe('ترقيم ML الموحد', () => {
  it('الطلب والشكوى والتحويل ياخدوا أرقام ML متسلسلة', async () => {
    const first: any = await createOrder();
    await closeOrders();
    assert.match(first.order_number ?? first.orderNumber, /^ML-ORD-\d{6}$/);

    const order = await createArrivedOrder();
    const complaint = await call('POST', `/orders/${order.id}/complaint`, clientToken, { kind: 'BEHAVIOR' });
    assert.match(complaint.body.data.reference, /^ML-CMP-\d{6}$/);
    assert.ok(complaint.body.message.includes(complaint.body.data.reference));

    const report = await call('POST', `/orders/${order.id}/report`, lawyerToken, { kind: 'BEHAVIOR' });
    assert.match(report.body.data.reference, /^ML-RPT-\d{6}$/);

    const listed = await call('GET', '/admin/complaints', adminToken);
    assert.equal(listed.body.data[0].reference, complaint.body.data.reference);

    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 500, 'شحن تجريبي')`, [clientId]);
    const transfer = await call('POST', '/wallet/transfer', clientToken, { phone: '01000000002', amount: 100 });
    assert.match(transfer.body.data.reference, /^ML-TRF-\d{6}$/);
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

  it('لو المهلة خلصت والمحامي وصل، الطلب يتقفل والموكل يقدر يقيّم', async () => {
    const order = await createArrivedOrder();
    await sql(`UPDATE service_orders SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1`, [order.id]);
    await sweepLifecycle();
    assert.equal((await sql(`SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'المهمة اتقفلت'`, [clientId])).length, 1);
    assert.equal((await call('POST', `/orders/${order.id}/review`, clientToken, { rating: 4 })).status, 201);
  });
});
