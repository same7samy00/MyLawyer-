import { Job, Queue, Worker } from 'bullmq';
import { Redis } from 'ioredis';
import { config } from '../config/index.js';

/// Work that leaves the server: notifications, wakes and emails. It waits in a queue in the fast memory, so
/// it isn't lost when a worker stops, a failure is tried again a few times, and any worker on either server
/// can do it. Without the fast memory, or while it doesn't answer, the work is done right away as before.
const QUEUE = 'outbox';
const ATTEMPTS = 5;
const CONCURRENCY = 20;

export type JobKind = 'push' | 'push-device' | 'wake' | 'wake-device' | 'otp-email';

interface Handler {
  run: (data: any) => Promise<void>;
  /// Older than this, the work no longer means anything (an old wake, an expired code), so it is dropped
  maxAgeMs: number;
}

const handlers = new Map<JobKind, Handler>();

/// A failure that trying again can't fix, like a bad address. The job stops without more attempts
export class FinalFailure extends Error {}

export function handleJob(kind: JobKind, maxAgeMs: number, run: (data: any) => Promise<void>) {
  handlers.set(kind, { run, maxAgeMs });
}

let queue: Queue | null = null;
let worker: Worker | null = null;

function queueConnection() {
  return new Redis(config.redisUrl, { maxRetriesPerRequest: 1, enableOfflineQueue: false, commandTimeout: 1000 });
}

function getQueue(): Queue | null {
  if (!config.redisUrl) return null;
  if (!queue) {
    queue = new Queue(QUEUE, {
      connection: queueConnection(),
      defaultJobOptions: {
        attempts: ATTEMPTS,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: true,
        // A failed job is kept a day to look at, then removed
        removeOnFail: { age: 24 * 3600, count: 5000 },
      },
    });
    queue.on('error', (err) => console.error('[MyLawyer Backend] Queue:', err.message));
  }
  return queue;
}

async function runNow(kind: JobKind, data: object) {
  try {
    await handlers.get(kind)?.run(data);
  } catch (err) {
    console.error(`[MyLawyer Backend] ${kind} failed:`, err instanceof Error ? err.message : err);
  }
}

/// Puts the work in the queue. Never throws: if the queue doesn't take it, it is done right away instead
export async function enqueue(kind: JobKind, data: object) {
  const target = getQueue();
  if (target) {
    try {
      await target.add(kind, data);
      return;
    } catch (err) {
      console.error('[MyLawyer Backend] Queue add failed, sending right away:', err instanceof Error ? err.message : err);
    }
  }
  await runNow(kind, data);
}

/// Every web worker also does queued work, so the queue grows with the workers. JOB_WORKER=off keeps a server
/// out of it: the second server sends no email, the signed mail server is on the main one
export function startJobWorker() {
  if (!config.redisUrl || process.env.JOB_WORKER === 'off') return;
  worker = new Worker(
    QUEUE,
    async (job: Job) => {
      const handler = handlers.get(job.name as JobKind);
      if (!handler || Date.now() - job.timestamp > handler.maxAgeMs) return;
      try {
        await handler.run(job.data);
      } catch (err) {
        if (err instanceof FinalFailure) job.discard();
        throw err;
      }
    },
    {
      connection: new Redis(config.redisUrl, { maxRetriesPerRequest: null }),
      concurrency: CONCURRENCY,
    },
  );
  worker.on('error', (err) => console.error('[MyLawyer Backend] Queue worker:', err.message));
  worker.on('failed', (job, err) => {
    if (job && (job.attemptsMade >= ATTEMPTS || err instanceof FinalFailure)) {
      console.error(`[MyLawyer Backend] ${job.name} gave up:`, err.message);
    }
  });
}

export async function stopJobQueue() {
  await worker?.close().catch(() => undefined);
  worker = null;
  await queue?.close().catch(() => undefined);
  queue = null;
}
