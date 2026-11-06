import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { call, sql } from './harness.js';

const day = async (offset: number) => (await sql(`SELECT to_char((NOW() AT TIME ZONE 'Africa/Cairo')::date + $1::int, 'YYYY-MM-DD') AS d`, [offset]))[0].d as string;

async function register(phone = '01011112222', fullName = 'أ. محمود السيد') {
  const res = await call('POST', '/presence/register', null, { fullName, phone, whatsapp: '01122223333', password: 'secret1' });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data.token as string;
}

async function add(token: string, body: object) {
  return call('POST', '/presence/entries', token, { day: await day(1), ...body });
}

const search = async (q: string) => (await call('GET', `/presence/entries?q=${encodeURIComponent(q)}`, null)).body.data as any[];

describe('صفحة أماكن التواجد', () => {
  beforeEach(async () => {
    await sql('DELETE FROM presence_accounts');
  });

  it('التسجيل بالاسم والهاتف والواتساب، والدخول من جهاز تاني، والرقم ما يتسجلش مرتين', async () => {
    await register('٠١٠١١١١٢٢٢٢');
    const again = await call('POST', '/presence/register', null, { fullName: 'حد تاني', phone: '01011112222', whatsapp: '01011112222', password: 'secret1' });
    assert.equal(again.status, 409);

    assert.equal((await call('POST', '/presence/login', null, { phone: '01011112222', password: 'wrong' })).status, 401);
    const login = await call('POST', '/presence/login', null, { phone: '01011112222', password: 'secret1' });
    assert.equal(login.status, 200);
    const me = await call('GET', '/presence/me', login.body.data.token);
    assert.equal(me.body.data.whatsapp, '01122223333');

    assert.equal((await call('POST', '/presence/register', null, { fullName: 'س', phone: '123', whatsapp: '01122223333', password: 'secret1' })).status, 400);
  });

  it('التواجد يظهر للعامة بالهاتف والواتساب، ويختفي بعد يومه، وصاحبه بس يمسحه', async () => {
    const token = await register();
    const res = await add(token, { city: 'الإسكندرية', places: ['محكمة شرق الإسكندرية الابتدائية', 'محكمة شرق الإسكندرية الابتدائية'], timeFrom: '09:00', timeTo: '13:00' });
    assert.equal(res.status, 201, JSON.stringify(res.body));

    const all = (await call('GET', '/presence/entries', null)).body.data;
    assert.equal(all.length, 1);
    assert.deepEqual(all[0].places, ['محكمة شرق الإسكندرية الابتدائية']);
    assert.equal(all[0].phone, '01011112222');
    assert.equal(all[0].timeFrom, '09:00');

    await sql(`UPDATE presence_entries SET day = day - 3`);
    assert.equal((await call('GET', '/presence/entries', null)).body.data.length, 0);
    await sql(`UPDATE presence_entries SET day = day + 3`);

    const other = await register('01099998888', 'أ. حد تاني');
    assert.equal((await call('DELETE', `/presence/entries/${res.body.data.id}`, other)).status, 404);
    assert.equal((await call('DELETE', `/presence/entries/${res.body.data.id}`, token)).status, 200);
    assert.equal((await call('GET', '/presence/mine', token)).body.data.length, 0);
  });

  it('ما ينفعش تاريخ فات أو بعيد، ولا وقت نهاية قبل البداية، ولا من غير دخول', async () => {
    const token = await register();
    assert.equal((await add(token, { city: 'الزقازيق', places: ['محكمة الزقازيق'], day: await day(-1) })).status, 400);
    assert.equal((await add(token, { city: 'الزقازيق', places: ['محكمة الزقازيق'], day: await day(90) })).status, 400);
    assert.equal((await add(token, { city: 'الزقازيق', places: ['محكمة الزقازيق'], timeFrom: '12:00', timeTo: '10:00' })).status, 400);
    assert.equal((await add(token, { city: 'الزقازيق', places: [] })).status, 400);
    assert.equal((await call('POST', '/presence/entries', null, { city: 'الزقازيق', places: ['محكمة الزقازيق'], day: await day(1) })).status, 401);
  });

  it('البحث بالكلمة وبجزء منها، من غير فرق بين ه وة وى وي والهمزات والتشكيل', async () => {
    const token = await register();
    await add(token, { city: 'الإسكندرية', places: ['محكمة شرق الإسكندرية الابتدائية'] });
    await add(token, { city: 'القاهرة', places: ['دار القضاء العالي', 'مصر الجديدة'] });
    await add(token, { city: 'الزقازيق', places: ['مجمع محاكم الزقازيق'] });

    assert.equal((await search('اسكندريه')).length, 1);
    assert.equal((await search('شرق الاسكندرية')).length, 1);
    assert.equal((await search('الأسكندرية شرق')).length, 1);
    assert.equal((await search('القضا')).length, 1);
    assert.equal((await search('العالى')).length, 1);
    assert.equal((await search('القَاهِرَة')).length, 1);
    assert.equal((await search('زقازيق')).length, 1);
    assert.equal((await search('ق')).length, 3);
    assert.equal((await search('محمود')).length, 3);
    assert.equal((await search('غرب الإسكندرية')).length, 0);
    assert.equal((await search('%')).length, 3);

    const city = (await call('GET', `/presence/entries?city=${encodeURIComponent('القاهره')}`, null)).body.data;
    assert.equal(city.length, 1);
  });
});
