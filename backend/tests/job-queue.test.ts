import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

process.env.NODE_ENV = 'test';
const { enqueue, handleJob, FinalFailure } = await import('../src/services/jobQueue.js');

// Tests run without the fast memory, the way a developer's machine does, so the work is done right away
describe('الطابور من غير الذاكرة السريعة', () => {
  it('الشغل بيتعمل على طول بنفس البيانات', async () => {
    const done: object[] = [];
    handleJob('otp-email', 60_000, async (data) => {
      done.push(data);
    });
    await enqueue('otp-email', { toEmail: 'a@example.test', otpCode: '123456', purpose: 'register' });
    assert.deepEqual(done, [{ toEmail: 'a@example.test', otpCode: '123456', purpose: 'register' }]);
  });

  it('الفشل ما بيوقعش الطلب اللي طلب الشغل', async () => {
    handleJob('push-device', 60_000, async () => {
      throw new Error('Firebase answered 503');
    });
    handleJob('wake-device', 60_000, async () => {
      throw new FinalFailure('Firebase refused the message: 400');
    });
    await assert.doesNotReject(enqueue('push-device', { token: 'x' }));
    await assert.doesNotReject(enqueue('wake-device', { token: 'x' }));
  });

  it('شغل الشخص بيتقسم لشغل لكل موبايل', async () => {
    const phones: string[] = [];
    handleJob('push-device', 60_000, async ({ token }) => {
      phones.push(token);
    });
    handleJob('push', 60_000, async ({ tokens }) => {
      for (const token of tokens) await enqueue('push-device', { token });
    });
    await enqueue('push', { tokens: ['one', 'two'] });
    assert.deepEqual(phones, ['one', 'two']);
  });
});
