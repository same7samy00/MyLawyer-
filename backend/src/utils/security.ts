import crypto from 'crypto';
import argon2 from 'argon2';

/**
 * Hashes password securely using Argon2id
 */
export async function hashPassword(plainPassword: string): Promise<string> {
  return argon2.hash(plainPassword, {
    type: argon2.argon2id,
    memoryCost: 65536, // 64 MB
    timeCost: 3,
    parallelism: 1,
  });
}

/**
 * Verifies password with Argon2id hash
 */
export async function verifyPassword(hash: string, plainPassword: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plainPassword);
  } catch {
    return false;
  }
}

/**
 * Generates a random 6-digit numeric OTP
 */
export function generateOtpCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

/// "أحمد محمد علي" becomes "أحمد م.", enough to confirm the person without the full name
export function shortName(fullName: string | null | undefined, fallback = ''): string {
  const [first, second] = (fullName || '').trim().split(/\s+/);
  if (!first) return fallback;
  return second ? `${first} ${[...second][0]}.` : first;
}

/**
 * Hashes an OTP code or Token with SHA-256 for secure database storage
 */
export function hashSha256(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

/**
 * Generates a cryptographically secure random token (e.g. for refresh token)
 */
export function generateSecureToken(bytes = 32): string {
  return crypto.randomBytes(bytes).toString('hex');
}

/**
 * Validates Egyptian Phone Number: starts with 010, 011, 012, or 015, exactly 11 digits
 */
export function isValidEgyptianPhone(phone: string): boolean {
  return /^01[0125][0-9]{8}$/.test(phone.trim());
}

/**
 * Sanitizes generic user text to prevent XSS
 */
export function sanitizeText(text: string, maxLength = 500): string {
  if (!text) return '';
  return text
    .replace(/[<>]/g, '')
    .trim()
    .slice(0, maxLength);
}

