import cluster, { Worker } from 'node:cluster';
import fs from 'node:fs';
import path from 'node:path';
import { buildApp } from './app.js';
import { config } from './config/index.js';
import { runMigrations } from './database/migrate.js';
import { dbPool } from './database/index.js';
import { sweepLifecycle } from './modules/lifecycle/sweep.js';
import { startLiveUpdates, stopLiveUpdates } from './services/liveUpdates.js';
import { closeFastMemory } from './services/fastMemory.js';

const WORKERS = Math.max(1, Number(process.env.WEB_WORKERS) || 1);
const RESTART_WAIT_MS = 1_000;
const SWEEP_EVERY_MS = 3_000;
// One number for the whole database, so only one process runs the time-based steps at a time
const SWEEP_LOCK = 4_242_001;
// A new worker that does not answer in this time is dropped, and the old ones keep serving
const NEW_WORKER_WAIT_MS = 30_000;

/// The main process owns migrations and the workers. A release replaces the workers one by one (SIGHUP),
/// so the address never stops answering.
async function startMain() {
  // Code that runs on an older database could corrupt orders and money, so a failure stops here
  await runMigrations(false);

  let stopping = false;
  let reloading = false;
  const replaced = new Set<number>();
  const starting = new Set<number>();

  const fork = () => cluster.fork();
  for (let i = 0; i < WORKERS; i++) fork();

  cluster.on('exit', (worker) => {
    // A worker retired by a reload is not replaced again, and a new one that failed to start
    // is not retried in a loop: the reload stops and the old workers keep serving
    if (stopping || replaced.delete(worker.id) || starting.delete(worker.id)) return;
    console.error(`[MyLawyer Backend] Worker ${worker.process.pid} stopped, starting another`);
    setTimeout(fork, RESTART_WAIT_MS);
  });

  const startReplacement = () => new Promise<Worker>((resolve, reject) => {
    const next = fork();
    starting.add(next.id);
    const timer = setTimeout(() => {
      next.process.kill('SIGTERM');
      reject(new Error('The new worker did not start listening'));
    }, NEW_WORKER_WAIT_MS);
    next.once('listening', () => { clearTimeout(timer); starting.delete(next.id); resolve(next); });
    next.once('exit', () => { clearTimeout(timer); reject(new Error('The new worker stopped while starting')); });
  });

  const reload = async () => {
    if (reloading || stopping) return;
    reloading = true;
    console.log('[MyLawyer Backend] Reload: new migrations, then the workers one by one');
    try {
      await runMigrations(false);
      const old = Object.values(cluster.workers ?? {}).filter((w): w is Worker => Boolean(w));
      for (const worker of old) {
        await startReplacement();
        replaced.add(worker.id);
        // The old worker finishes its open requests before it stops
        worker.process.kill('SIGTERM');
      }
      console.log('[MyLawyer Backend] Reload finished');
    } catch (err) {
      console.error('[MyLawyer Backend] Reload stopped, the running workers keep serving:', err);
    } finally {
      reloading = false;
    }
  };

  const stop = async (signal: string) => {
    if (stopping) return;
    stopping = true;
    console.log(`[MyLawyer Backend] ${signal} received, stopping`);
    for (const worker of Object.values(cluster.workers ?? {})) worker?.process.kill('SIGTERM');
    await new Promise<void>((resolve) => {
      const check = () => (Object.keys(cluster.workers ?? {}).length === 0 ? resolve() : setTimeout(check, 100));
      check();
    });
    await dbPool.end();
    process.exit(0);
  };
  process.on('SIGHUP', () => void reload());
  process.on('SIGTERM', () => stop('SIGTERM'));
  process.on('SIGINT', () => stop('SIGINT'));
}

/// Every worker offers to run the time-based steps, and the database lock lets one at a time.
/// So the steps keep running while workers are replaced, and always with the newest code.
function startSweeping() {
  let sweeping: Promise<void> | null = null;
  const timer = setInterval(() => {
    sweeping ??= (async () => {
      const client = await dbPool.connect();
      try {
        const lock = await client.query('SELECT pg_try_advisory_lock($1) AS taken', [SWEEP_LOCK]);
        if (!lock.rows[0].taken) return;
        try {
          await sweepLifecycle();
        } finally {
          await client.query('SELECT pg_advisory_unlock($1)', [SWEEP_LOCK]);
        }
      } finally {
        client.release();
      }
    })()
      .catch((err) => console.error('[MyLawyer Backend] Lifecycle sweep error:', err))
      .finally(() => { sweeping = null; });
  }, SWEEP_EVERY_MS);
  return async () => {
    clearInterval(timer);
    await sweeping;
  };
}

/// The release this code came from, written by deploy.sh. Empty on a developer's machine.
function releaseId(): string {
  try {
    return fs.readFileSync(path.resolve(process.cwd(), 'dist/RELEASE'), 'utf-8').trim();
  } catch {
    return '';
  }
}

async function startWorker() {
  process.env.MYLAWYER_RELEASE = releaseId();
  const app = buildApp();
  await app.listen({ port: config.port, host: config.host });
  startLiveUpdates();
  const stopSweeping = startSweeping();

  // A release restarts the workers, so open requests finish first
  let stopping = false;
  const stop = async () => {
    if (stopping) return;
    stopping = true;
    try {
      await stopSweeping();
      await stopLiveUpdates();
      await app.close();
      await closeFastMemory();
      await dbPool.end();
      process.exit(0);
    } catch (err) {
      console.error('[MyLawyer Backend] Error while stopping:', err);
      process.exit(1);
    }
  };
  // A reload is the main process's job, a worker only stops when told to
  process.on('SIGHUP', () => {});
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

(cluster.isPrimary ? startMain() : startWorker()).catch((err) => {
  console.error('[MyLawyer Backend] Fatal server startup error:', err);
  process.exit(1);
});
