import { query, readQuery } from '../../database/index.js';
import crypto from 'crypto';
import { GOVERNORATES, GOVERNORATE_POINTS } from './governorates.js';

/// The lawyers map is for looking only: every approved lawyer, available or not, in squares that are the same
/// for everyone. It is a showcase to look at, so it is a copy refreshed every 5 hours: Nginx and the phone keep
/// an answer that long
/// (owner decisions 2026-11-07 and 2026-11-10)
export const SHOWCASE_SECONDS = 5 * 60 * 60;
/// The app server itself keeps a square only this long. Nginx stands in front, so a square is asked for again
/// only when Nginx's copy runs out, and then it is built from the lawyers as they are now
const MEMORY_SECONDS = 300;
/// A lawyer whose place has not changed for this long leaves the map
const STALE_DAYS = 30;
/// Small squares close in, big squares when the map shows a large part of Egypt
export const CELL_DEGREES = { s: 0.1, l: 0.5 } as const;
export type CellSize = keyof typeof CELL_DEGREES;
export const MAX_CELLS = 150;
/// Kept per governorate; the app shows 20 at a time with «المزيد»
const TOP_PER_GOVERNORATE = 100;

const SHOWN = `
  lp.approval_status = 'approved' AND u.status = 'active' AND lp.suspended_until IS NULL
  AND lp.latitude IS NOT NULL AND lp.longitude IS NOT NULL
  AND lp.latitude BETWEEN 22.0 AND 31.8 AND lp.longitude BETWEEN 24.5 AND 37.0
  AND lp.last_location_updated_at > NOW() - make_interval(days => ${STALE_DAYS})`;

const COLUMNS = `u.id, lp.full_name, lp.profile_photo_path, lp.rating, lp.reviews_count, lp.experience_years, lp.latitude, lp.longitude`;

/// The public spot: the real place moved 150 to 450 m in a direction fixed for each lawyer. Never the exact
/// place (that shows after payment), always the same spot, and lawyers of one street don't stack on a grid point
export function publicPoint(id: string, lat: number, lon: number): [number, number] {
  const hash = crypto.createHash('sha256').update(`map:${id}`).digest();
  const angle = (hash.readUInt16BE(0) / 65536) * 2 * Math.PI;
  const meters = 150 + (hash.readUInt16BE(2) / 65536) * 300;
  const dLat = (meters * Math.cos(angle)) / 111_320;
  const dLon = (meters * Math.sin(angle)) / (111_320 * Math.cos((lat * Math.PI) / 180));
  return [Number((lat + dLat).toFixed(5)), Number((lon + dLon).toFixed(5))];
}

const toCard = (row: any) => ({
  id: row.id,
  name: row.full_name,
  rating: Number(row.rating) || 0,
  reviewsCount: Number(row.reviews_count) || 0,
  experienceYears: Number(row.experience_years) || 0,
  avatar: row.profile_photo_path || null,
  coordinates: publicPoint(row.id, Number(row.latitude), Number(row.longitude)),
});

/// The governorate of the nearest city or big town, the same rule the phone uses
export function governorateOf(lat: number, lon: number): string | null {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  const lonScale = Math.cos((lat * Math.PI) / 180);
  let best = -1;
  let bestDistance = Infinity;
  for (const [pLat, pLon, index] of GOVERNORATE_POINTS) {
    const dLat = pLat - lat;
    const dLon = (pLon - lon) * lonScale;
    const distance = dLat * dLat + dLon * dLon;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = index;
    }
  }
  return best >= 0 ? GOVERNORATES[best] : null;
}

export const cellKey = (size: CellSize, x: number, y: number) => `${size}:${x}:${y}`;

/// Each square keeps its answer as ready JSON text, so a busy square is turned into text once per
/// five minutes instead of once per request
const cells = new Map<string, { at: number; json: string }>();

/// The lawyers in each asked square. A square built less than five minutes ago is answered from memory.
/// The asked squares as one JSON object text: {"x_y": [lawyers], ...}
export async function cellsJson(size: CellSize, wanted: [number, number][]): Promise<string> {
  const now = Date.now();
  const degrees = CELL_DEGREES[size];
  const missing = wanted.filter(([x, y]) => {
    const saved = cells.get(cellKey(size, x, y));
    return !saved || now - saved.at >= MEMORY_SECONDS * 1000;
  });

  if (missing.length > 0) {
    // One read for the box around all the missing squares, then each lawyer goes to their square
    const xs = missing.map(([x]) => x);
    const ys = missing.map(([, y]) => y);
    const res = await readQuery(
      `SELECT ${COLUMNS} FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id
       WHERE ${SHOWN}
         AND lp.latitude >= $1::float8 AND lp.latitude < $2::float8
         AND lp.longitude >= $3::float8 AND lp.longitude < $4::float8`,
      [Math.min(...ys) * degrees, (Math.max(...ys) + 1) * degrees, Math.min(...xs) * degrees, (Math.max(...xs) + 1) * degrees]
    );
    const fresh = new Map<string, any[]>(missing.map(([x, y]) => [cellKey(size, x, y), []]));
    for (const row of res.rows) {
      const key = cellKey(size, Math.floor(Number(row.longitude) / degrees), Math.floor(Number(row.latitude) / degrees));
      fresh.get(key)?.push(toCard(row));
    }
    for (const [key, lawyers] of fresh) cells.set(key, { at: now, json: JSON.stringify(lawyers) });
    forgetOld(now);
  }

  return `{${wanted.map(([x, y]) => `"${x}_${y}":${cells.get(cellKey(size, x, y))?.json ?? '[]'}`).join(',')}}`;
}

