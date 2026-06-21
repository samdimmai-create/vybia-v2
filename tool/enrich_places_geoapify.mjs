// S12C — enrich OUR static places with Geoapify Places (build-time, offline out).
//
//   GEOAPIFY_KEY=… node tool/enrich_places_geoapify.mjs
//
// Geoapify is OSM-derived: it adds opening hours, finer categories, formatted
// address and refined coordinates (NO ratings — that's Foursquare's job). The key
// is read from the shell env ONLY and never committed. Output is bundled JSON;
// the app runtime stays fully offline.
import { runEnrichment } from './_enrich_common.mjs';

// Resolve the exact OSM POI at our place's coordinates via Place Details, which
// returns its real opening_hours + categories (far better hit-rate than a radius
// category search). bestMatch still validates name + proximity before merging.
const FATAL = { 401: 'bad key', 403: 'forbidden', 429: 'rate/credit limit' };

async function fetchNear(place, key) {
  const url = 'https://api.geoapify.com/v2/place-details?' + new URLSearchParams({
    lat: place.lat,
    lon: place.lng,
    features: 'details',
    apiKey: key,
  });
  const r = await fetch(url);
  if (FATAL[r.status]) {
    const { FatalProviderError } = await import('./_enrich_common.mjs');
    throw new FatalProviderError(`Geoapify ${r.status} (${FATAL[r.status]}).`);
  }
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const j = await r.json();
  return (j.features || [])
    .filter((f) => f.properties && f.properties.name)
    .map((f) => {
      const p = f.properties;
      const raw = (p.datasource && p.datasource.raw) || {};
      return {
        name: p.name,
        lat: p.lat,
        lng: p.lon,
        hours: raw.opening_hours || p.opening_hours || null,
        address: p.formatted || p.address_line2 || null,
        categories: p.categories || [],
      };
    });
}

// Real place-type roots — skip OSM attribute tags (wheelchair.*, vegetarian…).
const TYPE_ROOTS = ['catering', 'commercial', 'entertainment', 'leisure',
  'tourism', 'sport', 'building', 'amenity', 'natural', 'education', 'service'];

function mapVenue(v) {
  const fine = (v.categories || [])
    .filter((c) => c.includes('.') && TYPE_ROOTS.includes(c.split('.')[0]))
    .map((c) => c.split('.').pop().replace(/_/g, ' '))
    .find(Boolean);
  return {
    openingHours: v.hours ? humanizeHours(v.hours) : null,
    rating: null, // Geoapify has no ratings
    address: v.address,
    subcategory: fine || null,
    lat: v.lat,
    lng: v.lng,
  };
}

// OSM `opening_hours` can be terse ("Mo-Fr 09:00-18:00"); keep it but tidy.
function humanizeHours(h) {
  const s = String(h).trim();
  if (!s || s.length > 80) return s.slice(0, 80);
  return s
    .replace(/Mo/g, 'Lun').replace(/Tu/g, 'Mar').replace(/We/g, 'Mer')
    .replace(/Th/g, 'Jeu').replace(/Fr/g, 'Ven').replace(/Sa/g, 'Sam')
    .replace(/Su/g, 'Dim').replace(/;/g, ' · ');
}

runEnrichment({ name: 'geoapify', source: 'geoapify', envKey: 'GEOAPIFY_KEY', fetchNear, mapVenue })
  .catch((e) => { console.error(e); process.exit(1); });
