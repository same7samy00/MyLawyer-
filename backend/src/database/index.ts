import pg from 'pg';
import { config } from '../config/index.js';

const { Pool } = pg;

export type Db = pg.Pool | pg.PoolClient;

export const dbPool = new Pool({
  connectionString: config.databaseUrl,
  // Each worker has its own pool, and all of them must stay under PostgreSQL's limit
  max: Number(process.env.DB_POOL_MAX) || 15,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

dbPool.on('error', (err) => {
  console.error('Unexpected error on idle PostgreSQL client:', err);
});

export async function query<T extends pg.QueryResultRow = any>(text: string, params?: any[]): Promise<pg.QueryResult<T>> {
  const start = Date.now();
  const res = await dbPool.query(text, params);
  const duration = Date.now() - start;
  if (config.nodeEnv === 'development') {
    console.log(`Executed query [${duration}ms]: ${text.substring(0, 80)}...`);
  }
  return res;
}

export async function withTransaction<T>(callback: (client: pg.PoolClient) => Promise<T>): Promise<T> {
  const client = await dbPool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}
