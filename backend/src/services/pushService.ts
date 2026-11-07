import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { dbPool } from '../database/index.js';

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

async function sendToDevice(service: ServiceAccount, bearer: string, token: string, title: string, body: string, link: { orderId?: string; ticketId?: string; requestId?: string; consultationId?: string }) {
  const tag = link.orderId || link.ticketId || link.requestId || link.consultationId;
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${service.project_id}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
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
      },
    }),
  });

  // Phones that removed the app stop being valid
  if (res.status === 404) {
    await dbPool.query('DELETE FROM device_tokens WHERE token = $1', [token]);
  } else if (!res.ok) {
    console.error('[MyLawyer Backend] Push failed:', res.status);
  }
}

/// Failure here never affects the order, the notification stays inside the app
export async function sendPush(userId: string, title: string, body: string, link: { orderId?: string; ticketId?: string; requestId?: string; consultationId?: string } = {}) {
  const service = loadAccount();
  if (!service) return;

  try {
    const res = await dbPool.query('SELECT token FROM device_tokens WHERE user_id = $1', [userId]);
    if (res.rows.length === 0) return;

    const bearer = await getAccessToken(service);
    await Promise.all(res.rows.map((row) => sendToDevice(service, bearer, row.token, title, body, link)));
  } catch (err) {
    console.error('[MyLawyer Backend] Push error:', err);
  }
}
