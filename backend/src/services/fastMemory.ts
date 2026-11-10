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
