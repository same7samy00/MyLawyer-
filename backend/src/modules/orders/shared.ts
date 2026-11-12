import pg from 'pg';
import { approximateCoordinate, HOLD_HOURS } from '../lifecycle/service.js';

export type { AuthenticatedUser } from '../../utils/http.js';

/// Holds the order until the transaction ends, so two actions on it run one after the other
/// and the second one sees what the first one did. Every step that moves money starts here.
export async function lockOrder(db: pg.PoolClient, id: string) {
  const res = await db.query('SELECT * FROM service_orders WHERE id::text = $1 OR order_number = $1 FOR UPDATE', [id]);
  return res.rows[0];
}

// Contact details stay hidden until payment so the deal stays on the platform
export const PAID_STATUSES = ['ACTIVE', 'COMPLETED'];

export function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Seconds left to pay a chosen order, from the server so a wrong phone clock can't change them
export function paySecondsLeft(order: { status: string; payment_deadline: string | Date | null }): number {
  if (order.status !== 'ACCEPTED' || !order.payment_deadline) return 0;
  const left = (new Date(order.payment_deadline).getTime() - Date.now()) / 1000;
  return Math.max(0, Math.ceil(left));
}

// Before payment the lawyer reads only the governorate from the general area name
export function governorateOf(area: string | null): string | null {
  if (!area) return null;
  return area.split('،').pop()?.trim() || null;
}

/// The other side's newest point, only between payment and the arrival
export function livePosition(order: any, viewerId: string) {
  const tracking = order.status === 'ACTIVE' && !order.arrived_at;
  const ofLawyer = order.client_id === viewerId;
  const lat = ofLawyer ? order.lawyer_live_latitude : order.client_live_latitude;
  const lon = ofLawyer ? order.lawyer_live_longitude : order.client_live_longitude;
  const at = ofLawyer ? order.lawyer_live_at : order.client_live_at;
  if (!tracking || lat == null || lon == null) return { liveLatitude: null, liveLongitude: null, liveAt: null };
  return { liveLatitude: Number(lat), liveLongitude: Number(lon), liveAt: at };
}

/// Live points never leave the server outside the way to the meeting
export function hideLiveColumns(order: any) {
  for (const key of ['lawyer_live_latitude', 'lawyer_live_longitude', 'lawyer_live_at', 'client_live_latitude', 'client_live_longitude', 'client_live_at']) {
    delete order[key];
  }
}

// Each side sees the other's exact place and area only after payment
export function visibleLocation(order: any, viewerId: string, role: string) {
  const isShared = role === 'admin' || PAID_STATUSES.includes(order.status);
  const coarse = (value: unknown) => (value == null ? null : isShared ? Number(value) : approximateCoordinate(Number(value)));
  const isClient = order.client_id === viewerId;
  const isLawyer = order.lawyer_id === viewerId;

  return {
    clientLatitude: isClient ? Number(order.client_latitude) : coarse(order.client_latitude),
    clientLongitude: isClient ? Number(order.client_longitude) : coarse(order.client_longitude),
    clientAddress: isClient || isShared ? order.client_address : governorateOf(order.client_address),
    lawyerLatitude: isLawyer ? (order.lawyer_latitude == null ? null : Number(order.lawyer_latitude)) : coarse(order.lawyer_latitude),
    lawyerLongitude: isLawyer ? (order.lawyer_longitude == null ? null : Number(order.lawyer_longitude)) : coarse(order.lawyer_longitude),
  };
}

/// The lawyer's fee is held for HOLD_HOURS after the task ends, and a ticket in that time freezes it.
/// Ending a task by «إنهاء المهمة» and the field service's «الشخص رفض» both close it this way
export async function finishOrder(db: pg.PoolClient, order: { id: string; status: string; client_id: string }, userId: string, note: string) {
  const res = await db.query(
    `UPDATE service_orders
     SET status = 'COMPLETED', completed_at = NOW(), payout_status = 'HELD', payout_amount = lawyer_amount,
         hold_until = NOW() + make_interval(hours => $2), updated_at = NOW()
     WHERE id = $1 RETURNING hold_until`,
    [order.id, HOLD_HOURS]
  );
  await db.query(
    `INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note)
     VALUES ($1, $2, $3, 'COMPLETED', $4)`,
    [order.id, userId, order.status, note]
  );
  return res.rows[0] as { hold_until: Date };
}
