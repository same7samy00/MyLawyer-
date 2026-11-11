import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { app, adminToken, call, createUser, sql } from './harness.js';
import { hashPassword } from '../src/utils/security.js';
import { wipeAccount } from '../src/modules/users/deletion.js';

const PASSWORD = 'DeleteMe12345';
let counter = 0;
const newPhone = () => `0155${String(Date.now() + counter++).slice(-7)}`;

/// A fresh account with a password and a token, so each test has its own
async function account(role: 'client' | 'lawyer' = 'client') {
  const phone = newPhone();
  const id = await createUser(phone, role);
  await sql('INSERT INTO user_credentials (user_id, password_hash) VALUES ($1, $2)', [id, await hashPassword(PASSWORD)]);
  if (role === 'lawyer') await sql(`INSERT INTO lawyer_profiles (user_id, full_name, approval_status) VALUES ($1, 'محامي للحذف', 'approved')`, [id]);
  const token = app.jwt.sign({ userId: id, role }) as string;
  return { id, phone, token };
}

describe('حذف الحساب', () => {
  it('محتاج كلمة السر الصح، وحساب الإدارة ما بيتمسحش من هنا', async () => {
    const me = await account();
    assert.equal((await call('POST', '/users/me/delete', me.token, {})).status, 400);
    assert.equal((await call('POST', '/users/me/delete', me.token, { password: 'wrong-one' })).status, 400);
    assert.equal((await call('POST', '/users/me/delete', null, { password: PASSWORD })).status, 401);
    assert.equal((await call('POST', '/users/me/delete', adminToken, { password: PASSWORD })).status, 403);
    assert.equal((await sql('SELECT deletion_requested_at FROM users WHERE id = $1', [me.id]))[0].deletion_requested_at, null);
  });

  it('الرصيد أو المديونية أو تذكرة مفتوحة بيمنعوا الحذف وبيقولوا السبب', async () => {
    const me = await account();
    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 150, 'رصيد تجربة')`, [me.id]);
    let res = await call('POST', '/users/me/delete', me.token, { password: PASSWORD });
    assert.equal(res.status, 409);
    assert.match(res.body.error, /رصيد 150/);

    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, -200, 'مديونية تجربة')`, [me.id]);
    res = await call('POST', '/users/me/delete', me.token, { password: PASSWORD });
    assert.equal(res.status, 409);
    assert.match(res.body.error, /مديونية 50/);

    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 50, 'تسوية')`, [me.id]);
    await sql(`INSERT INTO support_tickets (reference, user_id, category, title) VALUES ($1, $2, 'OTHER', 'سؤال')`, [`ML-TKT-T${counter++}`, me.id]);
    res = await call('POST', '/users/me/delete', me.token, { password: PASSWORD });
    assert.equal(res.status, 409);
    assert.match(res.body.error, /تذكرة/);
  });

  it('الطلب بيخرّج الحساب من كل مكان، والتحويل له بيتقفل، والدخول تاني بيلغيه', async () => {
    const me = await account('lawyer');
    await sql(`INSERT INTO user_sessions (user_id, refresh_token_hash, expires_at) VALUES ($1, 'h-${counter++}', NOW() + INTERVAL '1 day')`, [me.id]);
    await sql(`INSERT INTO device_tokens (token, user_id, platform) VALUES ($1, $2, 'android')`, [`dev-${counter++}`, me.id]);
    await sql('UPDATE lawyer_profiles SET is_available = TRUE WHERE user_id = $1', [me.id]);

    const res = await call('POST', '/users/me/delete', me.token, { password: PASSWORD });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    const days = (new Date(res.body.data.deleteAt).getTime() - Date.now()) / 86_400_000;
    assert.ok(days > 29.9 && days < 30.1, 'deleted after 30 days');

    assert.equal((await sql('SELECT COUNT(*)::int AS n FROM user_sessions WHERE user_id = $1 AND revoked_at IS NULL', [me.id]))[0].n, 0);
    assert.equal((await sql('SELECT COUNT(*)::int AS n FROM device_tokens WHERE user_id = $1', [me.id]))[0].n, 0);
    assert.equal((await sql('SELECT is_available FROM lawyer_profiles WHERE user_id = $1', [me.id]))[0].is_available, false);
    const sender = await account();
    assert.equal((await call('GET', `/wallet/recipient?phone=${me.phone}`, sender.token)).status, 404, 'no transfers to an account on its way out');

    const back = await call('POST', '/auth/login', null, { identifier: me.phone, password: PASSWORD });
    assert.equal(back.status, 200, JSON.stringify(back.body));
    assert.equal(back.body.data.user.deletionCancelled, true);
    assert.equal((await sql('SELECT deletion_requested_at FROM users WHERE id = $1', [me.id]))[0].deletion_requested_at, null);
  });

  it('بعد 30 يوم البيانات الشخصية بتتمسح، والطلبات والفلوس بتفضل باسم مجهول، والدخول بيقف', async () => {
    const me = await account();
    const order = await sql(
      `INSERT INTO service_orders (order_number, client_id, lawyer_id, service_type, service_title, problem_description, client_latitude, client_longitude, price, status)
       SELECT 'ML-ORD-DEL' || $2, $1, u.id, 'URGENT', 'خدمة', 'وصف', 30.05, 31.25, 300, 'COMPLETED' FROM users u WHERE u.role = 'lawyer' LIMIT 1
       RETURNING id`,
      [me.id, String(counter++)]
    );
    assert.equal((await call('POST', '/users/me/delete', me.token, { password: PASSWORD })).status, 200);
    await sql(`UPDATE users SET deletion_requested_at = NOW() - INTERVAL '31 days' WHERE id = $1`, [me.id]);

    assert.equal(await wipeAccount(me.id), true);
    const user = (await sql('SELECT full_name, phone, email, status, deleted_at FROM users WHERE id = $1', [me.id]))[0];
    assert.equal(user.full_name, 'حساب محذوف');
    assert.notEqual(user.phone, me.phone);
    assert.match(user.email, /@deleted\.invalid$/);
    assert.equal(user.status, 'suspended');
    assert.ok(user.deleted_at);
    assert.equal((await sql('SELECT COUNT(*)::int AS n FROM user_credentials WHERE user_id = $1', [me.id]))[0].n, 0);
    assert.equal((await sql('SELECT COUNT(*)::int AS n FROM service_orders WHERE id = $1', [order[0].id]))[0].n, 1, 'the order stays for the books');
    assert.equal((await call('POST', '/auth/login', null, { identifier: me.phone, password: PASSWORD })).status, 401);
    assert.equal(await wipeAccount(me.id), false, 'a wiped account is not wiped twice');
  });

  it('فلوس وصلت بعد الطلب بتوقف المسح لحد ما الإدارة تشوفها', async () => {
    const me = await account();
    assert.equal((await call('POST', '/users/me/delete', me.token, { password: PASSWORD })).status, 200);
    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 120, 'قرار إدارة')`, [me.id]);
    assert.equal(await wipeAccount(me.id), false);
    assert.equal((await sql('SELECT deleted_at FROM users WHERE id = $1', [me.id]))[0].deleted_at, null);
  });
});
