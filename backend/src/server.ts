import { buildApp } from './app.js';
import { config } from './config/index.js';
import { runMigrations } from './database/migrate.js';
import { dbPool } from './database/index.js';
import { sweepLifecycle } from './modules/lifecycle/sweep.js';

async function start() {
  try {
    // 1. Code that runs on an older database could corrupt orders and money, so a failure stops here
    await runMigrations(false);

    // 2. Build Fastify application
    const app = buildApp();

    // 3. Listen on configured host and port
    const address = await app.listen({
      port: config.port,
      host: config.host,
    });
    console.log(`[MyLawyer Backend] Server running at ${address}`);

    // 4. Time-based order steps: reminders, deadlines, payout release, review publishing.
    // A slow round finishes before the next one starts.
    let sweeping: Promise<void> | null = null;
    const sweepTimer = setInterval(() => {
      sweeping ??= sweepLifecycle()
        .catch((err) => console.error('[MyLawyer Backend] Lifecycle sweep error:', err))
        .finally(() => { sweeping = null; });
    }, 3_000);

    // 5. A release restarts the server, so open requests and the current round finish first
    let stopping = false;
    const stop = async (signal: string) => {
      if (stopping) return;
      stopping = true;
      console.log(`[MyLawyer Backend] ${signal} received, stopping`);
      clearInterval(sweepTimer);
      try {
        await app.close();
        await sweeping;
        await dbPool.end();
        process.exit(0);
      } catch (err) {
        console.error('[MyLawyer Backend] Error while stopping:', err);
        process.exit(1);
      }
    };
    process.on('SIGTERM', () => stop('SIGTERM'));
    process.on('SIGINT', () => stop('SIGINT'));
  } catch (err) {
    console.error('[MyLawyer Backend] Fatal server startup error:', err);
    process.exit(1);
  }
}

start();
