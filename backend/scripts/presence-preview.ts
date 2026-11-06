// Local preview of the "where I'll be" page with sample lawyers in a temporary database, nothing reaches the real server.
// Run from the backend folder: npm run preview:tawagod, then open http://localhost:4100/tawagod/
// Sign in with any sample: 01000000101 / demo123
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { uuid_ossp } from '@electric-sql/pglite/contrib/uuid_ossp';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

const DB_PORT = 55435;
const PORT = Number(process.env.PORT || 4100);
process.env.DATABASE_URL = `postgresql://postgres:postgres@127.0.0.1:${DB_PORT}/postgres?sslmode=disable`;
process.env.NODE_ENV = 'test';
const fs = await import('node:fs');
const path = await import('node:path');

const db = await PGlite.create({ extensions: { pgcrypto, uuid_ossp } });
await new PGLiteSocketServer({ db, port: DB_PORT, host: '127.0.0.1' }).start();

const { dbPool } = await import('../src/database/index.js');
dbPool.options.max = 1;
await (await import('../src/database/migrate.js')).runMigrations(false);
const { hashPassword } = await import('../src/utils/security.js');
const { buildApp } = await import('../src/app.js');
const app: any = buildApp();

// Nginx serves the website on the real server, the preview does it here
const SITE = path.resolve('public/site');
const TYPES: Record<string, string> = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf' };
app.get('/*', async (request: any, reply: any) => {
  let file = path.join(SITE, decodeURIComponent(String(request.params['*'])).replace(/\.\./g, ''));
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) return reply.status(404).send('Not found');
  return reply.type(TYPES[path.extname(file)] || 'application/octet-stream').send(fs.readFileSync(file));
});
await app.ready();

const sql = (text: string, params: any[] = []) => dbPool.query(text, params);
const hash = await hashPassword('demo123');
const samples: [string, string, string, string[], number, string | null, string | null, string | null][] = [
  ['أ. محمود السيد', '01000000101', 'الزقازيق', ['مجمع محاكم الزقازيق', 'محكمة الأسرة بالزقازيق'], 1, '09:00', '13:00', 'أي حد محتاج اطلاع أو صورة حكم يكلمني'],
  ['أ. هبة عبد الرحمن', '01000000102', 'القاهرة', ['مصر الجديدة', 'الأميرية', 'العباسية', 'التجمع', 'دار القضاء العالي'], 1, null, null, null],
  ['أ. كريم فؤاد', '01000000103', 'الإسكندرية', ['محكمة شرق الإسكندرية الابتدائية'], 1, '10:00', null, null],
  ['أ. ياسمين علي', '01000000104', 'الإسكندرية', ['محكمة غرب الإسكندرية', 'مجمع محاكم المنشية'], 0, '08:30', '12:00', null],
  ['أ. أحمد سمير', '01000000105', 'المنصورة', ['محكمة المنصورة الابتدائية'], 2, null, '14:00', 'متاح للحضور في جلسات التأجيل'],
  ['أ. مروة حسن', '01000000106', 'الجيزة', ['محكمة الجيزة الابتدائية', 'محكمة جنوب الجيزة', 'نيابة الهرم'], 0, '09:00', '15:00', null],
];
for (const [name, phone, city, places, offset, from, to, note] of samples) {
  const id = (await sql('INSERT INTO presence_accounts (full_name, phone, whatsapp, password_hash) VALUES ($1, $2, $2, $3) RETURNING id', [name, phone, hash])).rows[0].id;
  await sql(
    `INSERT INTO presence_entries (account_id, city, places, day, time_from, time_to, note)
     VALUES ($1, $2, $3, (NOW() AT TIME ZONE 'Africa/Cairo')::date + $4::int, $5, $6, $7)`,
    [id, city, places, offset, from, to, note]
  );
}

await app.listen({ port: PORT, host: '127.0.0.1' });
console.log(`Preview ready: http://localhost:${PORT}/tawagod/`);
