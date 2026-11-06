import { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { config } from '../../config/index.js';
import { dbPool } from '../../database/index.js';
import { HttpError } from '../../utils/http.js';
import { generateSecureToken, hashPassword, hashSha256, isValidEgyptianPhone, sanitizeText, verifyPassword } from '../../utils/security.js';

// "Where I'll be": lawyers say which courts they'll be at, and anyone can find them and call.
// Its accounts are its own, so the page works for lawyers who don't use the app.

const SESSION_DAYS = 90;
const MAX_ACTIVE_ENTRIES = 20;
const MAX_DAYS_AHEAD = 60;
const MAX_PLACES = 10;
const TODAY = `(NOW() AT TIME ZONE 'Africa/Cairo')::date`;

/// "٠١٠١٢٣٤٥٦٧٨" typed on an Arabic keyboard is the same number as "01012345678"
function latinDigits(value: string) {
  return value.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0)).replace(/\s|-/g, '');
}

const phoneField = (message: string) => z.string().transform(latinDigits).refine(isValidEgyptianPhone, { message });
const text = (max: number, message: string) => z.string().transform((v) => sanitizeText(v, max)).refine((v) => v.length >= 2, { message });
const time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'الوقت غير صحيح' });

const registerSchema = z.object({
  fullName: text(80, 'اكتب الاسم'),
  phone: phoneField('رقم الهاتف لازم يكون رقم مصري من 11 رقم'),
  whatsapp: phoneField('رقم الواتساب لازم يكون رقم مصري من 11 رقم'),
  password: z.string().min(6, { message: 'كلمة السر 6 حروف أو أرقام على الأقل' }).max(100),
});

const loginSchema = z.object({
  phone: z.string().transform(latinDigits),
  password: z.string().max(100),
});

const entrySchema = z.object({
  city: text(40, 'اختار المدينة'),
  places: z.array(z.string().transform((v) => sanitizeText(v, 80)))
    .transform((list) => [...new Set(list.filter((p) => p.length >= 2))])
    .refine((list) => list.length >= 1, { message: 'ضيف محكمة أو مكان واحد على الأقل' })
    .refine((list) => list.length <= MAX_PLACES, { message: `أقصى عدد ${MAX_PLACES} أماكن في اليوم` }),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { message: 'اختار التاريخ' }),
  timeFrom: time.optional().nullable(),
  timeTo: time.optional().nullable(),
  note: z.string().max(200).optional().nullable(),
}).refine((e) => !e.timeFrom || !e.timeTo || e.timeTo > e.timeFrom, { message: 'وقت النهاية لازم يكون بعد وقت البداية', path: ['timeTo'] });

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) throw new HttpError(400, result.error.issues[0]?.message || 'البيانات غير صحيحة');
  return result.data;
}

// The same word is found however it was written: أ إ آ ٱ as ا, ؤ as و, ئ and ى as ي, ة as ه,
// Arabic digits as Latin, and no hamza, tashkeel or tatweel. The letters after the mapped ones are dropped.
const FROM = 'أإآٱؤئىة٠١٢٣٤٥٦٧٨٩' + 'ءـًٌٍَُِّْٰ';
const TO = 'ااااوييه0123456789';
const normalized = (expression: string) => `translate(lower(${expression}), '${FROM}', '${TO}')`;

export function normalizeArabic(value: string) {
  let out = '';
  for (const ch of value.toLowerCase()) {
    const at = FROM.indexOf(ch);
    out += at < 0 ? ch : (TO[at] ?? '');
  }
  return out;
}

/// Every word must appear somewhere, as a whole word or part of one, so "شرق اسكندريه" finds
/// "محكمة شرق الإسكندرية الابتدائية". A leading "ال" is dropped so "الزقازيق" also finds "زقازيق".
function searchWords(q: string) {
  return normalizeArabic(q)
    .replace(/[%_\\]/g, ' ')
    .split(/[\s,،.\-/]+/)
    .map((w) => (w.length > 3 && w.startsWith('ال') ? w.slice(2) : w))
    .filter((w) => w.length > 0)
    .slice(0, 6);
}

