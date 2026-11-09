// Load test of the isolated copy on 127.0.0.1:4100, run on the backend server itself so the network is not the limit.
// The maps server is reached over the internet through Nginx and https, the way the app reaches it.
// A ramp stops when errors pass 5% or p99 passes 10 s, and the whole run stops if production is not UP.
// Prints numbers only, never secrets.
import autocannon from 'autocannon';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';

const require = createRequire('/opt/mylawyer-loadtest/package.json');
const pg = require('pg');
const env = Object.fromEntries(fs.readFileSync('/opt/mylawyer-loadtest/.env', 'utf-8').split('\n').filter(Boolean).map((l) => [l.split('=')[0], l.slice(l.indexOf('=') + 1)]));
const API = 'http://127.0.0.1:4100/api/v1';
const DUR = Number(process.env.DUR || 20);
const only = process.argv[2] || 'all';
const cairo = { lat: 30.0444, lon: 31.2357 };
const results = [];

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
function token(userId, role) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64({ userId, role, status: 'active', iat: now, exp: now + 7200 });
  const sig = crypto.createHmac('sha256', env.JWT_SECRET).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}

// Server resources while a test runs: CPU of the whole machine, memory of the test copy, database connections
function cpuTimes() {
  const [, ...v] = fs.readFileSync('/proc/stat', 'utf-8').split('\n')[0].trim().split(/\s+/).map(Number);
  const idle = v[3] + v[4];
  return { idle, total: v.reduce((a, b) => a + b, 0) };
}
function sampler() {
  let last = cpuTimes();
  const peak = { cpu: 0, rss: 0, pg: 0, load: 0 };
  const timer = setInterval(() => {
    const now = cpuTimes();
    const cpu = 100 * (1 - (now.idle - last.idle) / (now.total - last.total));
    last = now;
    let rss = 0;
    try { rss = Number(execSync(`ps -o rss= --ppid $(systemctl show -p MainPID --value mylawyer-loadtest) | awk '{s+=$1} END {print s}'`).toString().trim()) / 1024; } catch {}
    let pgc = 0;
    try { pgc = Number(execSync(`sudo -u postgres psql -Atc "select count(*) from pg_stat_activity where datname='mylawyer_loadtest'"`).toString().trim()); } catch {}
    const load = Number(fs.readFileSync('/proc/loadavg', 'utf-8').split(' ')[0]);
    peak.cpu = Math.max(peak.cpu, cpu); peak.rss = Math.max(peak.rss, rss); peak.pg = Math.max(peak.pg, pgc); peak.load = Math.max(peak.load, load);
  }, 1000);
  return () => { clearInterval(timer); return peak; };
}

function cannon(name, opts) {
  return new Promise((resolve) => {
    const stop = sampler();
    autocannon({ duration: DUR, timeout: 10, ...opts }, (err, r) => {
      const peak = stop();
      if (err) { console.log(name, 'ERROR', err.message); return resolve(); }
      const codes = Object.entries(r.statusCodeStats || {}).map(([c, v]) => `${c}:${v.count}`).join(' ');
      const codesRaw = Object.fromEntries(Object.entries(r.statusCodeStats || {}).map(([c, v]) => [c, v.count]));
      const row = { name, connections: opts.connections, rps: Math.round(r.requests.average), total: r.requests.total, codesRaw, p50: r.latency.p50, p90: r.latency.p90, p97_5: r.latency.p97_5, p99: r.latency.p99, max: r.latency.max, codes, errors: r.errors, timeouts: r.timeouts, kbPerReq: r.requests.total ? Math.round(r.throughput.total / r.requests.total / 102.4) / 10 : 0, cpu: Math.round(peak.cpu), rssMb: Math.round(peak.rss), pg: peak.pg };
      results.push(row);
      console.log(JSON.stringify(row));
      resolve(row);
    });
  });
}

