import { approximateCoordinate } from '../lifecycle/service.js';

export interface AuthenticatedUser {
  userId: string;
  role: 'client' | 'lawyer' | 'admin';
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

// Seconds come from the server so a wrong phone clock can't change the countdown
export function responseSecondsLeft(order: { status: string; response_deadline: string | Date | null }): number {
  if (order.status !== 'PENDING' || !order.response_deadline) return 0;
  const left = (new Date(order.response_deadline).getTime() - Date.now()) / 1000;
  return Math.max(0, Math.ceil(left));
}

// Before payment the lawyer reads only the governorate from the general area name
export function governorateOf(area: string | null): string | null {
  if (!area) return null;
  return area.split('،').pop()?.trim() || null;
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
