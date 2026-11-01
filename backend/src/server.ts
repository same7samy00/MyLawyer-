import { buildApp } from './app.js';
import { config } from './config/index.js';
import { runMigrations } from './database/migrate.js';
import { sweepLifecycle } from './modules/lifecycle/service.js';

async function start() {
  try {
    // 1. Ensure latest database migrations are applied
    try {
      await runMigrations(false);
    } catch (migErr: any) {
      console.error('[MyLawyer Backend] Migration error during startup:', migErr?.message || migErr);
    }

    // 2. Build Fastify application
    const app = buildApp();

    // 3. Listen on configured host and port
    const address = await app.listen({
      port: config.port,
      host: config.host,
    });
    console.log(`[MyLawyer Backend] Server running at ${address}`);

    // 4. Time-based order steps: reminders, deadlines, payout release, review publishing
    setInterval(() => {
      sweepLifecycle().catch((err) => console.error('[MyLawyer Backend] Lifecycle sweep error:', err));
    }, 3_000);

    console.log(`[MyLawyer Backend] Swagger docs available at ${address}/docs`);
  } catch (err) {
    console.error('[MyLawyer Backend] Fatal server startup error:', err);
    process.exit(1);
  }
}

start();
