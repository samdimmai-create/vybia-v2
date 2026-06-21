// S12C — enrich OUR static places with Foursquare Places (build-time, offline out).
//
//   FOURSQUARE_KEY=… node tool/enrich_places_foursquare.mjs
//
// Foursquare adds RATINGS/popularity plus opening hours and a fine category. The
// key is read from the shell env ONLY and never committed. Output is bundled
// JSON; the app runtime stays fully offline. FSQ ratings are 0–10; we normalise
// to the 0–5 scale the card shows.
//
// Uses the CURRENT Foursquare Places API (places-api.foursquare.com, Bearer auth
// + X-Places-Api-Version). If the account is out of free credits (HTTP 429) or
// the key is rejected (401/403), the run ABORTS cleanly and the catalog is left
// unchanged — graceful no-op, exactly the standby behaviour we want until the
// key/credits are in place.
import { runEnrichment, FatalProviderError } from './_enrich_common.mjs';

const API_VERSION = '2025-06-17';

async function fetchNear(place, key) {
  const url = 'https://places-api.foursquare.com/places/search?' + new URLSearchParams({
    ll: `${place.lat},${place.lng}`,
    query: place.name,
    radius: '200',
    limit: '10',
    fields: 'name,rating,popularity,hours,location,latitude,longitude,categories',
  });
  const r = await fetch(url, {
    headers: {
      Authorization: `Bearer ${key}`,
      accept: 'application/json',
      'X-Places-Api-Version': API_VERSION,
    },
  });
  if (r.status === 401 || r.status === 403) {
    throw new FatalProviderError('Foursquare rejected the key (401/403).');
  }
  if (r.status === 429) {
    throw new FatalProviderError('Foursquare account has no API credits (429).');
  }
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const j = await r.json();
  return (j.results || []).map((p) => ({
    name: p.name,
    lat: p.latitude ?? (p.geocodes && p.geocodes.main && p.geocodes.main.latitude),
    lng: p.longitude ?? (p.geocodes && p.geocodes.main && p.geocodes.main.longitude),
    rating: p.rating, // 0–10
    hours: p.hours && p.hours.display ? p.hours.display : null,
    address: (p.location && (p.location.formatted_address || p.location.address)) || null,
    categories: (p.categories || []).map((c) => c.short_name || c.name),
  }));
}

function mapVenue(v) {
  return {
    openingHours: v.hours || null,
    rating: v.rating != null ? v.rating / 2 : null, // 0–10 → 0–5
    address: v.address,
    subcategory: (v.categories && v.categories[0]) || null,
    lat: v.lat,
    lng: v.lng,
  };
}

runEnrichment({ name: 'foursquare', source: 'foursquare', envKey: 'FOURSQUARE_KEY', fetchNear, mapVenue })
  .catch((e) => { console.error(e); process.exit(1); });
