import { query } from '../../database/index.js';

export const OTP_RESEND_SECONDS = 60;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_VALID_MS = 10 * 60 * 1000;

/// Counts one guess on a code in a single step, and says no once the limit is reached
export async function takeAttempt(table: 'email_verifications' | 'password_reset_requests' | 'admin_login_codes', id: string): Promise<boolean> {
  const res = await query(
    `UPDATE ${table} SET attempts = attempts + 1 WHERE id = $1 AND attempts < $2 RETURNING id`,
    [id, OTP_MAX_ATTEMPTS]
  );
  return (res.rowCount ?? 0) > 0;
}
