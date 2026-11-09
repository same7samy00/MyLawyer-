/// Road distance and time with live traffic from TomTom. The key stays on the server only.
/// Nearby asks share one answer for a few minutes, so both phones of one trip cost one call.

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

export const routingConfigured = () => tomtomKey().length > 0;

/// Null when TomTom can't answer, and the caller falls back to its own estimate
export async function roadRoute(from: Point, to: Point, withPoints = false): Promise<RoadRoute | null> {
  if (!routingConfigured()) return null;
  const a = { lat: snap(from.lat), lon: snap(from.lon) };
  const b = { lat: snap(to.lat), lon: snap(to.lon) };
  const key = `${a.lat.toFixed(3)},${a.lon.toFixed(3)}:${b.lat.toFixed(3)},${b.lon.toFixed(3)}:${withPoints ? 1 : 0}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.route;

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
    if (cache.size >= MAX_CACHE) cache.delete(cache.keys().next().value as string);
    cache.set(key, { at: Date.now(), route });
    return route;
  } catch {
    return null;
  }
}

const placeCache = new Map<string, { at: number; name: string }>();
const PLACE_CACHE_MS = 24 * 60 * 60 * 1000;

/// The street, area and governorate at a point, in Arabic. Points about 200 m apart share one answer for a day
export async function placeName(at: Point): Promise<string | null> {
  if (!routingConfigured()) return null;
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
