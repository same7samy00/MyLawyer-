// Writes demo-lawyers.sql: 1000 demo lawyers placed like real ones, inside real Egyptian cities and towns
// (from the app's places file), more in the big cities, each with its governorate, a believable rating and
// reviews. Run: node backend/scripts/demo/build-demo-lawyers.mjs, then load the SQL on the server.
// Same seed every run, so the file only changes when this script changes.
import fs from 'fs';

const places = JSON.parse(fs.readFileSync(new URL('../../../assets/data/egypt_places.json', import.meta.url), 'utf8'));
let seed = 20261109;
const rand = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);

const first = ['أحمد','محمد','محمود','مصطفى','إبراهيم','علي','حسن','حسين','خالد','عمرو','طارق','وليد','هشام','ياسر','كريم','سامح','عادل','أشرف','شريف','تامر','رامي','مينا','بيتر','جرجس','عبد الرحمن','عبد الله','يوسف','عمر','إسلام','سيد','نهى','منى','سارة','ريهام','دينا','هبة','مروة','إيمان','شيماء','نورهان','ياسمين','آية','ندى','مريم','فاطمة','سلمى','رانيا','أسماء'];
const last = ['السيد','عبد العزيز','الشربيني','النجار','الجمال','عبد الحميد','الشافعي','البنا','المصري','عبد المنعم','الدسوقي','الطنطاوي','حجازي','شلبي','عوض','زكي','منصور','رزق','الشامي','الخولي','بدوي','عيسى','غنيم','مرسي','حمدي','عطية','نصار','قنديل','الفقي','العشري','بركات','عبد الفتاح','فرج','سليمان','الصعيدي','الأسيوطي','المنياوي','السوهاجي','الإسكندراني'];
const pick = (list) => list[Math.floor(rand() * list.length)];
// The father's name is always a man's name
const men = first.slice(0, first.indexOf('نهى'));

// How many lawyers each governorate gets follows its people (millions, about 2025)
const people = { 'القاهرة': 10.5, 'الجيزة': 9.3, 'الشرقية': 7.8, 'الدقهلية': 6.9, 'البحيرة': 6.8, 'المنيا': 6.1, 'القليوبية': 6.0,
  'الإسكندرية': 5.6, 'سوهاج': 5.6, 'الغربية': 5.3, 'أسيوط': 4.9, 'المنوفية': 4.6, 'الفيوم': 4.0, 'كفر الشيخ': 3.7, 'قنا': 3.6,
  'بنى سويف': 3.6, 'أسوان': 1.6, 'دمياط': 1.6, 'الإسماعيلية': 1.4, 'الأقصر': 1.3, 'بورسعيد': 0.8, 'السويس': 0.8, 'مطروح': 0.5,
  'شمال سيناء': 0.5, 'البحر الأحمر': 0.4, 'الوادي الجديد': 0.27, 'جنوب سيناء': 0.11 };
// Inside a governorate, cities get more than towns, and the capital-sized cities spread wider
const big = new Set(['القاهرة', 'الجيزة', 'الإسكندرية']);
const spots = [];
for (const [name, lat, lon, kind, gov] of places.places) {
  if (kind < 2) continue;
  const governorate = places.governorates[gov];
  if (!(governorate in people)) continue;
  spots.push({ lat, lon, gov: governorate, weight: big.has(name) ? 12 : kind === 3 ? 4 : 1, spread: big.has(name) ? 9 : kind === 3 ? 3 : 1.2 });
}
const byGov = {};
for (const spot of spots) (byGov[spot.gov] ??= []).push(spot);
const govTotal = Object.keys(byGov).reduce((sum, g) => sum + people[g], 0);
const pickSpot = () => {
  let r = rand() * govTotal;
  const gov = Object.keys(byGov).find((g) => (r -= people[g]) <= 0) ?? 'القاهرة';
  const list = byGov[gov];
  let w = rand() * list.reduce((sum, s) => sum + s.weight, 0);
  return list.find((s) => (w -= s.weight) <= 0) ?? list[0];
};

const rows = [];
for (let g = 1; g <= 1000; g++) {
  const spot = pickSpot();
  // Somewhere inside the city: up to its spread in km, denser near the middle
  const km = spot.spread * Math.sqrt(rand()) * 0.9;
  const angle = rand() * 2 * Math.PI;
  const lat = spot.lat + (km * Math.cos(angle)) / 111.32;
  const lon = spot.lon + (km * Math.sin(angle)) / (111.32 * Math.cos((spot.lat * Math.PI) / 180));
  // About 1 in 8 is new with no reviews; the rest mostly between 4.0 and 5.0
  const isNew = rand() < 0.125;
  const reviews = isNew ? 0 : Math.round(3 + rand() ** 2 * 180);
  const rating = isNew ? 0 : Math.min(5, Math.round((3.7 + rand() ** 0.6 * 1.3) * 10) / 10);
  const years = isNew ? 1 + Math.floor(rand() * 3) : 3 + Math.floor(rand() * 27);
  const name = `${pick(first)} ${pick(men)} ${pick(last)}`;
  rows.push(`(${g}, '${name}', ${lat.toFixed(6)}, ${lon.toFixed(6)}, '${spot.gov}', ${rating}, ${reviews}, ${years})`);
}

const sql = `-- 1000 demo lawyers placed like real ones inside real Egyptian cities and towns, written by build-demo-lawyers.mjs.
-- Marked by the email domain demo.invalid, removed with demo-lawyers-remove.sql. They cannot sign in (no password)
-- and receive no push (no device). Load after demo-lawyers-remove.sql.
BEGIN;
CREATE TEMP TABLE demo_people (g int, full_name text, lat float8, lon float8, governorate text, rating numeric, reviews int, years int) ON COMMIT DROP;
INSERT INTO demo_people VALUES
${rows.join(',\n')};
WITH new_users AS (
  INSERT INTO users (phone, email, role, status, full_name, email_verified_at)
  SELECT '0159' || lpad(g::text, 7, '0'), 'demo-lawyer-' || g || '@demo.invalid', 'lawyer', 'active', 'أ. ' || full_name, NOW()
  FROM demo_people
  ON CONFLICT DO NOTHING
  RETURNING id, email, full_name
)
INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status,
                             latitude, longitude, governorate, governorate_at, last_location_updated_at, last_active_at,
                             rating, reviews_count, experience_years)
SELECT nu.id, nu.full_name, 'D' || lpad(p.g::text, 6, '0'), 'approved', TRUE, 'APPROVED',
       p.lat, p.lon, p.governorate, NOW(), NOW(), NOW(), p.rating, p.reviews, p.years
FROM new_users nu
JOIN demo_people p ON 'demo-lawyer-' || p.g || '@demo.invalid' = nu.email;
COMMIT;

SELECT governorate, COUNT(*) FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id
WHERE u.email LIKE '%@demo.invalid' GROUP BY governorate ORDER BY 2 DESC;
`;
fs.writeFileSync(new URL('./demo-lawyers.sql', import.meta.url), sql);
console.log('wrote', rows.length, 'lawyers in', new Set(rows.map((r) => r.split("'")[3])).size, 'governorates');
