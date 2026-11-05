import cluster from 'node:cluster';
import { buildApp } from './app.js';
import { config } from './config/index.js';
import { runMigrations } from './database/migrate.js';
import { dbPool } from './database/index.js';
import { sweepLifecycle } from './modules/lifecycle/sweep.js';
import { startLiveUpdates, stopLiveUpdates } from './services/liveUpdates.js';

const WORKERS = Math.max(1, Number(process.env.WEB_WORKERS) || 1);
const RESTART_WAIT_MS = 1_000;

/// The main process owns migrations and the time-based steps, so they run once
async function startMain() {
  // Code that runs on an older database could corrupt orders and money, so a failure stops here
  await runMigrations(false);

  let stopping = false;
  for (let i = 0; i < WORKERS; i++) cluster.fork();
  cluster.on('exit', (worker) => {
    if (stopping) return;
    console.error(`[MyLawyer Backend] Worker ${worker.process.pid} stopped, starting another`);
    setTimeout(() => cluster.fork(), RESTART_WAIT_MS);
  });

  // A slow round finishes before the next one starts
  let sweeping: Promise<void> | null = null;
  const sweepTimer = setInterval(() => {
    sweeping ??= sweepLifecycle()
      .catch((err) => console.error('[MyLawyer Backend] Lifecycle sweep error:', err))
      .finally(() => { sweeping = null; });
  }, 3_000);

  const stop = async (signal: string) => {
    if (stopping) return;
    stopping = true;
    console.log(`[MyLawyer Backend] ${signal} received, stopping`);
    clearInterval(sweepTimer);
    for (const worker of Object.values(cluster.workers ?? {})) worker?.process.kill('SIGTERM');
    await sweeping;
    await new Promise<void>((resolve) => {
      const check = () => (Object.keys(cluster.workers ?? {}).length === 0 ? resolve() : setTimeout(check, 100));
      check();
    });
    await dbPool.end();
    process.exit(0);
  };
  process.on('SIGTERM', () => stop('SIGTERM'));
  process.on('SIGINT', () => stop('SIGINT'));
}

async function startWorker() {
  const app = buildApp();
  await app.listen({ port: config.port, host: config.host });
  startLiveUpdates();

  // A release restarts the server, so open requests finish first
  let stopping = false;
  const stop = async () => {
    if (stopping) return;
    stopping = true;
    try {
      await stopLiveUpdates();
      await app.close();
      await dbPool.end();
      process.exit(0);
    } catch (err) {
      console.error('[MyLawyer Backend] Error while stopping:', err);
      process.exit(1);
    }
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

(cluster.isPrimary ? startMain() : startWorker()).catch((err) => {
  console.error('[MyLawyer Backend] Fatal server startup error:', err);
  process.exit(1);
});