/// The map the way Google Maps shows places: far away only the most important ones, more as you come closer.
/// Each square is split into small areas and only the best rated lawyer of each area is sent: about 5 km areas
/// when the map shows a governorate (big squares), about 500 m areas in a city (small squares). Up close the
/// cards answer has everyone. The pins on screen stay about the same number at every zoom, however many lawyers
/// there are. Worked out by the database and kept five minutes, the same for everyone.
export type MapKind = 'top';
const TOP_AREA_DEGREES: Record<CellSize, number> = { l: 0.05, s: 0.005 };
const light = new Map<string, { at: number; json: string }>();

export async function lightCellsJson(kind: MapKind, size: CellSize, wanted: [number, number][]): Promise<string> {
  const now = Date.now();
  const degrees = CELL_DEGREES[size];
  const area = TOP_AREA_DEGREES[size];
  const key = (x: number, y: number) => `${kind}:${size}:${x}:${y}`;
  const missing = wanted.filter(([x, y]) => {
    const saved = light.get(key(x, y));
    return !saved || now - saved.at >= MEMORY_SECONDS * 1000;
  });

  if (missing.length > 0) {
    const xs = missing.map(([x]) => x);
    const ys = missing.map(([, y]) => y);
    const res = await readQuery(
      `SELECT DISTINCT ON (floor(lp.latitude::float8 / $5), floor(lp.longitude::float8 / $5)) ${COLUMNS}
       FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id
       WHERE ${SHOWN} AND lp.latitude >= $1::float8 AND lp.latitude < $2::float8 AND lp.longitude >= $3::float8 AND lp.longitude < $4::float8
       ORDER BY floor(lp.latitude::float8 / $5), floor(lp.longitude::float8 / $5), lp.rating DESC, lp.reviews_count DESC`,
      [Math.min(...ys) * degrees, (Math.max(...ys) + 1) * degrees, Math.min(...xs) * degrees, (Math.max(...xs) + 1) * degrees, area]
    );
    const fresh = new Map<string, unknown[]>(missing.map(([x, y]) => [key(x, y), []]));
    for (const row of res.rows) {
      fresh.get(key(Math.floor(Number(row.longitude) / degrees), Math.floor(Number(row.latitude) / degrees)))?.push(toCard(row));
    }
    for (const [k, value] of fresh) light.set(k, { at: now, json: JSON.stringify(value) });
    if (light.size > 20000) for (const [k, saved] of light) if (now - saved.at >= MEMORY_SECONDS * 1000) light.delete(k);
  }

  return `{${wanted.map(([x, y]) => `"${x}_${y}":${light.get(key(x, y))?.json ?? '[]'}`).join(',')}}`;
}

function forgetOld(now: number) {
  if (cells.size < 5000) return;
  for (const [key, saved] of cells) {
    if (now - saved.at >= MEMORY_SECONDS * 1000) cells.delete(key);
  }
}

let top: { at: number; lists: Map<string, any[]> } | null = null;
let building: Promise<Map<string, any[]>> | null = null;

/// The top rated lawyers of one governorate. All the lists are rebuilt together at most every five minutes.
export async function topInGovernorate(governorate: string): Promise<any[]> {
  if (!top || Date.now() - top.at >= MEMORY_SECONDS * 1000) {
    building ??= buildTopLists().finally(() => {
      building = null;
    });
    const lists = await building;
    top = { at: Date.now(), lists };
  }
  return top.lists.get(governorate) ?? [];
}

async function buildTopLists(): Promise<Map<string, any[]>> {
  await refreshGovernorates();
  const res = await readQuery(
    `SELECT * FROM (
       SELECT ${COLUMNS}, lp.governorate,
              row_number() OVER (PARTITION BY lp.governorate ORDER BY lp.rating DESC, lp.reviews_count DESC) AS place
       FROM lawyer_profiles lp JOIN users u ON u.id = lp.user_id
       WHERE ${SHOWN} AND lp.governorate IS NOT NULL
     ) ranked WHERE place <= ${TOP_PER_GOVERNORATE} ORDER BY governorate, place`
  );
  const lists = new Map<string, any[]>();
  for (const row of res.rows) {
    const list = lists.get(row.governorate) ?? [];
    list.push(toCard(row));
    lists.set(row.governorate, list);
  }
  return lists;
}

/// Lawyers who are new or moved since their governorate was worked out get it again
export async function refreshGovernorates() {
  for (let batch = 0; batch < 20; batch++) {
    const res = await query(
      `SELECT id, latitude, longitude FROM lawyer_profiles
       WHERE latitude IS NOT NULL AND longitude IS NOT NULL
         AND (governorate_at IS NULL OR governorate_at < last_location_updated_at)
       LIMIT 2000`
    );
    if (res.rows.length === 0) return;
    const ids = res.rows.map((row) => row.id);
    const names = res.rows.map((row) => governorateOf(Number(row.latitude), Number(row.longitude)));
    await query(
      `UPDATE lawyer_profiles lp SET governorate = v.name, governorate_at = NOW()
       FROM unnest($1::uuid[], $2::text[]) AS v(id, name) WHERE lp.id = v.id`,
      [ids, names]
    );
    if (res.rows.length < 2000) return;
  }
}

/// Tests start from an empty memory
export function forgetShowcase() {
  cells.clear();
  light.clear();
  top = null;
}