// Many requests at a given concurrency, each one a different person, for writes that must not repeat
async function burst(name, items, concurrency, send) {
  const stop = sampler();
  const lat = [];
  let ok = 0; let fail = 0; const codes = {};
  const started = Date.now();
  let i = 0;
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (i < items.length) {
      const item = items[i++];
      const t = Date.now();
      try {
        const res = await send(item);
        codes[res.status] = (codes[res.status] || 0) + 1;
        if (res.status < 300) ok++; else fail++;
      } catch { fail++; }
      lat.push(Date.now() - t);
    }
  }));
  const secs = (Date.now() - started) / 1000;
  const peak = stop();
  lat.sort((a, b) => a - b);
  const q = (p) => lat[Math.min(lat.length - 1, Math.floor(lat.length * p))];
  const row = { name, connections: concurrency, total: items.length, ok, fail, codes: Object.entries(codes).map(([c, n]) => `${c}:${n}`).join(' '), perSecond: Math.round(items.length / secs), p50: q(0.5), p90: q(0.9), p99: q(0.99), max: lat[lat.length - 1], cpu: Math.round(peak.cpu), rssMb: Math.round(peak.rss), pg: peak.pg };
  results.push(row);
  console.log(JSON.stringify(row));
  return row;
}

const db = new pg.Pool({ connectionString: env.DATABASE_URL, max: 2 });
// One admin for the panel routes, in the test copy only
await db.query(`INSERT INTO users (phone, email, role, status, full_name, email_verified_at) VALUES ('01000000000', 'lt-admin@loadtest.invalid', 'admin', 'active', 'أدمن تجريبي', NOW()) ON CONFLICT DO NOTHING`).catch(() => {});
const admin = token((await db.query(`SELECT id FROM users WHERE email = 'lt-admin@loadtest.invalid'`)).rows[0].id, 'admin');
const clients = (await db.query(`SELECT id FROM users WHERE email LIKE 'lt-client-%' ORDER BY email`)).rows.map((r) => token(r.id, 'client'));
const lawyers = (await db.query(`SELECT id FROM users WHERE email LIKE 'lt-lawyer-%' ORDER BY email`)).rows.map((r) => ({ id: r.id, token: token(r.id, 'lawyer') }));
let turn = 0;
const rotate = (list) => (req) => ({ ...req, headers: { ...req.headers, authorization: `Bearer ${list[turn++ % list.length]}` } });
const post = (path, tok, body) => fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${tok}` }, body: JSON.stringify(body) });

// The same test at rising concurrency, to find where answers start slowing down or failing
const RAMP = (process.env.RAMP || '10,25,50,100,250,500,1000,2000,4000').split(',').map(Number);
async function prodUp() {
  try { return (await (await fetch('http://127.0.0.1:4000/api/v1/health')).json()).status === 'UP'; } catch { return false; }
}
function broke(row) {
  if (!row) return true;
  const total = row.total || 1;
  const bad = row.errors + row.timeouts + Object.entries(row.codesRaw || {}).filter(([c]) => Number(c) >= 500).reduce((a, [, n]) => a + n, 0);
  return bad > total * 0.05 || row.p99 > 10000;
}
const ramp = async (name, opts, levels = RAMP) => {
  for (const c of levels) {
    if (!(await prodUp())) { console.log(JSON.stringify({ name, stopped: 'production not UP' })); process.exit(2); }
    const row = await cannon(`${name} @${c}`, { ...opts, connections: c });
    if (broke(row)) { console.log(JSON.stringify({ name, stoppedAt: c, reason: 'errors over 5% or p99 over 10 s' })); break; }
  }
};

const scenarios = {
  health: () => ramp('health', { url: `${API}/health` }),
  orders: () => ramp('orders list (signed in)', { url: `${API}/orders`, requests: [{ setupRequest: rotate(clients) }] }),
  me: () => ramp('users/me (signed in)', { url: `${API}/users/me`, requests: [{ setupRequest: rotate(clients) }] }),
  notifications: () => cannon('notifications (signed in)', { url: `${API}/notifications`, connections: 300, requests: [{ setupRequest: rotate(clients) }] }),
  requests: async () => {
    // The server hides a lawyer silent for 10 minutes, so the test lawyers report in right before the writes
    await db.query(`UPDATE lawyer_profiles SET last_location_updated_at = NOW(), last_active_at = NOW(), is_available = TRUE, availability_off_reason = NULL`);
    const tokens = clients.slice(0, Number(process.env.REQUESTS || 5000));
    await burst('POST /requests (writes, lawyers notified)', tokens, Number(process.env.WRITE_C || 100), (tok) => post('/requests', tok, {
      problemType: 'محضر في قسم الشرطة', problemDescription: 'اختبار حمل', clientLat: cairo.lat + (Math.random() - 0.5) * 0.5, clientLon: cairo.lon + (Math.random() - 0.5) * 0.5,
    }));
    const pairs = (await db.query(`SELECT rr.request_id, rr.lawyer_id, r.min_price FROM request_recipients rr JOIN service_requests r ON r.id = rr.request_id WHERE r.status = 'OPEN' LIMIT 10000`)).rows;
    const byId = new Map(lawyers.map((l) => [l.id, l.token]));
    await burst('POST /requests/:id/offer (writes)', pairs, Number(process.env.WRITE_C || 100), (p) => post(`/requests/${p.request_id}/offer`, byId.get(p.lawyer_id), { price: Math.ceil(Number(p.min_price)) }));
    await cannon('lawyer incoming requests (signed in)', { url: `${API}/requests/incoming`, connections: 100, requests: [{ setupRequest: rotate(lawyers.map((l) => l.token)) }] });
  },
  live: async () => {
    const lines = [];
    const agent = new http.Agent({ keepAlive: true, maxSockets: Infinity });
    const target = Math.min(Number(process.env.LINES || 10000), clients.length);
    const stop = sampler();
    let open = 0; let failed = 0;
    await Promise.all(clients.slice(0, target).map((tok) => new Promise((resolve) => {
      const req = http.get(`${API}/events`, { agent, headers: { authorization: `Bearer ${tok}`, accept: 'text/event-stream' } }, (res) => {
        if (res.statusCode === 200) open++; else failed++;
        lines.push(res); res.on('data', () => {}); resolve();
      });
      req.on('error', () => { failed++; resolve(); });
      req.setTimeout(15000, () => { failed++; resolve(); });
      lines.push(req);
    })));
    console.log(JSON.stringify({ name: 'live lines open', open, failed }));
    const health = await cannon(`health while ${open} live lines are open`, { url: `${API}/health`, connections: 300, duration: 10 });
    const peak = stop();
    results.push({ name: 'live lines', open, failed, cpu: Math.round(peak.cpu), rssMb: Math.round(peak.rss), pg: peak.pg, healthRps: health?.rps, healthP99: health?.p99 });
    console.log(JSON.stringify(results[results.length - 1]));
    for (const l of lines) l.destroy?.();
    agent.destroy();
  },
  // Every read route the app and the panel use, each as its own ramp
  reads: async () => {
    const C = (path) => ({ url: API + path, requests: [{ setupRequest: rotate(clients) }] });
    const L = (path) => ({ url: API + path, requests: [{ setupRequest: rotate(lawyers.map((l) => l.token)) }] });
    const A = (path) => ({ url: API + path, headers: { authorization: `Bearer ${admin}` } });
    const cells = [];
    for (let x = 310; x <= 315; x++) for (let y = 297; y <= 302; y++) cells.push(`${x}_${y}`);
    const list = {
      'GET /users/me': C('/users/me'), 'GET /orders': C('/orders'), 'GET /orders/wallet/me': C('/orders/wallet/me'),
      'GET /notifications': C('/notifications'), 'GET /notifications/summary': C('/notifications/summary'),
      'GET /consultations': C('/consultations'), 'GET /consultations/settings': C('/consultations/settings'),
      'GET /support/tickets': C('/support/tickets'), 'GET /wallet/payments': C('/wallet/payments'), 'GET /wallet/limits': C('/wallet/limits'),
      'GET /wallet/recipient': C('/wallet/recipient?phone=01180000001'), 'GET /requests/range': C('/requests/range'),
      'GET /lawyers/map (36 small squares)': { url: `${API}/lawyers/map?size=s&cells=${cells.join(',')}` },
      'GET /lawyers/map (big squares)': { url: `${API}/lawyers/map?size=l&cells=62_59,62_60,63_59,63_60` },
      'GET /lawyers/top': { url: `${API}/lawyers/top?governorate=${encodeURIComponent('القاهرة')}` },
      'GET /lawyers/me': L('/lawyers/me'), 'GET /requests/incoming': L('/requests/incoming'),
      'GET /admin/overview': A('/admin/overview'), 'GET /admin/users': A('/admin/users'), 'GET /admin/orders': A('/admin/orders'),
      'GET /admin/money': A('/admin/money'), 'GET /admin/support': A('/admin/support'), 'GET /admin/consultations': A('/admin/consultations'),
      'GET /admin/reviews': A('/admin/reviews'), 'GET /admin/search': A('/admin/search?q=0118'), 'GET /admin/actions': A('/admin/actions'),
      'GET /admin/prices': A('/admin/prices'), 'GET /admin/urgent-applications': A('/admin/urgent-applications'),
      'GET /admin-panel (page)': { url: `${API}/admin-panel` }, 'GET /health': { url: `${API}/health` },
    };
    const only = process.env.ROUTE;
    const levels = (process.env.READ_RAMP || '50,250,1000').split(',').map(Number);
    for (const [name, opts] of Object.entries(list)) {
      if (!only || name.includes(only)) await ramp(name, opts, levels);
    }
  },
  // Sign in: the slowest single step on purpose (argon2), every login a different client
  login: async () => {
    const argon2 = require('argon2');
    const hash = await argon2.hash('LoadTest-2026');
    // Passwords live in user_credentials, one row per user
    await db.query(`INSERT INTO user_credentials (user_id, password_hash) SELECT id, $1 FROM users WHERE email LIKE 'lt-client-%' ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash`, [hash]);
    const phones = (await db.query(`SELECT phone FROM users WHERE email LIKE 'lt-client-%' ORDER BY email LIMIT 3000`)).rows.map((r) => r.phone);
    for (const c of [10, 50, 100, 200]) {
      await burst(`POST /auth/login @${c}`, phones.slice(0, Math.min(phones.length, c * 15)), c, (phone) => fetch(API + '/auth/login', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ identifier: phone, password: 'LoadTest-2026' }),
      }));
    }
  },
  // The shared TomTom map cache on our server, the way phones reach it. Squares not yet cached are fetched
  // from TomTom once, so a first run around Cairo also fills the cache
  maps: () => ramp('map squares over https (shared cache)', {
    url: 'https://my-lawyer.online',
    requests: [{ setupRequest: (req) => {
      const zz = [12, 13, 14, 15][Math.floor(Math.random() * 4)]; const n = 2 ** zz;
      const lat = cairo.lat + (Math.random() - 0.5) * 0.4; const lon = cairo.lon + (Math.random() - 0.5) * 0.4;
      const x = Math.floor(((lon + 180) / 360) * n); const r = (lat * Math.PI) / 180;
      const y = Math.floor(((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * n);
      return { ...req, path: `/map/t/${zz}/${x}/${y}.png` };
    } }],
  }, [10, 50, 100, 250, 500]),
  // A real crowd at the same time, by share of calls (assumed, there is no real usage data yet):
  // opening the app 20%, orders 20%, unread count 15%, map squares 15%, notifications 10%,
  // lawyer incoming requests 10%, governorate list 5%, wallet 5%
  mix: () => {
    const cells = []; for (let x = 311; x <= 314; x++) for (let y = 298; y <= 301; y++) cells.push(`${x}_${y}`);
    const lawyerTokens = lawyers.map((l) => l.token);
    const pick = [
      [20, '/users/me', clients], [20, '/orders', clients], [15, '/notifications/summary', clients],
      [15, `/lawyers/map?size=s&cells=${cells.join(',')}`, null], [10, '/notifications', clients],
      [10, '/requests/incoming', lawyerTokens], [5, `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, null], [5, '/wallet/payments', clients],
    ];
    const total = pick.reduce((a, [w]) => a + w, 0);
    return ramp('realistic mix', {
      url: API,
      requests: [{ setupRequest: (req) => {
        let r = Math.random() * total; let row = pick[0];
        for (const p of pick) { if ((r -= p[0]) < 0) { row = p; break; } }
        const headers = { ...req.headers };
        if (row[2]) headers.authorization = `Bearer ${row[2][turn++ % row[2].length]}`; else delete headers.authorization;
        return { ...req, path: '/api/v1' + row[1], headers };
      } }],
    });
  },
};

for (const [key, go] of Object.entries(scenarios)) {
  if (only === 'all' || only === key) await go();
}
await db.end();
fs.writeFileSync('/tmp/lt/results.json', JSON.stringify(results, null, 1));
console.log('DONE');
