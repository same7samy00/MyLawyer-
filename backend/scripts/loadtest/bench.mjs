// Load test of the isolated copy on 127.0.0.1:4100, run on the server itself so the network is not the limit.
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
      const row = { name, connections: opts.connections, rps: Math.round(r.requests.average), p50: r.latency.p50, p90: r.latency.p90, p99: r.latency.p99, max: r.latency.max, codes, errors: r.errors, timeouts: r.timeouts, kbPerReq: r.requests.total ? Math.round(r.throughput.total / r.requests.total / 102.4) / 10 : 0, cpu: Math.round(peak.cpu), rssMb: Math.round(peak.rss), pg: peak.pg };
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
const clients = (await db.query(`SELECT id FROM users WHERE email LIKE 'lt-client-%' ORDER BY email`)).rows.map((r) => token(r.id, 'client'));
const lawyers = (await db.query(`SELECT id FROM users WHERE email LIKE 'lt-lawyer-%' ORDER BY email`)).rows.map((r) => ({ id: r.id, token: token(r.id, 'lawyer') }));
let turn = 0;
const rotate = (list) => (req) => ({ ...req, headers: { ...req.headers, authorization: `Bearer ${list[turn++ % list.length]}` } });
const post = (path, tok, body) => fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${tok}` }, body: JSON.stringify(body) });

// The same test at rising concurrency, to find where answers start slowing down or failing
const RAMP = (process.env.RAMP || '100,300,600,1000').split(',').map(Number);
const ramp = async (name, opts) => { for (const c of RAMP) await cannon(`${name} @${c}`, { ...opts, connections: c }); };

const scenarios = {
  health: () => ramp('health', { url: `${API}/health` }),
  nearby50: () => ramp('nearby limit=50 (new apps)', { url: `${API}/lawyers/nearby?lat=${cairo.lat}&lon=${cairo.lon}&limit=50` }),
  nearby1000: () => cannon('nearby limit=1000 (old apps)', { url: `${API}/lawyers/nearby?lat=${cairo.lat}&lon=${cairo.lon}`, connections: 50 }),
  orders: () => ramp('orders list (signed in)', { url: `${API}/orders`, requests: [{ setupRequest: rotate(clients) }] }),
  me: () => ramp('users/me (signed in)', { url: `${API}/users/me`, requests: [{ setupRequest: rotate(clients) }] }),
  notifications: () => cannon('notifications (signed in)', { url: `${API}/notifications`, connections: 300, requests: [{ setupRequest: rotate(clients) }] }),
  requests: async () => {
    const tokens = clients.slice(0, Number(process.env.REQUESTS || 5000));
    await burst('create request -> 5 nearest lawyers (writes)', tokens, 100, (tok) => post('/requests', tok, {
      problemType: 'محضر في قسم الشرطة', problemDescription: 'اختبار حمل', clientLat: cairo.lat + (Math.random() - 0.5) * 0.5, clientLon: cairo.lon + (Math.random() - 0.5) * 0.5,
    }));
    const pairs = (await db.query(`SELECT rr.request_id, rr.lawyer_id, r.min_price FROM request_recipients rr JOIN service_requests r ON r.id = rr.request_id WHERE r.status = 'OPEN' LIMIT 10000`)).rows;
    const byId = new Map(lawyers.map((l) => [l.id, l.token]));
    await burst('lawyer offer on a request (writes)', pairs, 100, (p) => post(`/requests/${p.request_id}/offer`, byId.get(p.lawyer_id), { price: Math.ceil(Number(p.min_price)) }));
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
  tiles: () => {
    const z = [12, 13, 14, 15];
    return ramp('map tiles, renderer direct (no Nginx cache)', {
      url: 'http://127.0.0.1:3000',
      requests: [{ setupRequest: (req) => {
        const zz = z[Math.floor(Math.random() * z.length)]; const n = 2 ** zz;
        const lat = cairo.lat + (Math.random() - 0.5) * 0.4; const lon = cairo.lon + (Math.random() - 0.5) * 0.4;
        const x = Math.floor(((lon + 180) / 360) * n); const r = (lat * Math.PI) / 180;
        const y = Math.floor(((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * n);
        return { ...req, path: `/styles/mylawyer/256/${zz}/${x}/${y}@2x.webp` };
      } }],
    });
  },
  routes: () => ramp('road time (OSRM direct)', {
    url: 'http://127.0.0.1:5000',
    requests: [{ setupRequest: (req) => {
      const p = () => `${(cairo.lon + (Math.random() - 0.5) * 0.4).toFixed(5)},${(cairo.lat + (Math.random() - 0.5) * 0.4).toFixed(5)}`;
      return { ...req, path: `/route/v1/driving/${p()};${p()}?overview=false` };
    } }],
  }),
};

for (const [key, go] of Object.entries(scenarios)) {
  if (only === 'all' || only === key) await go();
}
await db.end();
fs.writeFileSync('/tmp/lt/results.json', JSON.stringify(results, null, 1));
console.log('DONE');
