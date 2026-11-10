/// Road distance and time with live traffic from TomTom. The key stays on the server only.
/// Nearby asks share one answer for a few minutes, so both phones of one trip cost one call.

import { fastMemory } from './fastMemory.js';

/// Tests never call TomTom, so they stay free and fast
const tomtomKey = () => (process.env.NODE_ENV === 'test' ? '' : process.env.TOMTOM_ROUTING_KEY || '');
const CACHE_MS = 2 * 60 * 1000;
/// About 200 m: two asks this close are the same trip
const ROUND_DEGREES = 0.002;
const MAX_CACHE = 5000;

export interface Point { lat: number; lon: number }

export interface RoadRoute {
  distanceMeters: number;
  /// With the traffic right now
  durationSeconds: number;
  trafficDelaySeconds: number;
  points?: [number, number][];
}

const cache = new Map<string, { at: number; route: RoadRoute }>();
const snap = (value: number) => Math.round(value / ROUND_DEGREES) * ROUND_DEGREES;

/// Tests put their own road answer here, so the sharing rules are checked without calling TomTom
let testSource: ((from: Point, to: Point) => Promise<RoadRoute | null>) | null = null;
export function useRoadSource(source: typeof testSource) {
  testSource = source;
  cache.clear();
}

export const routingConfigured = () => testSource !== null || tomtomKey().length > 0;

/// Null when TomTom can't answer, and the caller falls back to its own estimate
export async function roadRoute(from: Point, to: Point, withPoints = false): Promise<RoadRoute | null> {
  if (!routingConfigured()) return null;
  const a = { lat: snap(from.lat), lon: snap(from.lon) };
  const b = { lat: snap(to.lat), lon: snap(to.lon) };
  const key = `${a.lat.toFixed(3)},${a.lon.toFixed(3)}:${b.lat.toFixed(3)},${b.lon.toFixed(3)}:${withPoints ? 1 : 0}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.route;

  // Two asks for the same trip at the same moment, like the two phones of one order, wait for one answer
  const running = asking.get(key);
  if (running) return running;
  const answer = askOnce(key, from, to, withPoints).finally(() => asking.delete(key));
  asking.set(key, answer);
  return answer;
}

const asking = new Map<string, Promise<RoadRoute | null>>();
const sharedKey = (key: string) => `road:${key}`;

/// The answer another worker, on either server, already paid for in the last two minutes
async function sharedAnswer(key: string): Promise<RoadRoute | null> {
  try {
    const saved = await fastMemory()?.get(sharedKey(key));
    return saved ? (JSON.parse(saved) as RoadRoute) : null;
  } catch {
    return null;
  }
}

function remember(key: string, route: RoadRoute, share: boolean) {
  if (cache.size >= MAX_CACHE) cache.delete(cache.keys().next().value as string);
  cache.set(key, { at: Date.now(), route });
  // The line of the road is big and asked for rarely, so only the short answer is shared
  if (share) fastMemory()?.set(sharedKey(key), JSON.stringify(route), 'PX', CACHE_MS).catch(() => undefined);
}

async function askOnce(key: string, from: Point, to: Point, withPoints: boolean): Promise<RoadRoute | null> {
  if (!withPoints) {
    const shared = await sharedAnswer(key);
    if (shared) {
      remember(key, shared, false);
      return shared;
    }
  }
  if (testSource) {
    const route = await testSource(from, to);
    if (route) remember(key, route, !withPoints);
    return route;
  }

  try {
    const url = `https://api.tomtom.com/routing/1/calculateRoute/${from.lat},${from.lon}:${to.lat},${to.lon}/json`
      + `?traffic=true&travelMode=car&routeType=fastest${withPoints ? '' : '&routeRepresentation=summaryOnly'}&key=${tomtomKey()}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) return null;
    const body = (await res.json()) as any;
    const first = body.routes?.[0];
    const summary = first?.summary;
    if (typeof summary?.travelTimeInSeconds !== 'number') return null;

    const route: RoadRoute = {
      distanceMeters: summary.lengthInMeters,
      durationSeconds: summary.travelTimeInSeconds,
      trafficDelaySeconds: summary.trafficDelayInSeconds ?? 0,
    };
    if (withPoints) {
      route.points = (first.legs ?? []).flatMap((leg: any) => (leg.points ?? []).map((p: any) => [p.latitude, p.longitude]));
    }
    remember(key, route, !withPoints);
    return route;
  } catch {
    return null;
  }
}

const placeCache = new Map<string, { at: number; name: string }>();
const PLACE_CACHE_MS = 24 * 60 * 60 * 1000;

/// The street, area and governorate at a point, in Arabic. Points about 200 m apart share one answer for a day
export async function placeName(at: Point): Promise<string | null> {
  if (tomtomKey().length === 0) return null;
  const key = `${snap(at.lat).toFixed(3)},${snap(at.lon).toFixed(3)}`;
  const hit = placeCache.get(key);
  if (hit && Date.now() - hit.at < PLACE_CACHE_MS) return hit.name;

  try {
    const res = await fetch(
      `https://api.tomtom.com/search/2/reverseGeocode/${at.lat},${at.lon}.json?language=ar&key=${tomtomKey()}`,
      { signal: AbortSignal.timeout(4000) }
    );
    if (!res.ok) return null;
    const address = ((await res.json()) as any).addresses?.[0]?.address;
    if (!address) return null;
    const governorate = address.countrySubdivision ? (String(address.countrySubdivision).startsWith('محافظة') ? address.countrySubdivision : `محافظة ${address.countrySubdivision}`) : null;
    const parts = [address.streetName, address.municipalitySubdivision || address.municipality, governorate]
      .filter((part: unknown): part is string => typeof part === 'string' && part.trim().length > 0)
      .filter((part: string, i: number, all: string[]) => all.indexOf(part) === i);
    if (parts.length === 0) return null;
    const name = parts.join('، ');
    if (placeCache.size >= MAX_CACHE) placeCache.delete(placeCache.keys().next().value as string);
    placeCache.set(key, { at: Date.now(), name });
    return name;
  } catch {
    return null;
  }
}
