// Local preview of the control page with sample data in a temporary database, nothing reaches the real server.
// Run from the backend folder: npm run preview:panel
// Sign in: admin@demo.test / Demo12345
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { uuid_ossp } from '@electric-sql/pglite/contrib/uuid_ossp';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

const DB_PORT = 55434;
process.env.DATABASE_URL = `postgresql://postgres:postgres@127.0.0.1:${DB_PORT}/postgres?sslmode=disable`;
process.env.NODE_ENV = 'test';
const { tmpdir } = await import('node:os');
const { join } = await import('node:path');
const fs = await import('node:fs');
process.env.PUBLIC_STORAGE_PATH = join(tmpdir(), 'mylawyer-demo-public');
process.env.PRIVATE_STORAGE_PATH = join(tmpdir(), 'mylawyer-demo-private');

const db = await PGlite.create({ extensions: { pgcrypto, uuid_ossp } });
await new PGLiteSocketServer({ db, port: DB_PORT, host: '127.0.0.1' }).start();

const { dbPool } = await import('../src/database/index.js');
dbPool.options.max = 1;
await (await import('../src/database/migrate.js')).runMigrations(false);
const { hashPassword } = await import('../src/utils/security.js');
const { buildApp } = await import('../src/app.js');
const app: any = buildApp();
// Nginx serves the photos on the real server, the preview does it here
app.get('/uploads/*', async (request: any, reply: any) => {
  const file = join(process.env.PUBLIC_STORAGE_PATH!, String(request.params['*']).replace(/\.\./g, ''));
  if (!fs.existsSync(file)) return reply.status(404).send();
  return reply.type('image/png').send(fs.readFileSync(file));
});
await app.ready();

const sql = (text: string, params: any[] = []) => dbPool.query(text, params);

const user = async (phone: string, role: string, name: string) =>
  (await sql(
    `INSERT INTO users (phone, email, role, status, email_verified_at, full_name)
     VALUES ($1, $2, $3::user_role, 'active'::user_status, NOW(), $4) RETURNING id`,
    [phone, `${phone}@example.test`, role, name]
  )).rows[0].id as string;

const lawyer = async (phone: string, name: string, urgentStatus: string, specialty: string) => {
  const id = await user(phone, 'lawyer', name);
  await sql(
    `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, specialty, bio, approval_status, is_available,
                                  latitude, longitude, urgent_status, urgent_terms_accepted_at)
     VALUES ($1, $2, $3, $4, 'محامٍ بخبرة في القضايا العاجلة', 'approved', TRUE, 30.05, 31.25, $5, NOW())`,
    [id, name, String(100000 + Number(phone.slice(-3))), specialty, urgentStatus]
  );
  return id;
};

const adminId = await user('01000000000', 'admin', 'الإدارة');
await sql(`UPDATE users SET email = 'admin@demo.test' WHERE id = $1`, [adminId]);
await sql('INSERT INTO user_credentials (user_id, password_hash) VALUES ($1, $2)', [adminId, await hashPassword('Demo12345')]);

const client1 = await user('01100000001', 'client', 'أحمد محمود');
const client2 = await user('01100000002', 'client', 'سارة علي');
const lawyer1 = await lawyer('01200000001', 'أ. محمد حسن', 'APPROVED', 'القانون الجنائي');
const lawyer2 = await lawyer('01200000002', 'أ. منى عادل', 'APPROVED', 'قانون الأسرة');
await lawyer('01200000003', 'أ. كريم سمير', 'PENDING', 'القانون المدني');

const token = (userId: string, role: string) => app.jwt.sign({ userId, role, status: 'active' });
const call = async (url: string, userToken: string, payload: object = {}) =>
  (await app.inject({ method: 'POST', url: `/api/v1${url}`, headers: { authorization: `Bearer ${userToken}` }, payload })).json();
const list = async (userToken: string) =>
  (await app.inject({ method: 'GET', url: '/api/v1/orders', headers: { authorization: `Bearer ${userToken}` } })).json().data;

const c1 = token(client1, 'client');
const c2 = token(client2, 'client');
const l1 = token(lawyer1, 'lawyer');
const l2 = token(lawyer2, 'lawyer');

const order = async (clientToken: string, lawyerId: string, problemType: string) =>
  (await call('/orders', clientToken, {
    lawyerId, problemType, problemDescription: 'وصف تجريبي للمشكلة', clientLat: 30.05, clientLon: 31.25,
  })).data;

// Completed and reviewed
const done = await order(c1, lawyer1, 'محضر في قسم الشرطة');
await call(`/orders/${done.id}/accept`, l1);
await call(`/orders/${done.id}/confirm-payment`, c1);
await call(`/orders/${done.id}/arrive`, l1, { latitude: 30.0501, longitude: 31.25 });
await call(`/orders/${done.id}/complete`, l1, {});
await call(`/orders/${done.id}/review`, c1, { rating: 5, comment: 'محامي محترم ووصل بسرعة' });

