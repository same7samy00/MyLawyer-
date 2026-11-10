import { Redis } from 'ioredis';
import { config } from '../config/index.js';

/// The fast memory (Redis) shared by every worker on both servers: request limits, sign-in guesses and
/// the live position on the way to a meeting. Without REDIS_URL, or while it is down, each worker falls back
/// to counting on its own, so the app keeps working.
let shared: Redis | null = null;

export function fastMemory(): Redis | null {
  if (!config.redisUrl) return null;
  shared ??= newConnection();
  return shared;
}

/// A connection of its own, for listening: a listening connection can't send other commands
export function newConnection(): Redis {
  const connection = new Redis(config.redisUrl, {
    // A command waits at most this long, then the caller falls back instead of hanging a request
    commandTimeout: 500,
    maxRetriesPerRequest: 1,
    enableOfflineQueue: false,
    retryStrategy: (times) => Math.min(times * 200, 3000),
  });
  connection.on('error', (err) => console.error('[MyLawyer Backend] Fast memory:', err.message));
  return connection;
}

/// An account seen active is remembered this long, so a request doesn't ask the database «is this account
/// suspended?» every time. A suspension forgets it at once, on every worker
const ACTIVE_SECONDS = 30;
const activeKey = (userId: string) => `active:${userId}`;

export async function knownActive(userId: string): Promise<boolean> {
  try {
    return (await fastMemory()?.get(activeKey(userId))) === '1';
  } catch {
    return false;
  }
}

export function rememberActive(userId: string) {
  fastMemory()?.set(activeKey(userId), '1', 'EX', ACTIVE_SECONDS).catch(() => undefined);
}

export async function forgetActive(userId: string) {
  await fastMemory()?.del(activeKey(userId)).catch(() => undefined);
}

/// Whether the fast memory answers, for the health check
export async function fastMemoryState(): Promise<'CONNECTED' | 'OFF' | 'ERROR'> {
  const memory = fastMemory();
  if (!memory) return 'OFF';
  try {
    return (await memory.ping()) === 'PONG' ? 'CONNECTED' : 'ERROR';
  } catch {
    return 'ERROR';
  }
}

export async function closeFastMemory() {
  await shared?.quit().catch(() => undefined);
  shared = null;
}
