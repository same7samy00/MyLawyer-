import crypto from 'crypto';
import argon2 from 'argon2';

/// Each password check takes 64 MB and a core for a moment. In a crowd (an ad, a launch) they wait
/// in line here instead of all running at once and failing (load test 2026-11-07: 3-4% errors at
/// 100-200 at once). A few run together per worker; the rest wait their turn.
const PASSWORD_SLOTS = Number(process.env.PASSWORD_SLOTS || 2);
/// Past this wait the person gets «busy, try again in a moment» (503), which the app retries by itself
const PASSWORD_MAX_WAIT_MS = 20_000;
let running = 0;
const waiting: Array<() => void> = [];

export class BusyError extends Error {}

async function inLine<T>(work: () => Promise<T>): Promise<T> {
  if (running >= PASSWORD_SLOTS) {
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        const at = waiting.indexOf(go);
        if (at >= 0) waiting.splice(at, 1);
        reject(new BusyError('busy'));
      }, PASSWORD_MAX_WAIT_MS);
      const go = () => {
        clearTimeout(timer);
        resolve();
      };
      waiting.push(go);
    });
  } else {
    running++;
  }
  try {
    return await work();
  } finally {
    const next = waiting.shift();
    if (next) next();
    else running--;
  }
}

/**
 * Hashes password securely using Argon2id
 */
export async function hashPassword(plainPassword: string): Promise<string> {
  return inLine(() => argon2.hash(plainPassword, {
    type: argon2.argon2id,
    memoryCost: 65536, // 64 MB
    timeCost: 3,
    parallelism: 1,
  }));
}

/**
 * Verifies password with Argon2id hash. A wrong password is false; a busy server is a BusyError,
 * never a «wrong password».
 */
export async function verifyPassword(hash: string, plainPassword: string): Promise<boolean> {
  return inLine(async () => {
    try {
      return await argon2.verify(hash, plainPassword);
    } catch {
      return false;
    }
  });
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

