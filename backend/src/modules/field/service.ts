import crypto from 'crypto';
import { Db } from '../../database/index.js';
import { PAID_STATUSES } from '../orders/shared.js';

/// The field services: a lawyer goes to a place for the client or for another person. They live apart from
/// «محاميك حالاً»: their own tables (migration 047), their own routes (`/field`), and their own screens in the app.
/// What they share with it is the machinery after a request exists: offers, payment, the order and the wallet.

export type PlaceKind = 'police' | 'prosecution' | 'court' | 'government' | 'other';

/// The service titles the app sends, and the kind of place each one goes to
export const FIELD_SERVICES: Record<string, PlaceKind> = {
  'محضر في قسم الشرطة': 'police',
  'تحقيق عاجل في النيابة العامة': 'prosecution',
  'حضور جلسة': 'court',
  'حضور مجلس عرفي': 'other',
  'إجراءات إدارية': 'government',
};

/// How close the lawyer's phone must be to the place to count as arrived. A court or a government compound is
/// much bigger than a police station, so its area is wider (owner decision 2026-11-12: arrival by the place's area)
const RADIUS_METERS: Record<PlaceKind, number> = { police: 150, prosecution: 250, court: 400, government: 300, other: 200 };
/// A place the client typed by hand has only the client's own point, so its area is never narrower than this
const UNVERIFIED_MIN_METERS = 300;

export const arrivalRadiusMeters = (kind: PlaceKind, verified: boolean) =>
  verified ? RADIUS_METERS[kind] : Math.max(RADIUS_METERS[kind], UNVERIFIED_MIN_METERS);

/// Wrong codes allowed before the code is locked. The client can still confirm the arrival
export const MAX_CODE_ATTEMPTS = 5;
export const MAX_PROOF_PHOTOS = 5;

/// Four digits the client passes on to the person
export const newHandoverCode = () => crypto.randomInt(0, 10000).toString().padStart(4, '0');

export const FIELD_COLUMNS = `
  ffr.request_id AS field_id, ffr.for_other AS f_for_other, ffr.person_name AS f_person_name, ffr.relation AS f_relation,
  ffr.person_detained AS f_detained, ffr.place_name AS f_place_name, ffr.place_kind AS f_place_kind,
  ffr.handover_code AS f_code, ffr.code_attempts AS f_attempts, ffr.arrival_method AS f_method, ffr.refused_at AS f_refused_at,
  (SELECT COUNT(*)::int FROM field_proofs fp WHERE fp.request_id = ffr.request_id) AS f_proofs`;

/// Added to a query on `service_orders o`: the request that made the order, and its field details when it has any
export const FIELD_JOIN = `
  LEFT JOIN service_requests fsr ON fsr.order_id = o.id
  LEFT JOIN field_requests ffr ON ffr.request_id = fsr.id`;

/// What the app reads about a field order, or null for any other order. The code goes to the client only,
/// and only while the lawyer has not arrived. The person's name and relation wait for the payment
export function fieldView(row: any, role: string) {
  if (!row.field_id) return null;
  const paid = role === 'admin' || PAID_STATUSES.includes(row.status);
  const isClient = role === 'client';
  const meeting = row.status === 'ACTIVE' && !row.arrived_at;
  return {
    forOther: row.f_for_other,
    personName: paid ? row.f_person_name : null,
    relation: paid ? row.f_relation : null,
    detained: row.f_detained,
    placeName: row.f_place_name,
    placeKind: row.f_place_kind,
    code: isClient && row.f_for_other && meeting ? row.f_code : null,
    codeLocked: row.f_attempts >= MAX_CODE_ATTEMPTS,
    arrivalMethod: row.f_method,
    refused: row.f_refused_at != null,
    proofs: role === 'client' ? 0 : row.f_proofs,
  };
}

export interface ArrivalRule { radiusKm: number; forOther: boolean }

/// The arrival rule of an order made from a field request, or null for any other order
export async function fieldArrivalRule(db: Db, orderId: string): Promise<ArrivalRule | null> {
  const res = await db.query(
    `SELECT f.arrival_radius_m, f.for_other FROM service_requests r JOIN field_requests f ON f.request_id = r.id WHERE r.order_id = $1`,
    [orderId]
  );
  const row = res.rows[0];
  return row ? { radiusKm: row.arrival_radius_m / 1000, forOther: row.for_other } : null;
}

/// Remembers how the arrival was proved. Only the first way counts
export async function markFieldArrival(db: Db, orderId: string, method: 'area' | 'code' | 'client') {
  await db.query(
    `UPDATE field_requests SET arrival_method = $2
     WHERE request_id = (SELECT id FROM service_requests WHERE order_id = $1) AND arrival_method IS NULL`,
    [orderId, method]
  );
}
