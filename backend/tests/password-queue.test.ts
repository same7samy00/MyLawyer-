import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { hashPassword, verifyPassword } from '../src/utils/security.js';

describe('طابور حماية كلمة السر', () => {
  it('كتير في نفس اللحظة: كلهم بيخلصوا بدورهم من غير ولا خطأ، والغلط بيفضل غلط', async () => {
    const hash = await hashPassword('Secret-123');
    const checks = await Promise.all(Array.from({ length: 12 }, (_, i) => verifyPassword(hash, i % 3 === 0 ? 'wrong' : 'Secret-123')));
    assert.equal(checks.filter(Boolean).length, 8);
    assert.equal(checks.filter((ok) => !ok).length, 4);
  });
});
