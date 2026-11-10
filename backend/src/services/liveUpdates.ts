import type { ServerResponse } from 'http';
import pg from 'pg';
import { config } from '../config/index.js';
import type { Db } from '../database/index.js';
import { fastMemory, newConnection } from './fastMemory.js';

const CHANNEL = 'user_changes';
// Live positions on the way to a meeting: never stored in change_log, only the newest one matters
const POSITION_CHANNEL = 'order_positions';
const HEARTBEAT_MS = 25_000;
const RECONNECT_MS = 3_000;
const MAX_LINES_PER_USER = 3;

const lines = new Map<string, Set<ServerResponse>>();
/// The control page's lines: every change reaches them
const adminLines = new Set<ServerResponse>();
let listener: pg.Client | null = null;
let positionListener: ReturnType<typeof newConnection> | null = null;
let stopped = false;

/// Tells this person's open apps that something changed.
/// PostgreSQL delivers it only after the transaction commits, so the app never reads old data.
/// [alert] makes the open app play its sound and vibrate.
/// [kind] tells the app which screens to reload: orders, requests, support, notifications or all.
/// [entityId] is the order, request or ticket that changed, so the app reloads that one item only.
/// Every change gets a number, so an app that was offline asks for what it missed and nothing more.
export async function publishChange(db: Db, userId: string, alert = false, kind = 'all', entityId: string | null = null) {
  const saved = await db.query('INSERT INTO change_log (user_id, kind, entity_id) VALUES ($1, $2, $3) RETURNING id', [userId, kind, entityId]);
  await db.query('SELECT pg_notify($1, $2)', [CHANNEL, `${userId}|${alert ? 'alert' : 'change'}|${kind}|${entityId ?? '-'}|${saved.rows[0].id}`]);
}

/// The same change for many people in one write, like a new request reaching ten lawyers
export async function publishChanges(db: Db, userIds: string[], alert: boolean, kind: string, entityId: string) {
  if (userIds.length === 0) return;
  await db.query(
    `WITH saved AS (
       INSERT INTO change_log (user_id, kind, entity_id)
       SELECT person, $2::varchar, $3::uuid FROM unnest($1::uuid[]) AS person
       RETURNING id, user_id
     )
     SELECT pg_notify($4::text, user_id::text || '|' || $5::text || '|' || $2::text || '|' || $3::text || '|' || id::text) FROM saved`,
    [userIds, kind, entityId, CHANNEL, alert ? 'alert' : 'change']
  );
}

export function deliverChange(userId: string, alert = false, kind = 'all', entityId = '-', changeId = '') {
  const text = `${changeId ? `id: ${changeId}\n` : ''}data: ${alert ? 'change-alert' : 'change'} ${kind} ${entityId}\n\n`;
  for (const line of lines.get(userId) ?? []) line.write(text);
  // The control page hears about every change, without sound
  for (const line of adminLines) line.write(`data: change ${kind} ${entityId}\n\n`);
}

/// Sends one side's newest point to the other side of the order, and to nobody else.
/// A point is a small message that needs no saving, so it goes through the fast memory and leaves the database
/// alone. Without the fast memory, or if it doesn't answer, it goes through the database as before
export async function publishPosition(db: Db, toUserId: string, orderId: string, side: 'lawyer' | 'client', lat: number, lon: number) {
  const payload = `${toUserId}|${orderId}|${side}|${lat}|${lon}`;
  const memory = fastMemory();
  if (memory) {
    try {
      await memory.publish(POSITION_CHANNEL, payload);
      return;
    } catch {
      // Falls back to the database
    }
  }
  await db.query('SELECT pg_notify($1, $2)', [POSITION_CHANNEL, payload]);
}

function deliverPosition(payload: string) {
  const [userId, orderId, side, lat, lon] = payload.split('|');
  if (!userId || !orderId) return;
  const text = `data: position ${orderId} ${side} ${lat} ${lon}\n\n`;
  for (const line of lines.get(userId) ?? []) line.write(text);
}

/// One open line per phone. A person's oldest line closes when they pass the limit.
export function openLine(userId: string, line: ServerResponse, isAdmin = false) {
  if (isAdmin) adminLines.add(line);
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
    adminLines.delete(line);
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
    if (message.channel === POSITION_CHANNEL) return deliverPosition(message.payload ?? '');
    const [userId, level, kind, entityId, changeId] = (message.payload ?? '').split('|');
    if (userId) deliverChange(userId, level === 'alert', kind || 'all', entityId || '-', changeId || '');
  });
  try {
    await client.connect();
    await client.query(`LISTEN ${CHANNEL}`);
    await client.query(`LISTEN ${POSITION_CHANNEL}`);
    listener = client;
  } catch (err) {
    console.error('[MyLawyer Backend] Live updates connection failed:', err);
    retryOnce();
  }
}

/// Points sent through the fast memory by a worker on either server. The connection reconnects by itself,
/// and listens again every time it is ready
function listenForPositions() {
  if (!fastMemory()) return;
  const connection = newConnection();
  positionListener = connection;
  connection.on('message', (_channel, payload) => deliverPosition(payload));
  connection.on('ready', () => {
    connection.subscribe(POSITION_CHANNEL).catch((err) => console.error('[MyLawyer Backend] Position listener failed:', err.message));
  });
}

export function startLiveUpdates() {
  stopped = false;
  void connectListener();
  listenForPositions();
}

export async function stopLiveUpdates() {
  stopped = true;
  closeAllLines();
  await listener?.end().catch(() => undefined);
  listener = null;
  await positionListener?.quit().catch(() => undefined);
  positionListener = null;
}
