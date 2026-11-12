/// Looks a place up by name (a police station, a prosecution, a court) with TomTom, inside Egypt, in Arabic.
/// The key stays on the server. The same words share one answer for an hour, so a busy hour costs a few calls.

import { fastMemory } from './fastMemory.js';

const tomtomKey = () => (process.env.NODE_ENV === 'test' ? '' : process.env.TOMTOM_ROUTING_KEY || '');
const CACHE_SECONDS = 60 * 60;
const MAX_RESULTS = 8;

export interface FoundPlace {
  name: string;
  /// The street, area and governorate under the name
  address: string;
  lat: number;
  lon: number;
}

/// Tests put their own answer here, so they never call TomTom
let testSource: ((text: string) => Promise<FoundPlace[]>) | null = null;
export function usePlaceSource(source: typeof testSource) {
  testSource = source;
}

export const placeSearchConfigured = () => testSource !== null || tomtomKey().length > 0;

/// Empty when TomTom can't answer, and the client types the place by hand
export async function searchPlaces(text: string): Promise<FoundPlace[]> {
  const words = text.trim().replace(/\s+/g, ' ').slice(0, 80);
  if (words.length < 2 || !placeSearchConfigured()) return [];
  if (testSource) return testSource(words);

  const key = `places:${words}`;
  try {
    const saved = await fastMemory()?.get(key);
    if (saved) return JSON.parse(saved) as FoundPlace[];
  } catch {
    // The shared memory is only a shortcut
  }

  try {
    const url = `https://api.tomtom.com/search/2/search/${encodeURIComponent(words)}.json`
      + `?language=ar&countrySet=EG&limit=${MAX_RESULTS}&idxSet=POI,Geo,Addr&key=${tomtomKey()}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) return [];
    const results = ((await res.json()) as any).results;
    const places: FoundPlace[] = (Array.isArray(results) ? results : [])
      .map((row: any): FoundPlace | null => {
        const lat = Number(row.position?.lat);
        const lon = Number(row.position?.lon);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
        const name = String(row.poi?.name ?? row.address?.freeformAddress ?? '').trim();
        if (!name) return null;
        const address = String(row.address?.freeformAddress ?? '').trim();
        return { name, address: address === name ? '' : address, lat, lon };
      })
      .filter((place: FoundPlace | null): place is FoundPlace => place !== null);
    fastMemory()?.set(key, JSON.stringify(places), 'EX', CACHE_SECONDS).catch(() => undefined);
    return places;
  } catch {
    return [];
  }
}
