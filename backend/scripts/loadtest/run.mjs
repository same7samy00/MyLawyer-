// Plays thousands of clients and lawyers against a load-test copy of the server (docs/LOAD_TEST.md).
// Runs on the second server, against the main one over the private link:
//   BASE=http://10.77.0.1:4100/api/v1 JWT_SECRET=... IDS=ids.json REPLICA_URL=postgresql://.../mylawyer_loadtest \
//   node run.mjs [reads|pings|flows|lines|all] > result.json
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import pg from 'pg';

const BASE = new URL(process.env.BASE ?? 'http://10.77.0.1:4100/api/v1');
const SECRET = process.env.JWT_SECRET ?? '';
const IDS = JSON.parse(fs.readFileSync(process.env.IDS ?? 'ids.json', 'utf8'));
const PROBLEM = process.env.PROBLEM ?? 'محضر في قسم الشرطة';
const which = process.argv[2] ?? 'all';
if (!/_loadtest/.test(process.env.REPLICA_URL ?? '')) throw new Error('REPLICA_URL must be a *_loadtest database');

const agent = new http.Agent({ keepAlive: true, maxSockets: 4000 });
const replica = new pg.Pool({ connectionString: process.env.REPLICA_URL, max: 20 });

// --- sign-in tokens, signed like the server does, valid for the whole test
const b64 = (v) => Buffer.from(typeof v === 'string' ? v : JSON.stringify(v)).toString('base64url');
function token(userId, role) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64({ userId, role, status: 'active', iat: now, exp: now + 4 * 3600 });
  const sig = crypto.createHmac('sha256', SECRET).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}
const lawyers = IDS.lawyers.map((l) => ({ ...l, token: token(l.id, 'lawyer') }));
const clients = IDS.clients.map((c) => ({ ...c, token: token(c.id, 'client') }));
const lawyerById = new Map(lawyers.map((l) => [l.id, l]));

// --- one request, timed
function call(method, path, tok, body) {
  return new Promise((resolve) => {
    const payload = body ? JSON.stringify(body) : undefined;
    const started = process.hrtime.bigint();
    const req = http.request({
      host: BASE.hostname, port: BASE.port, path: BASE.pathname + path, method, agent,
      headers: { ...(tok ? { authorization: `Bearer ${tok}` } : {}), ...(payload ? { 'content-type': 'application/json', 'content-length': Buffer.byteLength(payload) } : {}) },
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const ms = Number(process.hrtime.bigint() - started) / 1e6;
        let json = null;
        try { json = JSON.parse(Buffer.concat(chunks).toString()); } catch { /* not json */ }
        resolve({ status: res.statusCode, ms, json });
      });
    });
    req.on('error', (err) => resolve({ status: 0, ms: Number(process.hrtime.bigint() - started) / 1e6, json: { error: err.code } }));
    req.setTimeout(30000, () => req.destroy(new Error('timeout')));
    if (payload) req.write(payload);
    req.end();
  });
}

// --- numbers
class Stats {
  constructor() { this.byName = new Map(); this.errors = new Map(); }
  add(name, r, ok = r.status >= 200 && r.status < 300) {
    const s = this.byName.get(name) ?? { ms: [], ok: 0, fail: 0 };
    s.ms.push(r.ms); ok ? s.ok++ : s.fail++;
    this.byName.set(name, s);
    if (!ok) { const k = `${name} ${r.status} ${r.json?.error ?? ''}`.slice(0, 120); this.errors.set(k, (this.errors.get(k) ?? 0) + 1); }
    return ok;
  }
  report(seconds) {
    const out = {};
    for (const [name, s] of this.byName) {
      const ms = s.ms.sort((a, b) => a - b);
      const at = (p) => Math.round(ms[Math.min(ms.length - 1, Math.floor(ms.length * p))] ?? 0);
      out[name] = { count: ms.length, perSecond: Math.round(ms.length / seconds), ok: s.ok, fail: s.fail, p50: at(0.5), p95: at(0.95), p99: at(0.99), max: Math.round(ms.at(-1) ?? 0) };
    }
    return { endpoints: out, errors: Object.fromEntries([...this.errors].sort((a, b) => b[1] - a[1]).slice(0, 15)) };
  }
}
const rand = (list) => list[Math.floor(Math.random() * list.length)];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function stage(seconds, workers, loop) {
  const stats = new Stats();
  const until = Date.now() + seconds * 1000;
  const started = Date.now();
  await Promise.all(Array.from({ length: workers }, (_, i) => (async () => { while (Date.now() < until) await loop(stats, i); })()));
  const r = stats.report((Date.now() - started) / 1000);
  r.workers = workers; r.seconds = seconds;
  const all = Object.values(r.endpoints);
  r.total = { perSecond: all.reduce((a, e) => a + e.perSecond, 0), fail: all.reduce((a, e) => a + e.fail, 0), count: all.reduce((a, e) => a + e.count, 0) };
  console.error(JSON.stringify({ stage: loop.name, ...r }));
  return r;
}

