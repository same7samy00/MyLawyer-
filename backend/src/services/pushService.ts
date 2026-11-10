import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { dbPool } from '../database/index.js';
import { enqueue, FinalFailure, handleJob } from './jobQueue.js';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const ALERTS_CHANNEL = 'alerts';

let account: ServiceAccount | null | undefined;
let accessToken: { value: string; expiresAt: number } | null = null;

function loadAccount(): ServiceAccount | null {
  if (account !== undefined) return account;

  const file = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || path.resolve(process.cwd(), 'firebase-service-account.json');
  try {
    account = JSON.parse(fs.readFileSync(file, 'utf-8')) as ServiceAccount;
  } catch {
    account = null;
    console.warn('[MyLawyer Backend] Firebase key not found, push notifications are off');
  }
  return account;
}

function base64Url(value: string | Buffer): string {
  return Buffer.from(value).toString('base64url');
}

async function getAccessToken(service: ServiceAccount): Promise<string> {
  if (accessToken && accessToken.expiresAt > Date.now() + 60_000) return accessToken.value;

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: service.client_email,
    scope: MESSAGING_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));
  const signature = base64Url(crypto.sign('RSA-SHA256', Buffer.from(`${header}.${claims}`), service.private_key));

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${signature}`,
    }),
  });
  if (!res.ok) throw new Error(`Firebase token request failed: ${res.status}`);

  const json = (await res.json()) as { access_token: string; expires_in: number };
  accessToken = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return accessToken.value;
}

type Link = { orderId?: string; ticketId?: string; requestId?: string; consultationId?: string };

/// A notification is news for a few minutes only: Firebase drops it after 5, and so does the queue
const PUSH_MAX_AGE_MS = 5 * 60_000;
/// A wake is asked for again by the next sweep, so an old one means nothing
const WAKE_MAX_AGE_MS = 2 * 60_000;

function pushMessage(token: string, title: string, body: string, link: Link) {
  const tag = link.orderId || link.ticketId || link.requestId || link.consultationId;
  return {
    token,
    notification: { title, body },
    // The phone opens the page this notification talks about
    data: Object.fromEntries(Object.entries(link).filter(([, value]) => value)) as Record<string, string>,
    android: {
      priority: 'high',
      ttl: '300s',
      notification: {
        channel_id: ALERTS_CHANNEL,
        // One order keeps one notification on the device, the newest replaces the older
        ...(tag ? { tag } : {}),
        sound: 'default',
        default_sound: true,
        default_vibrate_timings: true,
      },
    },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

/// A silent, high-priority push with no text: it wakes the lawyer's phone, even with the screen off or the app
/// closed, and the phone answers by sending its place. Nothing shows on the screen
function wakeMessage(token: string) {
  return {
    token,
    data: { type: 'wake' },
    android: { priority: 'high', ttl: '120s' },
    apns: { headers: { 'apns-priority': '5', 'apns-push-type': 'background' }, payload: { aps: { 'content-available': 1 } } },
  };
}

/// Sends one message to one phone. A busy or broken moment at Firebase throws so the queue tries again;
/// a message Firebase refuses for good doesn't come back
async function deliver(message: { token: string }) {
  const service = loadAccount();
  if (!service) return;
  const bearer = await getAccessToken(service);
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${service.project_id}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message }),
    signal: AbortSignal.timeout(10_000),
  });
  // Phones that removed the app stop being valid
  if (res.status === 404) {
    await dbPool.query('DELETE FROM device_tokens WHERE token = $1', [message.token]);
    return;
  }
  if (res.status === 401) accessToken = null;
  if (res.status === 401 || res.status === 429 || res.status >= 500) throw new Error(`Firebase answered ${res.status}`);
  if (!res.ok) throw new FinalFailure(`Firebase refused the message: ${res.status}`);
}

async function phonesOf(userId: string): Promise<string[]> {
  const res = await dbPool.query('SELECT token FROM device_tokens WHERE user_id = $1', [userId]);
  return res.rows.map((row) => row.token as string);
}

// One job per person finds their phones, then one job per phone, so a retry reaches only the phone that missed it
handleJob('push', PUSH_MAX_AGE_MS, async ({ userId, title, body, link }) => {
  for (const token of await phonesOf(userId)) await enqueue('push-device', { token, title, body, link });
});
handleJob('push-device', PUSH_MAX_AGE_MS, ({ token, title, body, link }) => deliver(pushMessage(token, title, body, link)));
handleJob('wake', WAKE_MAX_AGE_MS, async ({ userId }) => {
  for (const token of await phonesOf(userId)) await enqueue('wake-device', { token });
});
handleJob('wake-device', WAKE_MAX_AGE_MS, ({ token }) => deliver(wakeMessage(token)));

export async function sendWake(userId: string) {
  if (!loadAccount()) return;
  await enqueue('wake', { userId });
}

/// Failure here never affects the order, the notification stays inside the app
export async function sendPush(userId: string, title: string, body: string, link: Link = {}) {
  if (!loadAccount()) return;
  await enqueue('push', { userId, title, body, link });
}
