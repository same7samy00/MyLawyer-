import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dbPool, withTransaction } from './index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function runMigrations(closePool = false): Promise<number> {
  console.log('[MIGRATIONS] Checking PostgreSQL Migrations...');

  // 1. Create migrations tracking table if not exists
  await dbPool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  // Baseline check: If core tables already exist from previous deployments before
  // the migration runner was added, mark 001_initial_schema.sql as applied so it
  // doesn't attempt to re-run and collide with existing structures or permissions.
  const { rows: baselineCheck } = await dbPool.query(`
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'users'
  `);
  if (baselineCheck.length > 0) {
    await dbPool.query(`
      INSERT INTO schema_migrations (name) 
      VALUES ('001_initial_schema.sql') 
      ON CONFLICT (name) DO NOTHING;
    `);
  }

  // 2. Discover migration files
  const candidateDirs = [
    path.resolve(process.cwd(), 'migrations'),
    path.resolve(__dirname, '../../migrations'),
    path.resolve(__dirname, '../migrations'),
    '/var/www/mylawyer/backend/migrations',
  ];

  const migrationsDir = candidateDirs.find((dir) => fs.existsSync(dir));

  if (!migrationsDir) {
    console.error(`[MIGRATIONS] ERROR: No migrations directory found! Checked: ${candidateDirs.join(', ')}`);
    if (closePool) await dbPool.end();
    throw new Error('Migrations directory not found');
  }

  console.log(`[MIGRATIONS] Using migrations directory: ${migrationsDir}`);

  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    console.log('[MIGRATIONS] No SQL migration files found.');
    if (closePool) await dbPool.end();
    return 0;
  }

  // 3. Fetch already applied migrations
  const { rows: appliedRows } = await dbPool.query('SELECT name FROM schema_migrations');
  const appliedSet = new Set(appliedRows.map(r => r.name));

  let appliedCount = 0;

  for (const file of files) {
    if (appliedSet.has(file)) {
      continue;
    }

    console.log(`[MIGRATIONS] Applying ${file}...`);
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf-8');

    await withTransaction(async (client) => {
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
    });

    console.log(`[MIGRATIONS] Successfully applied ${file}`);
    appliedCount++;
  }

  if (appliedCount > 0) {
    console.log(`[MIGRATIONS] Finished applying ${appliedCount} new migration(s).`);
  } else {
    console.log('[MIGRATIONS] Database schema is up to date.');
  }

  if (closePool) {
    await dbPool.end();
  }

  return appliedCount;
}

// If executed directly from command line
if (process.argv[1] && process.argv[1].includes('migrate')) {
  runMigrations(true).catch((err) => {
    console.error('[MIGRATIONS] Fatal Migration Error:', err);
    process.exit(1);
  });
}
