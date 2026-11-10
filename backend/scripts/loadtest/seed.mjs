// Fills a separate load-test database with lawyers and clients spread over Egypt (docs/LOAD_TEST.md).
// Never point it at the production database: it refuses any database whose name doesn't end in _loadtest.
//   DATABASE_URL=postgresql://.../mylawyer_loadtest LAWYERS=5000 CLIENTS=20000 node seed.mjs /root/loadtest/ids.json
import fs from 'node:fs';
import pg from 'pg';

const url = process.env.DATABASE_URL ?? '';
if (!/\/[a-z_]+_loadtest(\?|$)/.test(url)) throw new Error('DATABASE_URL must be a *_loadtest database');
const LAWYERS = Number(process.env.LAWYERS ?? 5000);
const CLIENTS = Number(process.env.CLIENTS ?? 20000);
const out = process.argv[2] ?? 'ids.json';

// Where people are, roughly by population: Greater Cairo, Alexandria, the Delta and Upper Egypt
const CENTERS = [
  [30.0444, 31.2357, 0.30], [30.0131, 31.2089, 0.10], [30.0626, 31.3366, 0.08], [29.9765, 31.1313, 0.07],
  [31.2001, 29.9187, 0.14], [30.5852, 31.5020, 0.05], [30.7865, 31.0004, 0.05], [31.0409, 31.3785, 0.05],
  [27.1801, 31.1837, 0.04], [25.6872, 32.6396, 0.04], [30.4660, 31.1848, 0.04], [29.0661, 31.0994, 0.04],
];
const pick = () => {
  let r = Math.random();
  for (const c of CENTERS) { if ((r -= c[2]) <= 0) return c; }
  return CENTERS[0];
};
// Up to about 8 km around a center
const around = ([lat, lon]) => [lat + (Math.random() - 0.5) * 0.15, lon + (Math.random() - 0.5) * 0.15];

const db = new pg.Client({ connectionString: url });
await db.connect();
const ids = { lawyers: [], clients: [] };

async function insertUsers(role, count, prefix) {
  const made = [];
  for (let start = 0; start < count; start += 1000) {
    const n = Math.min(1000, count - start);
    const values = [];
    const params = [];
    for (let i = 0; i < n; i++) {
      const k = start + i;
      params.push(`${prefix}${String(k).padStart(7, '0')}`, `lt-${role}-${k}@loadtest.local`);
      values.push(`($${params.length - 1}, $${params.length}, '${role}'::user_role, 'active'::user_status, NOW())`);
    }
    const res = await db.query(`INSERT INTO users (phone, email, role, status, email_verified_at) VALUES ${values.join(',')} RETURNING id`, params);
    made.push(...res.rows.map((r) => r.id));
  }
  return made;
}

const lawyerIds = await insertUsers('lawyer', LAWYERS, '0150');
for (let start = 0; start < lawyerIds.length; start += 1000) {
  const chunk = lawyerIds.slice(start, start + 1000);
  const values = [];
  const params = [];
  for (const id of chunk) {
    const [lat, lon] = around(pick());
    const reviews = Math.floor(Math.random() * 60);
    const rating = reviews === 0 ? 0 : (3.5 + Math.random() * 1.5).toFixed(2);
    params.push(id, `محامي تجربة ${id.slice(0, 6)}`, lat, lon, rating, reviews, 1 + Math.floor(Math.random() * 20));
    const p = params.length;
    values.push(`($${p - 6}, $${p - 5}, 'approved'::lawyer_approval_status, TRUE, 'APPROVED', $${p - 4}, $${p - 3}, $${p - 2}, $${p - 1}, $${p}, NOW(), NOW(), NOW())`);
    ids.lawyers.push({ id, lat, lon });
  }
  await db.query(
    `INSERT INTO lawyer_profiles (user_id, full_name, approval_status, is_available, urgent_status, latitude, longitude, rating, reviews_count, experience_years, last_location_updated_at, last_active_at, approved_at)
     VALUES ${values.join(',')}`,
    params,
  );
}
const clientIds = await insertUsers('client', CLIENTS, '0120');
for (const id of clientIds) {
  const [lat, lon] = around(pick());
  ids.clients.push({ id, lat, lon });
}

fs.writeFileSync(out, JSON.stringify(ids));
console.log(`seeded ${lawyerIds.length} lawyers and ${clientIds.length} clients into ${url.split('/').pop()}`);
await db.end();
