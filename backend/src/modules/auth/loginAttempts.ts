import { fastMemory } from '../../services/fastMemory.js';

const MAX_FAILURES = 10;
const WINDOW_SECONDS = 10 * 60;
const MAX_TRACKED = 50_000;
const KEY = (identifier: string) => `login-fail:${identifier}`;

/// Used only when the fast memory is off or not answering: then each worker counts on its own
const failures = new Map<string, { count: number; until: number }>();

/// Guessing one account's password from many addresses stops here, the address limit can't see it.
/// Counted in the fast memory, so every worker on both servers sees the same count.
export async function isLoginLocked(identifier: string): Promise<boolean> {
  const memory = fastMemory();
  if (memory) {
    try {
      return Number(await memory.get(KEY(identifier))) >= MAX_FAILURES;
    } catch {
      // Falls back to this worker's own count
    }
  }
  const entry = failures.get(identifier);
  if (!entry) return false;
  if (entry.until <= Date.now()) {
    failures.delete(identifier);
    return false;
  }
  return entry.count >= MAX_FAILURES;
}

export async function recordLoginFailure(identifier: string) {
  const memory = fastMemory();
  if (memory) {
    try {
      // The window starts with the first failure and isn't pushed back by later ones
      await memory.multi().incr(KEY(identifier)).expire(KEY(identifier), WINDOW_SECONDS, 'NX').exec();
      return;
    } catch {
      // Falls back to this worker's own count
    }
  }
  if (failures.size >= MAX_TRACKED) failures.clear();
  const entry = failures.get(identifier);
  if (entry && entry.until > Date.now()) entry.count += 1;
  else failures.set(identifier, { count: 1, until: Date.now() + WINDOW_SECONDS * 1000 });
}

export async function clearLoginFailures(identifier: string) {
  failures.delete(identifier);
  await fastMemory()?.del(KEY(identifier)).catch(() => undefined);
}
