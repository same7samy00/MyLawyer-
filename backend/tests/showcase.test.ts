import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, it } from 'node:test';
import { call, createUser, lawyerId, sql } from './harness.js';
import { forgetShowcase, governorateOf } from '../src/modules/lawyers/showcase.js';

const extra: string[] = [];

async function addLawyer(phone: string, lat: number, lon: number, options: { available?: boolean; approved?: boolean; rating?: number; daysSinceMove?: number } = {}) {
  const id = await createUser(phone, 'lawyer');
  extra.push(id);
  await sql(
    `INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, latitude, longitude, rating, last_location_updated_at)
     VALUES ($1, $2, $3, $4::lawyer_approval_status, $5, $6, $7, $8, NOW() - make_interval(days => $9))`,
    [id, `أ. ${phone}`, phone, options.approved === false ? 'pending' : 'approved', options.available ?? false, lat, lon, options.rating ?? 4, options.daysSinceMove ?? 0]
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
    const res = await call('GET', `/lawyers/map?size=s&cells=${cell}`, null);
    assert.equal(res.status, 200, JSON.stringify(res.body));
    const ids = res.body.data.cells[cell].map((lawyer: any) => lawyer.id);
    assert.ok(ids.includes(lawyerId) && ids.includes(off));
    assert.ok(!extra.slice(1).some((id) => ids.includes(id)));

    // المكان تقريبي وثابت، ومفيش بيانات إتاحة
    const card = res.body.data.cells[cell].find((lawyer: any) => lawyer.id === off);
    assert.deepEqual(card.coordinates, [30.05, 31.25]);
    assert.equal(card.isOnline, undefined);
  });

  it('المربع بيتحفظ 5 دقايق، فالتغيير يبان في النسخة الجاية بس', async () => {
    const cell = cellOf(30.05, 31.25);
    const first = await call('GET', `/lawyers/map?cells=${cell}`, null);
    const before = first.body.data.cells[cell].length;
    await addLawyer('01200000005', 30.055, 31.255);
    const second = await call('GET', `/lawyers/map?cells=${cell}`, null);
    assert.equal(second.body.data.cells[cell].length, before);
    forgetShowcase();
    const third = await call('GET', `/lawyers/map?cells=${cell}`, null);
    assert.equal(third.body.data.cells[cell].length, before + 1);
  });

  it('أهم محامي في كل منطقة: الأعلى تقييمًا بس، زي جوجل', async () => {
    const best = await addLawyer('01200000009', 30.0512, 31.2512, { rating: 4.99 });
    const weak = await addLawyer('01200000010', 30.0513, 31.2513, { rating: 3.0 });
    const cell = cellOf(30.05, 31.25);
    const ids = (await call('GET', `/lawyers/map?kind=top&cells=${cell}`, null)).body.data.cells[cell].map((l: any) => l.id);
    assert.ok(ids.includes(best) && !ids.includes(weak));
  });

  it('المربعات الكبيرة والطلبات الغلط', async () => {
    const big = cellOf(30.05, 31.25, 0.5);
    const res = await call('GET', `/lawyers/map?size=l&cells=${big}`, null);
    assert.ok(res.body.data.cells[big].some((lawyer: any) => lawyer.id === lawyerId));
    assert.equal((await call('GET', '/lawyers/map?cells=abc', null)).status, 400);
    assert.equal((await call('GET', '/lawyers/map?cells=0_0', null)).status, 400);
    const many = Array.from({ length: 151 }, (_, i) => `${250 + (i % 100)}_${260 + Math.floor(i / 100)}`).join(',');
    assert.equal((await call('GET', `/lawyers/map?cells=${many}`, null)).status, 400);
  });

  it('أعلى المحامين تقييمًا في المحافظة، والمحافظة بتتحسب تاني لما المكان يتغير', async () => {
    const top = await addLawyer('01200000006', 30.06, 31.33, { rating: 4.9 });
    const low = await addLawyer('01200000007', 30.07, 31.34, { rating: 3.1 });
    const alex = await addLawyer('01200000008', 31.2, 29.92, { rating: 5 });

    const cairo = (await call('GET', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, null)).body.data.map((lawyer: any) => lawyer.id);
    assert.ok(cairo.indexOf(top) < cairo.indexOf(low));
    assert.ok(!cairo.includes(alex));

    await sql(`UPDATE lawyer_profiles SET latitude = 30.06, longitude = 31.33, last_location_updated_at = NOW() + interval '1 second' WHERE user_id = $1`, [alex]);
    forgetShowcase();
    const after = (await call('GET', `/lawyers/top?governorate=${encodeURIComponent('القاهرة')}`, null)).body.data.map((lawyer: any) => lawyer.id);
    assert.equal(after[0], alex);

    assert.equal((await call('GET', '/lawyers/top?governorate=x', null)).status, 400);
  });
});
