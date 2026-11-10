import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { app, adminToken, clientId, clientToken, call, sql } from './harness.js';
import { forgetAppVersion } from '../src/modules/appClient/routes.js';

const withBuild = (build: string, token: string | null = clientToken) =>
  app.inject({ method: 'GET', url: '/api/v1/notifications/summary', headers: { 'x-app-build': build, ...(token ? { authorization: `Bearer ${token}` } : {}) } });

describe('التحديث الإجباري وأعطال التطبيق', () => {
  it('النسخة الأقدم من المسموح بتاخد «حدّث التطبيق» في أي طلب، والأحدث واللي من غير رقم بيعدّوا', async () => {
    const saved = await call('POST', '/admin/app-version', adminToken, { minBuild: 5, updateUrl: 'https://my-lawyer.online/app' });
    assert.equal(saved.status, 200, JSON.stringify(saved.body));
    try {
      const old = await withBuild('4');
      assert.equal(old.statusCode, 426);
      assert.equal(old.json().data.status, 'update_required');
      assert.equal(old.json().data.updateUrl, 'https://my-lawyer.online/app');
      assert.equal((await withBuild('5')).statusCode, 200);
      assert.equal((await call('GET', '/notifications/summary', clientToken)).status, 200, 'the control page and the site send no build');
      assert.deepEqual((await call('GET', '/admin/app-version', adminToken)).body.data, { minBuild: 5, updateUrl: 'https://my-lawyer.online/app' });
    } finally {
      await sql('UPDATE platform_settings SET min_app_build = 0, app_update_url = NULL');
      forgetAppVersion();
    }
    assert.equal((await withBuild('4')).statusCode, 200);
  });

  it('أقل نسخة بيغيّرها الإدارة بس، والرابط لازم https', async () => {
    assert.equal((await call('POST', '/admin/app-version', clientToken, { minBuild: 9 })).status, 403);
    assert.equal((await call('POST', '/admin/app-version', adminToken, { minBuild: -1 })).status, 400);
    assert.equal((await call('POST', '/admin/app-version', adminToken, { minBuild: 2, updateUrl: 'http://example.test' })).status, 400);
    assert.equal(Number((await sql('SELECT min_app_build FROM platform_settings'))[0].min_app_build), 0);
  });

  it('عطل التطبيق بيتسجل بصاحبه ونسخته، ومن غير دخول كمان، وبيتقص لو طويل', async () => {
    await sql('DELETE FROM app_errors');
    const signedIn = await app.inject({
      method: 'POST', url: '/api/v1/app/errors',
      headers: { authorization: `Bearer ${clientToken}`, 'x-app-build': '7' },
      payload: { message: 'Null check operator used on a null value', stack: 'x'.repeat(9000), platform: 'android' },
    });
    assert.equal(signedIn.statusCode, 201);
    assert.equal((await call('POST', '/app/errors', null, { message: 'قبل الدخول' })).status, 201);
    assert.equal((await call('POST', '/app/errors', null, {})).status, 400);

    const rows = await sql('SELECT user_id, app_build, platform, length(stack) AS stack FROM app_errors ORDER BY id');
    assert.equal(rows.length, 2);
    assert.equal(rows[0].user_id, clientId);
    assert.equal(rows[0].app_build, 7);
    assert.equal(rows[0].platform, 'android');
    assert.ok(rows[0].stack <= 4000);
    assert.equal(rows[1].user_id, null);
  });
});
