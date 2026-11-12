import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { app, clientToken, lawyerToken, adminToken, call, sql, clientId, clientBalance } from './harness.js';

const png = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da63f8cfc0f01f0005000201a5ddd3fb0000000049454e44ae426082', 'hex');
const details = 'اتفقت مع صاحب الشقة على الإيجار لمدة سنة، ودلوقتي عايز يطلعني قبل المدة من غير سبب';

async function sendPapers(token: string, pages: number, method = 'direct') {
  const boundary = 'ml-consult-boundary';
  const field = (name: string, value: string) => `--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`;
  const parts: Buffer[] = [Buffer.from(field('kind', 'PAPERS') + field('details', details) + field('method', method))];
  for (let i = 0; i < pages; i++) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="pages"; filename="p${i}.png"\r\nContent-Type: image/png\r\n\r\n`), png, Buffer.from('\r\n'));
  }
  parts.push(Buffer.from(`--${boundary}--\r\n`));
  return app.inject({
    method: 'POST',
    url: '/api/v1/consultations',
    headers: { authorization: `Bearer ${token}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
    payload: Buffer.concat(parts),
  });
}

describe('الاستشارة السريعة', () => {
  it('السعر من السيرفر: استشارة بس، واطلاع على ورق بسعر لكل ورقة', async () => {
    const call1 = (await call('POST', '/consultations/quote', clientToken, { kind: 'CALL' })).body.data;
    assert.equal(call1.total, 200);
    const papers = (await call('POST', '/consultations/quote', clientToken, { kind: 'PAPERS', pages: 3 })).body.data;
    assert.equal(papers.total, 250 + 3 * 30);
  });

  it('الطلب بالورق: السعر على عدد الصور، والصور لصاحبها والإدارة بس', async () => {
    const res = await sendPapers(clientToken, 2);
    assert.equal(res.statusCode, 201, res.body);
    const created = res.json().data;
    assert.match(created.reference, /^ML-CNS-\d{6}$/);
    assert.equal(created.price, 310);
    assert.equal(created.status, 'PAID');

    const mine = (await call('GET', `/consultations/${created.id}`, clientToken)).body.data;
    assert.equal(mine.pages.length, 2);
    const get = (token: string) => app.inject({ method: 'GET', url: `/api/v1${mine.pages[0]}`, headers: { authorization: `Bearer ${token}` } });
    assert.equal((await get(clientToken)).statusCode, 200);
    assert.equal((await get(adminToken)).statusCode, 200);
    assert.equal((await get(lawyerToken)).statusCode, 404);
  });

  it('الطلب بالكلام: النص للإدارة بس، والموكل ما بيشوفوش', async () => {
    const created = (await call('POST', '/consultations', clientToken, { kind: 'CALL', details, inputMethod: 'voice' })).body.data;
    assert.equal(created.viaVoice, true);
    assert.equal(created.details, null);
    const mine = (await call('GET', `/consultations/${created.id}`, clientToken)).body.data;
    assert.equal(mine.details, null);
    assert.equal(mine.viaVoice, true);
    const forAdmin = (await call('GET', `/admin/consultations/${created.id}`, adminToken)).body.data;
    assert.equal(forAdmin.details, details);
    assert.equal(forAdmin.input_method, 'VOICE');
    assert.equal((await call('GET', '/admin/consultations', adminToken)).body.data[0].input_method, 'VOICE');

    const typed = (await call('POST', '/consultations', clientToken, { kind: 'CALL', details })).body.data;
    assert.equal(typed.viaVoice, false);
    assert.equal(typed.details, details);
  });

  it('تفاصيل قصيرة أو محامي أو ورق من غير صور: مرفوض', async () => {
    assert.equal((await call('POST', '/consultations', clientToken, { kind: 'CALL', details: 'قصير' })).status, 400);
    assert.equal((await call('POST', '/consultations', lawyerToken, { kind: 'CALL', details })).status, 403);
    assert.equal((await call('POST', '/consultations', clientToken, { kind: 'PAPERS', details })).status, 400);
  });

  it('الدفع من الرصيد بيخصم، والرفض بيرجع المبلغ كله للرصيد', async () => {
    assert.equal((await call('POST', '/consultations', clientToken, { kind: 'CALL', details, method: 'wallet' })).status, 400);
    await sql(`INSERT INTO client_credits (client_id, amount, reason) VALUES ($1, 500, 'شحن اختبار')`, [clientId]);
    const created = (await call('POST', '/consultations', clientToken, { kind: 'CALL', details, method: 'wallet' })).body.data;
    assert.equal(await clientBalance(), 300);

    assert.equal((await call('POST', `/admin/consultations/${created.id}/status`, adminToken, { status: 'REJECTED' })).status, 400);
    assert.equal((await call('POST', `/admin/consultations/${created.id}/status`, adminToken, { status: 'REJECTED', reason: 'المشكلة محتاجة محامي في المحكمة' })).status, 200);
    assert.equal(await clientBalance(), 500);
    assert.equal((await call('POST', `/admin/consultations/${created.id}/status`, adminToken, { status: 'DONE' })).status, 409);
  });

  it('الإدارة: جاري التواصل ثم تمت، والأسعار الجديدة بتتطبق على الطلبات الجاية', async () => {
    const created = (await call('POST', '/consultations', clientToken, { kind: 'CALL', details })).body.data;
    assert.equal((await call('POST', `/admin/consultations/${created.id}/status`, adminToken, { status: 'CONTACTING' })).status, 200);
    assert.equal((await call('POST', `/admin/consultations/${created.id}/status`, adminToken, { status: 'DONE', note: 'تمت المكالمة' })).status, 200);
    assert.equal((await call('GET', '/consultations', clientToken)).body.data[0].status, 'DONE');

    const saved = await call('PUT', '/admin/consultation-settings', adminToken, { callPrice: 150, papersBasePrice: 250, pagePrice: 30, maxPages: 10, callMinutes: 7, minDetailsChars: 50, isOpen: true });
    assert.equal(saved.status, 200);
    assert.equal((await call('POST', '/consultations/quote', clientToken, { kind: 'CALL' })).body.data.total, 150);
    await call('PUT', '/admin/consultation-settings', adminToken, { callPrice: 200, papersBasePrice: 250, pagePrice: 30, maxPages: 10, callMinutes: 7, minDetailsChars: 50, isOpen: true });
  });
});

describe('الاستشارة السريعة: التواصل', () => {
  it('«مقدرناش نوصلك» ثم الموكل يطلب التواصل مرة واحدة', async () => {
    const created = (await call('POST', '/consultations', clientToken, { kind: 'CALL', details })).body.data;
    assert.equal(created.canRequestContact, false);
    assert.equal((await call('POST', `/consultations/${created.id}/contact`, clientToken, {})).status, 409);
    assert.equal((await call('POST', `/admin/consultations/${created.id}/unreachable`, adminToken, {})).status, 200);
    const mine = (await call('GET', `/consultations/${created.id}`, clientToken)).body.data;
    assert.equal(mine.canRequestContact, true);
    assert.equal((await call('POST', `/consultations/${created.id}/contact`, clientToken, {})).status, 200);
    assert.equal((await call('POST', `/consultations/${created.id}/contact`, clientToken, {})).status, 409);
    const forAdmin = (await call('GET', `/admin/consultations/${created.id}`, adminToken)).body.data;
    assert.ok(forAdmin.callback_requested_at);
  });
});
