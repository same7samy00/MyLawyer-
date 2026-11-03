import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { app, adminToken, call, clientId, clientToken, closeOrders, createOrder, createPaidOrder, createUser, lawyerId, lawyerToken, sql } from './harness.js';
import { hashPassword, hashSha256 } from '../src/utils/security.js';
import { detectFileType } from '../src/utils/files.js';
import { assertProductionSecrets } from '../src/config/index.js';

const OTP = '123456';
const PASSWORD = 'Strong12345';

let counter = 0;
const newPhone = () => `0150${String(Date.now() + counter++).slice(-7)}`;

async function newAccount(status = 'active', role = 'client') {
  const phone = newPhone();
  const email = `${phone}@example.test`;
  const rows = await sql(
    `INSERT INTO users (phone, email, role, status) VALUES ($1, $2, $3::user_role, $4::user_status) RETURNING id`,
    [phone, email, role, status]
  );
  const id = rows[0].id as string;
  await sql('INSERT INTO user_credentials (user_id, password_hash) VALUES ($1, $2)', [id, await hashPassword(PASSWORD)]);
  return { id, phone, email };
}

async function addOtp(table: 'email_verifications' | 'password_reset_requests', userId: string, code = OTP) {
  await sql(`INSERT INTO ${table} (user_id, otp_hash, expires_at) VALUES ($1, $2, NOW() + INTERVAL '10 minutes')`, [userId, hashSha256(code)]);
}

describe('تأمين الدخول والحساب', () => {
  it('الحساب الموقوف ما يقدرش يفعّل نفسه برمز التحقق', async () => {
    const user = await newAccount('suspended');
    await addOtp('email_verifications', user.id);
    const res = await call('POST', '/auth/verify-otp', null, { email: user.email, otp: OTP });
    assert.equal(res.status, 409);
    assert.equal((await sql('SELECT status FROM users WHERE id = $1', [user.id]))[0].status, 'suspended');
  });

  it('رمز التفعيل ما يتبعتش لحساب مش مستني تفعيل', async () => {
    const user = await newAccount('suspended');
    const res = await call('POST', '/auth/resend-otp', null, { email: user.email });
    assert.equal(res.status, 409);
    assert.equal((await sql('SELECT COUNT(*)::int AS total FROM email_verifications WHERE user_id = $1', [user.id]))[0].total, 0);
  });

  it('المحامي الجديد ما يبقاش متاح لوحده بعد تفعيل الإيميل', async () => {
    const user = await newAccount('pending_email_verification', 'lawyer');
    await sql(`INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number) VALUES ($1, 'أ. جديد', $2)`, [user.id, user.phone]);
    await addOtp('email_verifications', user.id);
    const res = await call('POST', '/auth/verify-otp', null, { email: user.email, otp: OTP });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    const profile = (await sql('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [user.id]))[0];
    assert.equal(profile.is_available, false);
  });

  it('محاولات رمز استعادة كلمة المرور محدودة، حتى لو الرمز الصح جه بعدها', async () => {
    const user = await newAccount();
    await addOtp('password_reset_requests', user.id);
    const attempt = (otp: string) => call('POST', '/auth/reset-password', null, { email: user.email, otp, newPassword: 'NewStrong123', confirmPassword: 'NewStrong123' });
    for (let i = 0; i < 5; i++) assert.equal((await attempt('000000')).status, 400);
    assert.equal((await attempt(OTP)).status, 429);
  });

  it('الرمز الصح بيغير كلمة المرور وبيقفل كل الجلسات', async () => {
    const user = await newAccount();
    await addOtp('password_reset_requests', user.id);
    const login = await call('POST', '/auth/login', null, { identifier: user.phone, password: PASSWORD });
    const res = await call('POST', '/auth/reset-password', null, { email: user.email, otp: OTP, newPassword: 'NewStrong123', confirmPassword: 'NewStrong123' });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal((await call('POST', '/auth/refresh', null, { refreshToken: login.body.data.refreshToken })).status, 401);
    assert.equal((await call('POST', '/auth/login', null, { identifier: user.phone, password: 'NewStrong123' })).status, 200);
  });

  it('طلب رمز الاستعادة له فاصل دقيقة، فمفيش سيل رموز وإيميلات', async () => {
    const user = await newAccount();
    for (let i = 0; i < 3; i++) assert.equal((await call('POST', '/auth/forgot-password', null, { email: user.email })).status, 200);
    assert.equal((await sql('SELECT COUNT(*)::int AS total FROM password_reset_requests WHERE user_id = $1', [user.id]))[0].total, 1);
  });

  it('تغيير كلمة المرور بيقفل الجلسات القديمة', async () => {
    const user = await newAccount();
    const login = await call('POST', '/auth/login', null, { identifier: user.phone, password: PASSWORD });
    const res = await call('POST', '/users/me/change-password', login.body.data.accessToken, { currentPassword: PASSWORD, newPassword: 'NewStrong123', confirmNewPassword: 'NewStrong123' });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.equal((await call('POST', '/auth/refresh', null, { refreshToken: login.body.data.refreshToken })).status, 401);
  });

  it('محاولات الدخول على نفس الحساب محدودة حتى من عناوين مختلفة', async () => {
    const user = await newAccount();
    const attempt = (ip: string) => app.inject({ method: 'POST', url: '/api/v1/auth/login', remoteAddress: ip, payload: { identifier: user.phone, password: 'wrong-password' } });
    for (let i = 0; i < 10; i++) assert.equal((await attempt(`10.0.0.${i + 1}`)).statusCode, 401);
    assert.equal((await attempt('10.0.0.99')).statusCode, 429);
  });

  it('رمز التجديد المتكرر في نفس اللحظة بينجح مرة واحدة', async () => {
    const user = await newAccount();
    const login = await call('POST', '/auth/login', null, { identifier: user.phone, password: PASSWORD });
    const refresh = () => call('POST', '/auth/refresh', null, { refreshToken: login.body.data.refreshToken });
    const statuses = (await Promise.all([refresh(), refresh()])).map((res) => res.status).sort();
    assert.deepEqual(statuses, [200, 401]);
  });

  it('طلبات التجديد الناقصة ترجع رد واضح مش خطأ خادم', async () => {
    const empty = await app.inject({ method: 'POST', url: '/api/v1/auth/refresh' });
    assert.equal(empty.statusCode, 400);
    assert.equal((await call('POST', '/auth/refresh', null, { refreshToken: 12345 })).status, 400);
  });

  it('عنوان الجهاز الحقيقي هو اللي بيتسجل، مش اللي المرسل بيكتبه', async () => {
    const user = await newAccount();
    await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      remoteAddress: '127.0.0.1',
      headers: { 'x-forwarded-for': '9.9.9.9, 41.41.41.41' },
      payload: { identifier: user.phone, password: PASSWORD },
    });
    const session = (await sql('SELECT ip_address::text AS ip FROM user_sessions WHERE user_id = $1', [user.id]))[0];
    assert.match(session.ip, /^41\.41\.41\.41/);
  });

  it('الخادم يرفض العمل في الإنتاج بأسرار افتراضية أو ناقصة', () => {
    const good = { NODE_ENV: 'production', JWT_SECRET: 'x'.repeat(40), DATABASE_URL: 'postgresql://u:p@localhost/db' };
    assert.doesNotThrow(() => assertProductionSecrets(good));
    assert.throws(() => assertProductionSecrets({ ...good, JWT_SECRET: undefined }));
    assert.throws(() => assertProductionSecrets({ ...good, JWT_SECRET: 'short' }));
    assert.throws(() => assertProductionSecrets({ ...good, DATABASE_URL: undefined }));
    assert.doesNotThrow(() => assertProductionSecrets({ NODE_ENV: 'test' }));
  });
});