const HAYSTACK = normalized(`a.full_name || ' ' || e.city || ' ' || array_to_string(e.places, ' ') || ' ' || COALESCE(e.note, '')`);

const ENTRY_COLUMNS = `
  e.id, a.full_name AS name, a.phone, a.whatsapp, e.city, e.places,
  to_char(e.day, 'YYYY-MM-DD') AS day, to_char(e.time_from, 'HH24:MI') AS "timeFrom",
  to_char(e.time_to, 'HH24:MI') AS "timeTo", e.note`;

async function startSession(accountId: string) {
  const token = generateSecureToken();
  await dbPool.query(
    `INSERT INTO presence_sessions (token_hash, account_id, expires_at) VALUES ($1, $2, NOW() + make_interval(days => $3))`,
    [hashSha256(token), accountId, SESSION_DAYS]
  );
  return token;
}

async function signedIn(request: FastifyRequest) {
  const token = request.headers.authorization?.replace(/^Bearer\s+/i, '');
  if (token) {
    const res = await dbPool.query(
      `SELECT a.id, a.full_name, a.phone, a.whatsapp FROM presence_sessions s
       JOIN presence_accounts a ON a.id = s.account_id
       WHERE s.token_hash = $1 AND s.expires_at > NOW()`,
      [hashSha256(token)]
    );
    if (res.rows[0]) return res.rows[0] as { id: string; full_name: string; phone: string; whatsapp: string };
  }
  throw new HttpError(401, 'سجل دخولك الأول');
}

const accountView = (a: { full_name: string; phone: string; whatsapp: string }) => ({ fullName: a.full_name, phone: a.phone, whatsapp: a.whatsapp });

