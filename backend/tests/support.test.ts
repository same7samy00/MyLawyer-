import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { app, sweepLifecycle, clientId, lawyerId, clientToken, lawyerToken, adminToken, call, sql, createUser, createOrder, createPaidOrder, createCompletedOrder, openTicket, wallet, clientBalance } from './harness.js';

describe('الدعم الفني', () => {
  it('تحت المراجعة، ثم مفتوحة بعد رد الإدارة، وتفضل مفتوحة لحد ما الإدارة تقفلها', async () => {
    const created = await openTicket(clientToken, null, 'ACCOUNT');
    assert.equal(created.status, 201);
    const ticket = created.body.data;
    assert.match(ticket.reference, /^ML-TKT-\d{6}$/);
    assert.equal(ticket.status, 'UNDER_REVIEW');

    assert.equal((await call('POST', `/admin/support/${ticket.id}/note`, adminToken, { body: 'كلمت الموكل' })).status, 200);
    assert.equal((await call('POST', `/admin/support/${ticket.id}/reply`, adminToken, { body: 'بنراجع حسابك' })).status, 200);
    assert.equal((await call('POST', `/support/tickets/${ticket.id}/messages`, clientToken, { body: 'شكراً، مستني' })).status, 201);
    assert.equal((await call('POST', `/admin/support/${ticket.id}/reply`, adminToken, { body: 'اتحلت' })).status, 200);

    const mine = (await call('GET', `/support/tickets/${ticket.id}`, clientToken)).body.data;
    assert.equal(mine.status, 'OPEN');
    assert.deepEqual(mine.messages.map((m: any) => m.author), ['USER', 'ADMIN', 'USER', 'ADMIN']);

    const forAdmin = (await call('GET', `/admin/support/${ticket.id}`, adminToken)).body.data;
    assert.equal(forAdmin.messages.some((m: any) => m.author === 'NOTE'), true);

    assert.equal((await call('POST', `/admin/support/${ticket.id}/close`, adminToken, {})).status, 200);
    assert.equal((await call('POST', `/support/tickets/${ticket.id}/messages`, clientToken, { body: 'رد بعد القفل' })).status, 409);
    assert.equal((await call('GET', '/support/tickets', clientToken)).body.data[0].status, 'CLOSED');
    assert.equal((await call('GET', `/support/tickets/${ticket.id}`, lawyerToken)).status, 404);
  });

  it('التذكرة بتاخد صور، والصورة لصاحب التذكرة والإدارة بس', async () => {
    const png = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da63f8cfc0f01f0005000201a5ddd3fb0000000049454e44ae426082', 'hex');
    const boundary = 'ml-test-boundary';
    const field = (name: string, value: string) => `--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`;
    const payload = Buffer.concat([
      Buffer.from(field('category', 'OTHER') + field('title', 'صورة المشكلة') + field('body', 'مرفق صورة للمشكلة')),
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="images"; filename="a.png"\r\nContent-Type: image/png\r\n\r\n`),
      png,
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]);
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/support/tickets',
      headers: { authorization: `Bearer ${clientToken}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
      payload,
    });
    assert.equal(res.statusCode, 201, res.body);

    const ticket = (await call('GET', `/support/tickets/${res.json().data.id}`, clientToken)).body.data;
    const image = ticket.messages[0].images[0];
    assert.match(image, /^\/support\/attachments\//);
    const get = (token: string) => app.inject({ method: 'GET', url: `/api/v1${image}`, headers: { authorization: `Bearer ${token}` } });
    assert.equal((await get(clientToken)).statusCode, 200);
    assert.equal((await get(adminToken)).statusCode, 200);
    assert.equal((await get(lawyerToken)).statusCode, 404);
  });

  it('ما يبعتش حاجة تانية لحد ما الإدارة ترد: لا رد في نفس التذكرة ولا تذكرة جديدة', async () => {
    const first = (await openTicket(clientToken, null, 'OTHER')).body.data;
    assert.equal(first.awaitingReply, true);
    assert.equal((await call('POST', `/support/tickets/${first.id}/messages`, clientToken, { body: 'نسيت أقول' })).status, 409);
    assert.equal((await openTicket(clientToken, null, 'OTHER')).status, 409);

    await call('POST', `/admin/support/${first.id}/reply`, adminToken, { body: 'تحت أمرك' });
    assert.equal((await call('GET', '/support/tickets', clientToken)).body.data[0].awaitingReply, false);
    assert.equal((await call('POST', `/support/tickets/${first.id}/messages`, clientToken, { body: 'تمام' })).status, 201);
    assert.equal((await call('POST', `/support/tickets/${first.id}/messages`, clientToken, { body: 'تاني' })).status, 409);
  });

  it('أقصى 3 تذاكر مفتوحة، وتذكرة مفتوحة واحدة على نفس الطلب', async () => {
    const reply = async (res: any) => {
      await call('POST', `/admin/support/${res.body.data.id}/reply`, adminToken, { body: 'وصلنا' });
      return res;
    };
    const order = await createCompletedOrder();
    assert.equal((await reply(await openTicket(clientToken, order.id, 'ORDER'))).status, 201);
    assert.equal((await openTicket(clientToken, order.id, 'ORDER')).status, 409);
    assert.equal((await reply(await openTicket(clientToken, null, 'OTHER'))).status, 201);
    assert.equal((await reply(await openTicket(clientToken, null, 'OTHER'))).status, 201);
    assert.equal((await openTicket(clientToken, null, 'OTHER')).status, 409);
  });

  it('صفحة الأموال بتعرض المجمد والحركات وسجل التجميد', async () => {
    const order = await createCompletedOrder();
    const ticket = (await openTicket(clientToken, order.id)).body.data;
    await call('POST', `/admin/support/${ticket.id}/transfer`, adminToken, { from: 'lawyer', amount: 100, reason: 'تعويض الموكل' });

    const detail = (await call('GET', `/admin/orders/${order.id}`, adminToken)).body.data;
    assert.equal(detail.movements.length, 2);
    assert.equal(detail.events[0].action, 'FREEZE');

    const warned = await call('POST', `/admin/users/${lawyerId}/warnings`, adminToken, { reason: 'إنذار على الطلب', orderNumber: detail.order.order_number });
    assert.equal(warned.status, 200);
    assert.equal((await sql('SELECT order_id FROM account_warnings WHERE user_id = $1', [lawyerId]))[0].order_id, order.id);
    assert.equal((await call('POST', `/admin/users/${lawyerId}/warnings`, adminToken, { reason: 'إنذار على طلب غريب', orderNumber: 'ML-NONE' })).status, 400);

    const overview = (await call('GET', '/admin/overview', adminToken)).body.data;
    assert.equal(overview.frozen_orders, 1);
    assert.equal(overview.waiting_tickets, 1);
    const allTickets = (await call('GET', '/admin/support', adminToken)).body.data;
    assert.equal(allTickets[0].user_role, 'client');

    let money = (await call('GET', '/admin/money', adminToken)).body.data;
    assert.equal(Number(money.totals.frozen), 350);
    assert.equal(Number(money.totals.added), 100);
    assert.equal(Number(money.totals.deducted), 100);
    assert.equal(money.frozen[0].ticket_id, ticket.id);
    assert.equal(money.movements.length, 2);
    assert.equal(money.events[0].action, 'FREEZE');
    assert.equal(money.events[0].created_by, null);

    await call('POST', `/admin/orders/${order.id}/freeze`, adminToken, { freeze: false });
    money = (await call('GET', '/admin/money', adminToken)).body.data;
    assert.equal(money.frozen.length, 0);
    assert.equal(money.events[0].action, 'UNFREEZE');
    assert.ok(money.events[0].created_by);

    await call('POST', `/admin/orders/${order.id}/freeze`, adminToken, { freeze: true });
    await call('POST', `/admin/orders/${order.id}/settle`, adminToken, { outcome: 'REFUND' });
    money = (await call('GET', '/admin/money', adminToken)).body.data;
    assert.equal(money.events[0].action, 'SETTLE');

    const future = (await call('GET', '/admin/money?from=2099-01-01', adminToken)).body.data;
    assert.equal(future.movements.length, 0);
    assert.equal((await call('GET', '/admin/money?from=bad', adminToken)).status, 400);
    assert.equal((await call('GET', '/admin/money', clientToken)).status, 403);
  });

  it('البحث الشامل يلاقي الطلب والتذكرة والحساب، وللإدارة بس', async () => {
    const order = await createCompletedOrder();
    const ticket = (await openTicket(clientToken, order.id)).body.data;
    const search = async (q: string) => (await call('GET', `/admin/search?q=${encodeURIComponent(q)}`, adminToken)).body.data;

    const number = (await call('GET', `/admin/orders/${order.id}`, adminToken)).body.data.order.order_number;
    assert.equal((await search(number)).orders[0].id, order.id);
    assert.equal((await search(ticket.reference)).tickets[0].id, ticket.id);
    const phone = (await sql('SELECT phone FROM users WHERE id = $1', [clientId]))[0].phone;
    assert.equal((await search(phone)).users[0].id, clientId);
    assert.equal((await search('%%')).users.length, 0);
    assert.equal((await search('ا')).users.length, 0);
    assert.equal((await call('GET', '/admin/search?q=test', clientToken)).status, 403);
  });

  it('كل دفعة بتتسجل برقم وطريقة، وتظهر في الأموال والطلب وملف الموكل', async () => {
    const order = await createPaidOrder();
    const money = (await call('GET', '/admin/money', adminToken)).body.data;
    assert.equal(money.payments.length, 1);
    assert.match(money.payments[0].reference, /^ML-PAY-\d+$/);
    assert.equal(money.payments[0].order_id, order.id);
    assert.equal(money.payments[0].method, 'DIRECT');
    assert.equal(Number(money.totals.paid), Number(money.payments[0].amount));

    assert.equal((await call('GET', `/admin/orders/${order.id}`, adminToken)).body.data.payment.reference, money.payments[0].reference);
    assert.equal((await call('GET', `/admin/users/${clientId}`, adminToken)).body.data.payments[0].reference, money.payments[0].reference);
  });

  it('الدفع من الرصيد بيتسجل بطريقة الرصيد', async () => {
    await call('POST', `/admin/users/${clientId}/balance`, adminToken, { amount: 1000, reason: 'رصيد للتجربة' });
    const order = await createOrder();
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
    assert.equal((await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, { method: 'wallet' })).status, 200);
    assert.equal((await sql('SELECT method FROM payments WHERE order_id = $1', [order.id]))[0].method, 'WALLET');
  });

  it('سنوات الخبرة بتتسجل مع حساب المحامي وتظهر في ملفه', async () => {
    const res = await call('POST', '/auth/register', null, {
      phone: '01000000088', email: 'years@example.com', password: 'Strong12345', confirmPassword: 'Strong12345',
      role: 'lawyer', fullName: 'محامٍ خبير', syndicateNumber: '778899', experienceYears: 12, agreeTerms: true,
    });
    assert.equal(res.status, 201);
    const row = (await sql(`SELECT lp.experience_years, lp.user_id FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id WHERE u.phone = '01000000088'`))[0];
    assert.equal(row.experience_years, 12);
    const token = app.jwt.sign({ userId: row.user_id, role: 'lawyer' });
    await sql(`UPDATE users SET status = 'active' WHERE id = $1`, [row.user_id]);
    const me = (await call('GET', '/users/me', token)).body.data;
    assert.equal(me.experienceYears, 12);
    assert.equal('specialty' in me, false);
    assert.equal('bio' in me, false);
  });

  it('إشعارات الطلب القديمة بتختفي لما الطلب يتقدم، والضغط على إشعار بيقراه', async () => {
    const titles = async (user: string) => (await sql('SELECT title FROM notifications WHERE user_id = $1', [user])).map((row: any) => row.title);
    const order = await createOrder();
    assert.ok((await titles(lawyerId)).includes('طلب جديد'));
    await call('POST', `/orders/${order.id}/accept`, lawyerToken, {});
    assert.equal((await titles(lawyerId)).includes('طلب جديد'), false);
    assert.ok((await titles(clientId)).includes('المحامي وافق'));
    await call('POST', `/orders/${order.id}/confirm-payment`, clientToken, {});
    assert.equal((await titles(clientId)).includes('المحامي وافق'), false);

    const note = (await sql(`SELECT id FROM notifications WHERE user_id = $1 AND title = 'الموكل دفع'`, [lawyerId]))[0];
    assert.equal((await call('POST', '/notifications/read', lawyerToken, { id: note.id })).status, 200);
    assert.ok((await sql('SELECT read_at FROM notifications WHERE id = $1', [note.id]))[0].read_at);
    assert.equal((await call('POST', '/notifications/read', lawyerToken, {})).status, 400);

    await sql('UPDATE notifications SET read_at = NULL WHERE id = $1', [note.id]);
    await call('POST', '/notifications/read', clientToken, { id: note.id });
    assert.equal((await sql('SELECT read_at FROM notifications WHERE id = $1', [note.id]))[0].read_at, null);
  });

  it('لوحة التحكم بتتفتح بملفاتها، ومفيش وصول لملفات تانية', async () => {
    const page = await app.inject({ method: 'GET', url: '/api/v1/admin-panel' });
    assert.equal(page.statusCode, 200);
    assert.equal(page.body.includes('__VERSION__'), false);
    for (const [name, type] of [['styles', 'text/css'], ['script', 'text/javascript'], ['logo', 'image/png']]) {
      const link = page.body.match(new RegExp(`/api/v1/admin-panel/${name}\\?v=\\w+`))![0];
      assert.equal(/\.\w+\?/.test(link), false);
      const file = await app.inject({ method: 'GET', url: link });
      assert.equal(file.statusCode, 200);
      assert.ok((file.headers['content-type'] as string).startsWith(type));
      assert.match(file.headers['cache-control'] as string, /immutable/);
    }
    const script = await app.inject({ method: 'GET', url: '/api/v1/admin-panel/script' });
    assert.ok(script.body.indexOf('function readSession') < script.body.indexOf('const PAGES = {'));
    assert.equal((await app.inject({ method: 'GET', url: '/api/v1/admin-panel/assets/index.html' })).statusCode, 404);
  });

  it('قرارات الإدارة بتتسجل بمين عملها', async () => {
    await sql('DELETE FROM admin_actions');
    const other = await createUser('01000000077', 'client');
    await call('POST', `/admin/users/${other}/status`, adminToken, { suspend: true });
    await call('POST', `/admin/users/${other}/status`, adminToken, { suspend: false });
    await call('POST', '/admin/tax', adminToken, { percent: 0 });
    await call('POST', '/admin/commission', adminToken, { percent: 0 });
    const actions = (await call('GET', '/admin/actions', adminToken)).body.data;
    assert.deepEqual(actions.map((item: any) => item.action).sort(), ['ACCOUNT_ACTIVATE', 'ACCOUNT_SUSPEND', 'COMMISSION_UPDATE', 'TAX_UPDATE']);
    assert.ok(actions.every((item: any) => item.created_by));
    assert.equal((await call('GET', '/admin/actions', clientToken)).status, 403);
  });

  it('انتهاء المهل والتذاكر والتجميد بيتسجلوا في مراحل الطلب', async () => {
    const unanswered = await createOrder();
    await sql(`UPDATE service_orders SET response_deadline = NOW() - INTERVAL '1 minute' WHERE id = $1`, [unanswered.id]);
    await sweepLifecycle();
    const logs = (await call('GET', `/admin/orders/${unanswered.id}`, adminToken)).body.data.logs;
    assert.equal(logs.at(-1).new_status, 'NO_RESPONSE');
    assert.equal(logs.at(-1).actor_role, null);

    const done = await createCompletedOrder();
    await openTicket(clientToken, done.id);
    const notes = (await call('GET', `/admin/orders/${done.id}`, adminToken)).body.data.logs.map((log: any) => log.note);
    assert.ok(notes.some((note: string) => note.startsWith('فُتحت تذكرة')));
    assert.ok(notes.some((note: string) => note.startsWith('تجميد الأتعاب')));
  });

  it('التحويل من التذكرة بيخصم من طرف ويضيف للتاني في نفس اللحظة', async () => {
    const order = await createCompletedOrder();
    const ticket = (await openTicket(clientToken, order.id)).body.data;
    const transfer = (body: object) => call('POST', `/admin/support/${ticket.id}/transfer`, adminToken, body);
    const lawyerTotal = async () => Number((await sql('SELECT COALESCE(SUM(amount), 0) AS total FROM lawyer_adjustments WHERE lawyer_id = $1', [lawyerId]))[0].total);

    assert.equal((await transfer({ from: 'lawyer', amount: 100, reason: 'تعويض الموكل' })).status, 200);
    assert.equal(await clientBalance(), 100);
    assert.equal(await lawyerTotal(), -100);

    assert.equal((await transfer({ from: 'client', amount: 40, reason: 'تصحيح المبلغ' })).status, 200);
    assert.equal(await clientBalance(), 60);
    assert.equal(await lawyerTotal(), -60);

    assert.equal((await transfer({ from: 'lawyer', amount: 0, reason: 'مبلغ غير صحيح' })).status, 400);
    assert.equal((await transfer({ from: 'nobody', amount: 10, reason: 'اتجاه غير صحيح' })).status, 400);
    assert.equal(await clientBalance(), 60);
  });

  it('إغلاق التذكرة ما بيغيرش الفلوس، والقرار من صفحة الطلب', async () => {
    const order = await createCompletedOrder();
    const ticket = (await openTicket(clientToken, order.id)).body.data;
    assert.equal((await wallet()).frozenBalance, 350);

    assert.equal((await call('POST', `/admin/support/${ticket.id}/close`, adminToken, { outcome: 'REFUND' })).status, 200);
    assert.equal(await clientBalance(), 0);
    assert.equal((await wallet()).frozenBalance, 350);

    assert.equal((await call('POST', `/admin/orders/${order.id}/settle`, adminToken, { outcome: 'REFUND' })).status, 200);
    assert.equal(await clientBalance(), 350);
    assert.equal((await wallet()).frozenBalance, 0);
  });
});