describe('الخصوصية قبل الدفع', () => {
  it('تفاصيل الطلب ما بتكشفش تليفون أو إيميل الطرف التاني قبل الدفع', async () => {
    const order = await createOrder();
    for (const token of [lawyerToken, clientToken]) {
      const text = JSON.stringify((await call('GET', `/orders/${order.id}`, token)).body);
      assert.ok(!text.includes('01000000001'), 'رقم الموكل ظهر');
      assert.ok(!text.includes('01000000002'), 'رقم المحامي ظهر');
      assert.ok(!text.includes('@example.test'), 'الإيميل ظهر');
    }
  });

  it('الموكل ما يشوفش صافي المحامي في تفاصيل الطلب', async () => {
    const order = await createPaidOrder();
    const data = (await call('GET', `/orders/${order.id}`, clientToken)).body.data.order;
    assert.equal(data.lawyer_amount, undefined);
    assert.equal(data.payout_amount, undefined);
  });
});

describe('الصلاحيات والمدخلات', () => {
  it('المحامي الموقوف مرفوض في مسارات المحامي كمان', async () => {
    await sql(`UPDATE users SET status = 'suspended'::user_status WHERE id = $1`, [lawyerId]);
    const res = await call('POST', '/lawyers/me/availability', lawyerToken, { isAvailable: true });
    assert.equal(res.status, 403);
    assert.equal(res.body.data.status, 'suspended');
  });

  it('الاعتذار والإلغاء من غير جسم للطلب مش خطأ خادم', async () => {
    const order = await createOrder();
    const rejected = await app.inject({ method: 'POST', url: `/api/v1/orders/${order.id}/reject`, headers: { authorization: `Bearer ${lawyerToken}` } });
    assert.equal(rejected.statusCode, 200, rejected.body);
    const next = await createOrder();
    const cancelled = await app.inject({ method: 'POST', url: `/api/v1/orders/${next.id}/cancel`, headers: { authorization: `Bearer ${clientToken}` } });
    assert.equal(cancelled.statusCode, 200, cancelled.body);
  });

  it('معرف غير صالح يرجع 400 من غير تفاصيل قاعدة البيانات', async () => {
    const res = await call('POST', '/orders', clientToken, { lawyerId: 'not-a-uuid', problemDescription: 'وصف', clientLat: 30, clientLon: 31 });
    assert.equal(res.status, 400);
    assert.equal((await call('GET', '/lawyers/documents/not-a-uuid', lawyerToken)).status, 400);
    // A route without its own check: the error handler answers, and no database wording leaves
    const unchecked = await call('POST', '/admin/urgent-applications/not-a-uuid/decision', adminToken, { approve: true });
    assert.equal(unchecked.status, 400);
    assert.ok(!JSON.stringify(unchecked.body).includes('uuid'));
    // The in-memory database needs one query to recover after an error, real PostgreSQL doesn't
    await sql('SELECT 1').catch(() => {});
  });

  it('وصف الطلب لازم يكون نص', async () => {
    assert.equal((await call('POST', '/orders', clientToken, { lawyerId, problemDescription: 123, clientLat: 30, clientLon: 31 })).status, 400);
  });

  it('قائمة الطلبات بحساب الإدارة شغالة', async () => {
    await createOrder();
    const all = await call('GET', '/orders', adminToken);
    assert.equal(all.status, 200, JSON.stringify(all.body));
    assert.equal(all.body.data.length, 1);
    const pending = await call('GET', '/orders?status=PENDING', adminToken);
    assert.equal(pending.status, 200, JSON.stringify(pending.body));
    assert.equal((await call('GET', '/orders?status=COMPLETED', adminToken)).body.data.length, 0);
  });

  it('فيديو MP4 مش بيتقبل كصورة', () => {
    const box = (brand: string) => Buffer.concat([Buffer.from([0, 0, 0, 24]), Buffer.from(`ftyp${brand}`), Buffer.alloc(12)]);
    assert.equal(detectFileType(box('isom')), null);
    assert.equal(detectFileType(box('mp42')), null);
    assert.equal(detectFileType(box('heic'))?.mime, 'image/heic');
    assert.equal(detectFileType(box('mif1'))?.mime, 'image/heic');
  });

  it('البلاغ على تعليق مرة واحدة بس', async () => {
    const order = await createOrder();
    const [review] = await sql(
      `INSERT INTO reviews (order_id, client_id, lawyer_id, rating, comment, publish_at, published_at) VALUES ($1, $2, $3, 1, 'تعليق', NOW(), NOW()) RETURNING id`,
      [order.id, clientId, lawyerId]
    );
    assert.equal((await call('POST', `/lawyers/me/reviews/${review.id}/report`, lawyerToken, { reason: 'السبب الأول' })).status, 200);
    assert.equal((await call('POST', `/lawyers/me/reviews/${review.id}/report`, lawyerToken, { reason: 'السبب التاني' })).status, 409);
    assert.equal((await sql('SELECT report_reason FROM reviews WHERE id = $1', [review.id]))[0].report_reason, 'السبب الأول');
  });

  it('تعديل التقييم مقفول بعد مدة السبعة أيام', async () => {
    const order = await createOrder();
    await sql(`UPDATE service_orders SET status = 'COMPLETED', completed_at = NOW() - INTERVAL '8 days' WHERE id = $1`, [order.id]);
    await sql(
      `INSERT INTO reviews (order_id, client_id, lawyer_id, rating, publish_at, published_at) VALUES ($1, $2, $3, 3, NOW(), NOW())`,
      [order.id, clientId, lawyerId]
    );
    assert.equal((await call('PUT', `/orders/${order.id}/review`, clientToken, { rating: 5 })).status, 400);
  });
});