// Active with an open money ticket
const active = await order(c2, lawyer1, 'محضر في قسم الشرطة');
await call(`/orders/${active.id}/accept`, l1);
await call(`/orders/${active.id}/confirm-payment`, c2);
await call('/support/tickets', c2, { category: 'MONEY', orderId: active.id, title: 'المحامي اتأخر', body: 'المحامي اتأخر عن الميعاد المتفق عليه ومش بيرد' });

// Cancelled, then one waiting for the lawyer
const cancelled = await order(c1, lawyer2, 'محضر في قسم الشرطة');
await call(`/orders/${cancelled.id}/cancel`, c1, { reason: 'الموكل غيّر رأيه' });
await order(c1, lawyer2, 'محضر في قسم الشرطة');

// More sample data so every page has something to show
const client3 = await user('01100000003', 'client', 'محمود فتحي');
const client4 = await user('01100000004', 'client', 'نورهان سامي');
const client5 = await user('01100000005', 'client', 'خالد إبراهيم');
const c5 = token(client5, 'client');
const lawyer3 = await lawyer('01200000004', 'أ. ياسر فؤاد', 'APPROVED', 'قانون العمل');
const lawyer4 = await lawyer('01200000005', 'أ. هبة رمزي', 'APPROVED', 'القانون التجاري');
const lawyer5 = await lawyer('01200000006', 'أ. شريف نبيل', 'APPROVED', 'القانون الإداري');
const lawyer6 = await lawyer('01200000007', 'أ. دينا مصطفى', 'PENDING', 'قضايا الأسرة');
const sample = fs.readFileSync(join(process.cwd(), '..', 'assets', 'images', 'app_logo.png'));
const upload = (url: string, userToken: string) => {
  const boundary = 'demo-boundary';
  return app.inject({
    method: 'POST',
    url: `/api/v1${url}`,
    headers: { authorization: `Bearer ${userToken}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
    payload: Buffer.concat([
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="image.png"\r\nContent-Type: application/octet-stream\r\n\r\n`),
      sample,
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]),
  });
};
const l6 = token(lawyer6, 'lawyer');
await upload('/users/me/profile-photo', l6);
await upload('/lawyers/me/documents', l6);
const l4 = token(lawyer4, 'lawyer');
const l5 = token(lawyer5, 'lawyer');
const c3 = token(client3, 'client');
const c4 = token(client4, 'client');

// An account ticket the admin already answered, so it is open
const accountTicket = await call('/support/tickets', c3, { category: 'ACCOUNT', title: 'مش قادر أغير صورتي', body: 'كل ما أرفع صورة جديدة بيطلع خطأ' });
await sql(`INSERT INTO ticket_messages (ticket_id, author, author_id, body) VALUES ($1, 'ADMIN', $2, 'جرب صورة أصغر من 5 ميجا وقولنا')`, [accountTicket.data.id, adminId]);
await sql(`UPDATE support_tickets SET status = 'OPEN' WHERE id = $1`, [accountTicket.data.id]);

// Lawyer ticket, then the order expired and the lawyer appealed
const expired = await order(c4, lawyer4, 'محضر في قسم الشرطة');
await call(`/orders/${expired.id}/accept`, l4);
await call(`/orders/${expired.id}/confirm-payment`, c4);
await call('/support/tickets', l4, { category: 'ORDER', orderId: expired.id, title: 'تعامل غير لائق', body: 'الموكل اتعامل بشكل غير لائق وقت المهمة' });
await sql(`UPDATE service_orders SET status = 'EXPIRED', expires_at = NOW() - INTERVAL '1 hour' WHERE id = $1`, [expired.id]);
await call(`/orders/${expired.id}/appeal`, l4, { reason: 'وصلت للموكل وخلصت المهمة بس النت كان واقع' });

// Cancelled after payment, so the client got the money back as credit
const refunded = await order(c5, lawyer5, 'محضر في قسم الشرطة');
await call(`/orders/${refunded.id}/accept`, l5);
await call(`/orders/${refunded.id}/confirm-payment`, c5);
await call(`/orders/${refunded.id}/cancel`, c5, { reason: 'اتحلت المشكلة' });

// A reported review and lawyer strikes
await sql(`UPDATE reviews SET reported_at = NOW(), report_reason = 'التعليق فيه معلومات غلط' WHERE order_id = $1`, [done.id]);
await sql(`INSERT INTO lawyer_strikes (lawyer_id, kind) VALUES ($1, 'NO_RESPONSE'), ($1, 'WITHDRAW')`, [lawyer2]);
await sql(`UPDATE users SET status = 'suspended' WHERE id = $1`, [client4]);

await app.listen({ port: 3900, host: '127.0.0.1' });
console.log('panel ready');
