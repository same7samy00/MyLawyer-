import type { ServerResponse } from 'http';
import pg from 'pg';
import { config } from '../config/index.js';
import type { Db } from '../database/index.js';

const CHANNEL = 'user_changes';
const HEARTBEAT_MS = 25_000;
const RECONNECT_MS = 3_000;
const MAX_LINES_PER_USER = 3;

const lines = new Map<string, Set<ServerResponse>>();
let listener: pg.Client | null = null;
let stopped = false;

/// Tells this person's open apps that something changed.
/// PostgreSQL delivers it only after the transaction commits, so the app never reads old data.
/// [alert] makes the open app play its sound and vibrate.
export async function publishChange(db: Db, userId: string, alert = false) {
  await db.query('SELECT pg_notify($1, $2)', [CHANNEL, `${userId}|${alert ? 'alert' : 'change'}`]);
}

export function deliverChange(userId: string, alert = false) {
  for (const line of lines.get(userId) ?? []) line.write(alert ? 'data: change-alert\n\n' : 'data: change\n\n');
}

/// One open line per phone. A person's oldest line closes when they pass the limit.
export function openLine(userId: string, line: ServerResponse) {
  const own = lines.get(userId) ?? new Set<ServerResponse>();
  lines.set(userId, own);
  if (own.size >= MAX_LINES_PER_USER) own.values().next().value?.end();
  own.add(line);

  line.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  line.write('data: ready\n\n');

  // Networks and proxies close a line that stays silent
  const heartbeat = setInterval(() => line.write(': ping\n\n'), HEARTBEAT_MS);
  line.on('close', () => {
    clearInterval(heartbeat);
    own.delete(line);
    if (own.size === 0 && lines.get(userId) === own) lines.delete(userId);
  });
}

export function closeAllLines() {
  for (const own of lines.values()) {
    for (const line of own) line.end();
  }
}

async function connectListener() {
  if (stopped) return;
  const client = new pg.Client({ connectionString: config.databaseUrl });
  const retry = () => {
    if (listener === client) listener = null;
    client.end().catch(() => undefined);
    if (!stopped) setTimeout(connectListener, RECONNECT_MS);
  };
  let retried = false;
  const retryOnce = () => {
    if (retried) return;
    retried = true;
    retry();
  };

  client.on('error', retryOnce);
  client.on('end', retryOnce);
  client.on('notification', (message) => {
    const [userId, kind] = (message.payload ?? '').split('|');
    if (userId) deliverChange(userId, kind === 'alert');
  });
  try {
    await client.connect();
    await client.query(`LISTEN ${CHANNEL}`);
    listener = client;
  } catch (err) {
    console.error('[MyLawyer Backend] Live updates connection failed:', err);
    retryOnce();
  }
}

export function startLiveUpdates() {
  stopped = false;
  void connectListener();
}

export async function stopLiveUpdates() {
  stopped = true;
  closeAllLines();
  await listener?.end().catch(() => undefined);
  listener = null;
}