describe('تزامن الطلبات', () => {
  it('موكلين في نفس اللحظة: محامي واحد ياخد طلب واحد بس', async () => {
    const secondId = await createUser(newPhone(), 'client');
    const secondToken = app.jwt.sign({ userId: secondId, role: 'client' });
    const body = { lawyerId, problemDescription: 'وصف المشكلة', clientLat: 30.05, clientLon: 31.25 };
    const results = await Promise.all([call('POST', '/orders', clientToken, body), call('POST', '/orders', secondToken, body)]);
    assert.deepEqual(results.map((res) => res.status).sort(), [201, 409]);
    await closeOrders();
  });

  it('موكل واحد ضغط مرتين في نفس اللحظة: طلب واحد بس', async () => {
    const body = { lawyerId, problemDescription: 'وصف المشكلة', clientLat: 30.05, clientLon: 31.25 };
    const results = await Promise.all([call('POST', '/orders', clientToken, body), call('POST', '/orders', clientToken, body)]);
    assert.deepEqual(results.map((res) => res.status).sort(), [201, 409]);
  });

  it('القبول والاعتذار في نفس اللحظة: واحد بس يتنفذ', async () => {
    const order = await createOrder();
    const results = await Promise.all([
      call('POST', `/orders/${order.id}/accept`, lawyerToken, {}),
      call('POST', `/orders/${order.id}/reject`, lawyerToken, {}),
    ]);
    assert.equal(results.filter((res) => res.status === 200).length, 1, JSON.stringify(results.map((res) => res.status)));
  });
});