// --- 1. what an open app reads all day
const READS = [
  ['orders', '/orders'], ['summary', '/notifications/summary'], ['notifications', '/notifications'],
  ['me', '/users/me'], ['top', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`],
];
async function reads(stats) {
  const c = rand(clients);
  const [name, path] = rand(READS);
  stats.add(name, await call('GET', path, c.token));
}

// --- 2. available lawyers sending their place
async function pings(stats) {
  const l = rand(lawyers);
  stats.add('location', await call('POST', '/lawyers/me/location', l.token, { latitude: l.lat + (Math.random() - 0.5) * 0.002, longitude: l.lon + (Math.random() - 0.5) * 0.002 }));
}

// --- 3. the whole «محاميك حالاً» trip, from the request to the review
let nextClient = 0;
const flowTimes = [];
async function flows(stats) {
  const c = clients[nextClient++ % clients.length];
  const t0 = Date.now();
  const sent = await call('POST', '/requests', c.token, { problemType: PROBLEM, problemDescription: 'تجربة ضغط', clientLat: c.lat, clientLon: c.lon, clientAddress: 'تجربة' });
  if (!stats.add('1 request', sent, sent.status === 201)) return sleep(200);
  const requestId = sent.json.data.id;
  let recipients = [];
  for (let i = 0; i < 20 && recipients.length === 0; i++) {
    recipients = (await replica.query('SELECT lawyer_id FROM request_recipients WHERE request_id = $1', [requestId])).rows.map((r) => r.lawyer_id);
    if (recipients.length === 0) await sleep(100);
  }
  if (recipients.length === 0) { stats.add('2 lawyers reached', { status: 0, ms: Date.now() - t0, json: { error: 'no lawyer reached' } }, false); await call('POST', `/requests/${requestId}/cancel`, c.token, {}); return; }
  stats.add('2 lawyers reached', { status: 200, ms: Date.now() - t0 });
  const min = Number((await replica.query('SELECT min_price FROM service_requests WHERE id = $1', [requestId])).rows[0]?.min_price ?? 300);
  // Only the test lawyers: the database may hold a few others
  const offering = recipients.filter((id) => lawyerById.has(id)).slice(0, 3);
  if (offering.length === 0) { await call('POST', `/requests/${requestId}/cancel`, c.token, {}); return; }
  await Promise.all(offering.map(async (id) => stats.add('3 offer', await call('POST', `/requests/${requestId}/offer`, lawyerById.get(id).token, { price: min }))));
  const seen = await call('GET', `/requests/${requestId}`, c.token);
  stats.add('4 see offers', seen);
  const offer = seen.json?.data?.offers?.[0];
  if (!offer) { await call('POST', `/requests/${requestId}/cancel`, c.token, {}); return; }
  const chosen = await call('POST', `/requests/${requestId}/offers/${offer.id}/select`, c.token, {});
  if (!stats.add('5 choose', chosen)) { await call('POST', `/requests/${requestId}/cancel`, c.token, {}); return; }
  const orderId = chosen.json.data.orderId;
  const lawyer = lawyerById.get(chosen.json.data.lawyerId);
  if (!stats.add('6 pay', await call('POST', `/orders/${orderId}/confirm-payment`, c.token, {}))) return;
  if (!stats.add('7 arrive', await call('POST', `/orders/${orderId}/arrive`, lawyer.token, { latitude: c.lat, longitude: c.lon }))) return;
  if (!stats.add('8 complete', await call('POST', `/orders/${orderId}/complete`, lawyer.token, {}))) return;
  stats.add('9 review', await call('POST', `/orders/${orderId}/review`, c.token, { rating: 4 + Math.round(Math.random()) }), true);
  flowTimes.push(Date.now() - t0);
}

// --- 4. open live lines: every open app keeps one
async function lines(count, holdSeconds) {
  const opened = [];
  let ok = 0, fail = 0;
  const started = Date.now();
  for (let i = 0; i < count; i++) {
    const c = clients[i % clients.length];
    opened.push(new Promise((resolve) => {
      const req = http.request({ host: BASE.hostname, port: BASE.port, path: `${BASE.pathname}/events`, method: 'GET', headers: { authorization: `Bearer ${c.token}` } }, (res) => {
        if (res.statusCode === 200) ok++; else fail++;
        res.on('data', () => {});
        resolve(req);
      });
      req.on('error', () => { fail++; resolve(req); });
      req.end();
    }));
    if (i % 200 === 199) await sleep(50);
  }
  const reqs = await Promise.all(opened);
  const openMs = Date.now() - started;
  console.error(JSON.stringify({ stage: 'lines', count, ok, fail, secondsToOpen: Math.round(openMs / 100) / 10 }));
  await sleep(holdSeconds * 1000);
  for (const r of reqs) r.destroy();
  return { asked: count, ok, fail, secondsToOpen: Math.round(openMs / 100) / 10 };
}

const result = { startedAt: new Date().toISOString(), lawyers: lawyers.length, clients: clients.length };
if (which === 'reads' || which === 'all') {
  result.reads = [];
  for (const w of [50, 200, 500, 1000, 2000]) result.reads.push(await stage(25, w, reads));
}
if (which === 'pings' || which === 'all') {
  result.pings = [];
  for (const w of [100, 500, 1000]) result.pings.push(await stage(20, w, pings));
}
if (which === 'flows' || which === 'all') {
  result.flows = [];
  for (const w of process.env.SMOKE ? [2] : [10, 50, 100, 200, 400]) {
    flowTimes.length = 0;
    const r = await stage(process.env.SMOKE ? 15 : 45, w, flows);
    const t = flowTimes.sort((a, b) => a - b);
    r.completedTrips = t.length;
    r.tripsPerMinute = Math.round(t.length / (r.seconds / 60));
    r.tripSecondsP50 = t.length ? Math.round(t[Math.floor(t.length * 0.5)] / 100) / 10 : null;
    r.tripSecondsP95 = t.length ? Math.round(t[Math.floor(t.length * 0.95)] / 100) / 10 : null;
    result.flows.push(r);
    await sleep(5000);
  }
}
if (which === 'lines' || which === 'all') {
  result.lines = [];
  for (const n of [2000, 5000, 10000]) { result.lines.push(await lines(n, 20)); await sleep(5000); }
}
result.finishedAt = new Date().toISOString();
console.log(JSON.stringify(result, null, 1));
await replica.end();
process.exit(0);
