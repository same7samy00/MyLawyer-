const MAX_FAILURES = 10;
const WINDOW_MS = 10 * 60 * 1000;
const MAX_TRACKED = 50_000;

const failures = new Map<string, { count: number; until: number }>();

/// Guessing one account's password from many addresses stops here, the address limit can't see it.
/// Kept in memory, so with several server copies each one counts on its own.
export function isLoginLocked(identifier: string): boolean {
  const entry = failures.get(identifier);
  if (!entry) return false;
  if (entry.until <= Date.now()) {
    failures.delete(identifier);
    return false;
  }
  return entry.count >= MAX_FAILURES;
}

export function recordLoginFailure(identifier: string) {
  if (failures.size >= MAX_TRACKED) failures.clear();
  const entry = failures.get(identifier);
  if (entry && entry.until > Date.now()) entry.count += 1;
  else failures.set(identifier, { count: 1, until: Date.now() + WINDOW_MS });
}

export function clearLoginFailures(identifier: string) {
  failures.delete(identifier);
}
