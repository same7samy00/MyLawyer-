import assert from 'node:assert/strict';
import { after, before, beforeEach } from 'node:test';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { uuid_ossp } from '@electric-sql/pglite/contrib/uuid_ossp';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

// Runs against an in-memory PostgreSQL, so no real data is involved
const PORT = 55433;
process.env.DATABASE_URL = `postgresql://postgres:postgres@127.0.0.1:${PORT}/postgres?sslmode=disable`;
process.env.NODE_ENV = 'test';
process.env.PRIVATE_STORAGE_PATH = (await import('node:path')).join((await import('node:os')).tmpdir(), 'mylawyer-test-docs');

export const PROBLEM = 'محضر في قسم الشرطة';

export let db: PGlite;
let socket: PGLiteSocketServer;
export let app: any;
export let dbPool: any;
export let sweepLifecycle: () => Promise<void>;

export let clientId: string;
export let lawyerId: string;
export let adminId: string;
export let clientToken: string;
export let lawyerToken: string;
export let adminToken: string;

export async function call(method: string, url: string, token: string | null, payload?: object) {
  const res = await app.inject({
    method,
    url: `/api/v1${url}`,
    headers: token ? { authorization: `Bearer ${token}` } : {},
    payload,
  });
  return { status: res.statusCode, body: res.json() };
}

export async function sql(text: string, params: any[] = []) {
  return (await dbPool.query(text, params)).rows;
}

export async function createUser(phone: string, role: string) {
  const rows = await sql(
    `INSERT INTO users (phone, email, role, status, email_verified_at)
     VALUES ($1, $2, $3::user_role, 'active'::user_status, NOW()) RETURNING id`,
    [phone, `${phone}@example.test`, role]
  );
  return rows[0].id as string;
}

export async function createOrder(overrides: object = {}) {
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

export async function closeOrders() {
  await sql(`UPDATE service_orders SET status = 'CANCELLED' WHERE status IN ('PENDING', 'ACCEPTED', 'ACTIVE')`);
}

export async function createPaidOrder() {
  const order = await createOrder();
  await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
  const paid = await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
  assert.equal(paid.status, 200);
  return order;
}

export async function createArrivedOrder() {
  const order = await createPaidOrder();
  const arrived = await call('POST', `/orders/${order.id}/arrive`, lawyerToken, { latitude: 30.0502, longitude: 31.25 });
  assert.equal(arrived.status, 200, JSON.stringify(arrived.body));
  return order;
}

export async function createCompletedOrder() {
  const order = await createArrivedOrder();
  const done = await call('POST', `/orders/${order.id}/complete`, lawyerToken, {});
  assert.equal(done.status, 200, JSON.stringify(done.body));
  return order;
}

export function openTicket(token: string, orderId: string | null, category = 'MONEY') {
  return call('POST', '/support/tickets', token, { category, title: 'مشكلة في الطلب', body: 'تفاصيل المشكلة بالكامل هنا', ...(orderId ? { orderId } : {}) });
}

export async function wallet() {
  return (await call('GET', '/orders/wallet/me', lawyerToken)).body.data;
}

export async function clientBalance() {
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
  sweepLifecycle = (await import('../src/modules/lifecycle/sweep.js')).sweepLifecycle;
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
  for (const table of ['change_log', 'service_requests', 'ticket_attachments', 'ticket_messages', 'support_tickets', 'wallet_transfers', 'reviews', 'lawyer_strikes', 'client_credits', 'account_warnings', 'lawyer_adjustments', 'notifications', 'client_problem_prices', 'order_status_logs']) {
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
