import { fastMemory } from '../../services/fastMemory.js';

/// Two counts, like the big apps, so a stranger can't lock someone else out by typing wrong passwords:
/// - one address on one account: 10 wrong in 10 minutes stops that address only;
/// - the account from everywhere: 50 wrong in an hour means guessing from many addresses, and stops the account.
const LIMITS = {
  address: { max: 10, seconds: 10 * 60 },
  account: { max: 50, seconds: 60 * 60 },
} as const;
const MAX_TRACKED = 50_000;
type Kind = keyof typeof LIMITS;
const key = (kind: Kind, identifier: string, ip: string) => (kind === 'address' ? `login-fail:${identifier}:${ip}` : `login-fail:${identifier}`);

/// Used only when the fast memory is off or not answering: then each worker counts on its own
const failures = new Map<string, { count: number; until: number }>();

function localCount(k: string): number {
  const entry = failures.get(k);
  if (!entry) return 0;
  if (entry.until <= Date.now()) {
    failures.delete(k);
    return 0;
  }
  return entry.count;
}

/// Counted in the fast memory, so every worker on both servers sees the same counts
export async function isLoginLocked(identifier: string, ip: string): Promise<boolean> {
  const kinds = Object.keys(LIMITS) as Kind[];
  const memory = fastMemory();
  if (memory) {
    try {
      const counts = await memory.mget(...kinds.map((kind) => key(kind, identifier, ip)));
      return kinds.some((kind, i) => Number(counts[i]) >= LIMITS[kind].max);
    } catch {
      // Falls back to this worker's own count
    }
  }
  return kinds.some((kind) => localCount(key(kind, identifier, ip)) >= LIMITS[kind].max);
}

export async function recordLoginFailure(identifier: string, ip: string) {
  const memory = fastMemory();
  if (memory) {
    try {
      const batch = memory.multi();
      // Each window starts with the first failure and isn't pushed back by later ones
      for (const kind of Object.keys(LIMITS) as Kind[]) batch.incr(key(kind, identifier, ip)).expire(key(kind, identifier, ip), LIMITS[kind].seconds, 'NX');
      await batch.exec();
      return;
    } catch {
      // Falls back to this worker's own count
    }
  }
  if (failures.size >= MAX_TRACKED) failures.clear();
  for (const kind of Object.keys(LIMITS) as Kind[]) {
    const k = key(kind, identifier, ip);
    const count = localCount(k);
    failures.set(k, { count: count + 1, until: count === 0 ? Date.now() + LIMITS[kind].seconds * 1000 : failures.get(k)!.until });
  }
}

/// A right password clears this address's count. The account count stays, so a guess that lands doesn't
/// wipe the trace of many wrong ones
export async function clearLoginFailures(identifier: string, ip: string) {
  failures.delete(key('address', identifier, ip));
  await fastMemory()?.del(key('address', identifier, ip)).catch(() => undefined);
}
