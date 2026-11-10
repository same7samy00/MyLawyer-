import crypto from 'crypto';
import { query } from '../../database/index.js';
import { sendOtpEmail } from '../../services/emailService.js';
import { OTP_VALID_MS, takeAttempt } from './codes.js';

/// The control page's second step (2026-11-10): the password alone doesn't open it. A 6-digit code goes by
/// email, to ADMIN_CODE_EMAIL when set (the owner's inbox that already gets the server alerts), else the
/// admin's own email. Tests and a developer's machine skip it unless ADMIN_LOGIN_CODE=on.
export function adminCodeRequired(): boolean {
  const setting = process.env.ADMIN_LOGIN_CODE;
  if (setting === 'off') return false;
  if (setting === 'on') return true;
  return process.env.NODE_ENV === 'production';
}

const hash = (userId: string, code: string) => crypto.createHash('sha256').update(`${userId}:${code}`).digest('hex');

/// Makes a new code and sends it. Returns where it went, partly hidden, for the page to say
export async function sendAdminCode(user: { id: string; email: string }): Promise<string> {
  const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
  await query('UPDATE admin_login_codes SET consumed_at = NOW() WHERE user_id = $1 AND consumed_at IS NULL', [user.id]);
  await query(
    'INSERT INTO admin_login_codes (user_id, code_hash, expires_at) VALUES ($1, $2, $3)',
    [user.id, hash(user.id, code), new Date(Date.now() + OTP_VALID_MS)],
  );
  const to = process.env.ADMIN_CODE_EMAIL || user.email;
  await sendOtpEmail(to, code, 'admin_login');
  return to.replace(/^(.{2}).*(@.*)$/, '$1***$2');
}

/// One guess on the newest code. Right once, then it can't be used again
export async function checkAdminCode(userId: string, code: string): Promise<boolean> {
  const res = await query(
    `SELECT id, code_hash FROM admin_login_codes
     WHERE user_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [userId],
  );
  const row = res.rows[0];
  if (!row || !(await takeAttempt('admin_login_codes', row.id))) return false;
  const expected = Buffer.from(row.code_hash, 'hex');
  const given = Buffer.from(hash(userId, code), 'hex');
  if (expected.length !== given.length || !crypto.timingSafeEqual(expected, given)) return false;
  const used = await query('UPDATE admin_login_codes SET consumed_at = NOW() WHERE id = $1 AND consumed_at IS NULL RETURNING id', [row.id]);
  return (used.rowCount ?? 0) > 0;
}