export async function presenceRoutes(fastify: FastifyInstance) {
  // Guessing passwords is slow, while the app's own limit stays as it is
  const strict = { config: { rateLimit: { max: config.nodeEnv === 'test' ? 100000 : 10, timeWindow: '1 minute' } } };

  fastify.post('/register', strict, async (request, reply) => {
    const body = parse(registerSchema, request.body);
    const taken = await dbPool.query('SELECT 1 FROM presence_accounts WHERE phone = $1', [body.phone]);
    if (taken.rows[0]) throw new HttpError(409, 'الرقم ده متسجل قبل كده، سجل دخول');

    const res = await dbPool.query(
      `INSERT INTO presence_accounts (full_name, phone, whatsapp, password_hash) VALUES ($1, $2, $3, $4)
       ON CONFLICT (phone) DO NOTHING RETURNING id, full_name, phone, whatsapp`,
      [body.fullName, body.phone, body.whatsapp, await hashPassword(body.password)]
    );
    if (!res.rows[0]) throw new HttpError(409, 'الرقم ده متسجل قبل كده، سجل دخول');
    const token = await startSession(res.rows[0].id);
    return reply.status(201).send({ success: true, data: { token, account: accountView(res.rows[0]) } });
  });

  fastify.post('/login', strict, async (request) => {
    const body = parse(loginSchema, request.body);
    const res = await dbPool.query('SELECT id, full_name, phone, whatsapp, password_hash FROM presence_accounts WHERE phone = $1', [body.phone]);
    const account = res.rows[0];
    if (!account || !(await verifyPassword(account.password_hash, body.password))) {
      throw new HttpError(401, 'رقم الهاتف أو كلمة السر غلط');
    }
    await dbPool.query('DELETE FROM presence_sessions WHERE account_id = $1 AND expires_at < NOW()', [account.id]);
    return { success: true, data: { token: await startSession(account.id), account: accountView(account) } };
  });

  fastify.post('/logout', async (request) => {
    const token = request.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (token) await dbPool.query('DELETE FROM presence_sessions WHERE token_hash = $1', [hashSha256(token)]);
    return { success: true };
  });

  fastify.get('/me', async (request) => ({ success: true, data: accountView(await signedIn(request)) }));

  // Public: everyone who will be somewhere from today on, nearest day first
  fastify.get('/entries', async (request) => {
    const query = request.query as { q?: string; city?: string; day?: string };
    const words = searchWords(sanitizeText(query.q || '', 80));
    const city = normalizeArabic(sanitizeText(query.city || '', 40)).trim();
    const day = /^\d{4}-\d{2}-\d{2}$/.test(query.day || '') ? query.day : null;

    const res = await dbPool.query(
      `SELECT ${ENTRY_COLUMNS}
       FROM presence_entries e JOIN presence_accounts a ON a.id = e.account_id
       WHERE e.day >= ${TODAY}
         AND NOT EXISTS (SELECT 1 FROM unnest($1::text[]) w WHERE ${HAYSTACK} NOT LIKE '%' || w || '%')
         AND ($2 = '' OR ${normalized('e.city')} = $2)
         AND ($3::date IS NULL OR e.day = $3::date)
       ORDER BY e.day, e.time_from NULLS LAST, e.created_at
       LIMIT 300`,
      [words, city, day]
    );
    return { success: true, data: res.rows };
  });

  // The cities and places already written, so people pick the same name instead of a new spelling
  fastify.get('/suggestions', async () => {
    const res = await dbPool.query(
      `SELECT city, place, COUNT(*)::int AS uses FROM presence_entries, unnest(places) AS place
       WHERE day >= ${TODAY} - 90 GROUP BY city, place ORDER BY uses DESC LIMIT 500`
    );
    return { success: true, data: res.rows.map((r) => ({ city: r.city, place: r.place })) };
  });

  fastify.get('/mine', async (request) => {
    const account = await signedIn(request);
    const res = await dbPool.query(
      `SELECT ${ENTRY_COLUMNS} FROM presence_entries e JOIN presence_accounts a ON a.id = e.account_id
       WHERE e.account_id = $1 AND e.day >= ${TODAY} ORDER BY e.day, e.time_from NULLS LAST`,
      [account.id]
    );
    return { success: true, data: res.rows };
  });

  fastify.post('/entries', async (request, reply) => {
    const account = await signedIn(request);
    const body = parse(entrySchema, request.body);

    const range = await dbPool.query(`SELECT $1::date >= ${TODAY} AS from_today, $1::date <= ${TODAY} + $2::int AS near`, [body.day, MAX_DAYS_AHEAD]);
    if (!range.rows[0].from_today) throw new HttpError(400, 'اختار النهارده أو يوم جاي');
    if (!range.rows[0].near) throw new HttpError(400, `التاريخ لازم يكون خلال ${MAX_DAYS_AHEAD} يوم`);

    const active = await dbPool.query(`SELECT COUNT(*)::int AS n FROM presence_entries WHERE account_id = $1 AND day >= ${TODAY}`, [account.id]);
    if (active.rows[0].n >= MAX_ACTIVE_ENTRIES) throw new HttpError(400, `عندك ${MAX_ACTIVE_ENTRIES} تواجد جاي، امسح واحد الأول`);

    const res = await dbPool.query(
      `INSERT INTO presence_entries (account_id, city, places, day, time_from, time_to, note)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [account.id, body.city, body.places, body.day, body.timeFrom || null, body.timeTo || null, sanitizeText(body.note || '', 200) || null]
    );
    return reply.status(201).send({ success: true, data: { id: res.rows[0].id } });
  });

  fastify.delete('/entries/:id', async (request) => {
    const account = await signedIn(request);
    const { id } = request.params as { id: string };
    const res = await dbPool.query('DELETE FROM presence_entries WHERE id = $1 AND account_id = $2 RETURNING id', [id, account.id]);
    if (!res.rows[0]) throw new HttpError(404, 'التواجد ده مش موجود');
    return { success: true };
  });
}
