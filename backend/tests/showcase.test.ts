import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, it } from 'node:test';
import { call, clientToken, createUser, lawyerId, sql } from './harness.js';
import { forgetShowcase, governorateOf, publicPoint } from '../src/modules/lawyers/showcase.js';

const extra: string[] = [];

async function addLawyer(phone: string, lat: number, lon: number, options: { available?: boolean; approved?: boolean; rating?: number; reviews?: number; daysSinceMove?: number } = {}) {
  const id = await createUser(phone, 'lawyer');
  extra.push(id);
  await sql(
    `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, latitude, longitude, rating, reviews_count, last_location_updated_at)
     VALUES ($1, $2, $3, $4::lawyer_approval_status, $5, $6, $7, $8, $10, NOW() - make_interval(days => $9))`,
    [id, `أ. ${phone}`, phone, options.approved === false ? 'pending' : 'approved', options.available ?? false, lat, lon, options.rating ?? 4, options.daysSinceMove ?? 0, options.reviews ?? 20]
  );
  return id;
}

const cellOf = (lat: number, lon: number, degrees = 0.1) => `${Math.floor(lon / degrees)}_${Math.floor(lat / degrees)}`;

describe('خريطة المحامين للعرض', () => {
  beforeEach(() => forgetShowcase());
  afterEach(async () => {
    await sql('DELETE FROM lawyer_profiles WHERE user_id = ANY($1)', [extra]);
    await sql('DELETE FROM users WHERE id = ANY($1)', [extra]);
    extra.length = 0;
  });

  it('المحافظة من أقرب مدينة، نفس قاعدة الموبايل', () => {
    assert.equal(governorateOf(30.06, 31.33), 'القاهرة');
    assert.equal(governorateOf(31.2, 29.92), 'الإسكندرية');
    assert.equal(governorateOf(NaN, 31), null);
  });

  it('المربع فيه كل المحامين المعتمدين متاحين أو لأ، ومن غير المعلق والقديم والموقوف', async () => {
    const off = await addLawyer('01200000001', 30.051, 31.251, { available: false });
    await addLawyer('01200000002', 30.052, 31.252, { approved: false });
    await addLawyer('01200000003', 30.053, 31.253, { daysSinceMove: 40 });
    const stopped = await addLawyer('01200000004', 30.054, 31.254);
    await sql(`UPDATE lawyer_profiles SET suspended_until = NOW() + interval '1 day' WHERE user_id = $1`, [stopped]);

    const cell = cellOf(30.05, 31.25);
    const res = await call('GET', `/lawyers/map?size=s&cells=${cell}`, clientToken);
    assert.equal(res.status, 200, JSON.stringify(res.body));
    const ids = res.body.data.cells[cell].map((lawyer: any) => lawyer.id);
    assert.ok(ids.includes(lawyerId) && ids.includes(off));
    assert.ok(!extra.slice(1).some((id) => ids.includes(id)));

    // المكان تقريبي (150 لـ 450 متر من الحقيقي) وثابت لنفس المحامي، ومفيش بيانات إتاحة
    const card = res.body.data.cells[cell].find((lawyer: any) => lawyer.id === off);
    const real = (await sql('SELECT latitude, longitude FROM lawyer_profiles WHERE user_id = $1', [off]))[0];
    const km = Math.hypot((card.coordinates[0] - Number(real.latitude)) * 111.32, (card.coordinates[1] - Number(real.longitude)) * 111.32 * Math.cos((Number(real.latitude) * Math.PI) / 180));
    assert.ok(km > 0.14 && km < 0.46, String(km));
    assert.deepEqual(card.coordinates, publicPoint(off, Number(real.latitude), Number(real.longitude)));
    assert.equal(card.isOnline, undefined);
  });

  it('محامي مراجعة جوجل ما بيظهرش على الخريطة للناس', async () => {
    const review = await addLawyer('01200000009', 30.055, 31.255);
    await sql('UPDATE users SET is_review_account = TRUE WHERE id = $1', [review]);
    const cell = cellOf(30.05, 31.25);
    const ids = (await call('GET', `/lawyers/map?size=s&cells=${cell}`, clientToken)).body.data.cells[cell].map((lawyer: any) => lawyer.id);
    assert.ok(ids.includes(lawyerId));
    assert.ok(!ids.includes(review));
  });

  it('خريطة المحامين وقايمتهم وتقييماتهم للحسابات المسجلة بس', async () => {
    const cell = cellOf(30.05, 31.25);
    assert.equal((await call('GET', `/lawyers/map?cells=${cell}`, null)).status, 401);
    assert.equal((await call('GET', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, null)).status, 401);
    assert.equal((await call('GET', `/lawyers/${lawyerId}/reviews`, null)).status, 401);
    assert.equal((await call('GET', '/auth/check', null)).status, 401);
    assert.equal((await call('GET', '/auth/check', clientToken)).status, 200);
  });

  it('المربع بيتحفظ عند الخادم، فالتغيير يبان في النسخة الجاية بس', async () => {
    const cell = cellOf(30.05, 31.25);
    const first = await call('GET', `/lawyers/map?cells=${cell}`, clientToken);
    const before = first.body.data.cells[cell].length;
    await addLawyer('01200000005', 30.055, 31.255);
    const second = await call('GET', `/lawyers/map?cells=${cell}`, clientToken);
    assert.equal(second.body.data.cells[cell].length, before);
    forgetShowcase();
    const third = await call('GET', `/lawyers/map?cells=${cell}`, clientToken);
    assert.equal(third.body.data.cells[cell].length, before + 1);
  });

  it('أهم محامي في كل منطقة: الأعلى تقييمًا بس، زي جوجل', async () => {
    const best = await addLawyer('01200000009', 30.0512, 31.2512, { rating: 4.99, reviews: 40 });
    const weak = await addLawyer('01200000010', 30.0513, 31.2513, { rating: 3.0, reviews: 40 });
    const cell = cellOf(30.05, 31.25);
    const ids = (await call('GET', `/lawyers/map?kind=top&cells=${cell}`, clientToken)).body.data.cells[cell].map((l: any) => l.id);
    assert.ok(ids.includes(best) && !ids.includes(weak));
  });

  it('المربعات الكبيرة والطلبات الغلط', async () => {
    const big = cellOf(30.05, 31.25, 0.5);
    const res = await call('GET', `/lawyers/map?size=l&cells=${big}`, clientToken);
    assert.ok(res.body.data.cells[big].some((lawyer: any) => lawyer.id === lawyerId));
    assert.equal((await call('GET', '/lawyers/map?cells=abc', clientToken)).status, 400);
    assert.equal((await call('GET', '/lawyers/map?cells=0_0', clientToken)).status, 400);
    const many = Array.from({ length: 151 }, (_, i) => `${250 + (i % 100)}_${260 + Math.floor(i / 100)}`).join(',');
    assert.equal((await call('GET', `/lawyers/map?cells=${many}`, clientToken)).status, 400);
  });

  it('أعلى المحامين تقييمًا في المحافظة، والمحافظة بتتحسب تاني لما المكان يتغير', async () => {
    const top = await addLawyer('01200000006', 30.06, 31.33, { rating: 4.9 });
    const low = await addLawyer('01200000007', 30.07, 31.34, { rating: 3.1 });
    const alex = await addLawyer('01200000008', 31.2, 29.92, { rating: 5 });

    const cairo = (await call('GET', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, clientToken)).body.data.map((lawyer: any) => lawyer.id);
    assert.ok(cairo.indexOf(top) < cairo.indexOf(low));
    assert.ok(!cairo.includes(alex));

    await sql(`UPDATE lawyer_profiles SET latitude = 30.06, longitude = 31.33, last_location_updated_at = NOW() + interval '1 second' WHERE user_id = $1`, [alex]);
    forgetShowcase();
    const after = (await call('GET', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, clientToken)).body.data.map((lawyer: any) => lawyer.id);
    assert.equal(after[0], alex);

    assert.equal((await call('GET', '/lawyers/top?governorate=x', clientToken)).status, 400);
  });
});

describe('ترتيب التقييم العادل', () => {
  afterEach(async () => {
    await sql('DELETE FROM lawyer_profiles WHERE user_id = ANY($1)', [extra]);
    await sql('DELETE FROM users WHERE id = ANY($1)', [extra]);
    extra.length = 0;
    forgetShowcase();
  });

  it('5 نجوم من تقييم واحد بتيجي بعد 4.9 من 50 تقييم', async () => {
    const steady = await addLawyer('01200000011', 30.065, 31.335, { rating: 4.9, reviews: 50 });
    const once = await addLawyer('01200000012', 30.066, 31.336, { rating: 5, reviews: 1 });
    forgetShowcase();
    const cairo = (await call('GET', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, clientToken)).body.data.map((lawyer: any) => lawyer.id);
    assert.ok(cairo.includes(steady) && cairo.includes(once), JSON.stringify(cairo));
    assert.ok(cairo.indexOf(steady) < cairo.indexOf(once));
  });
});
