// S12C — shared build-time place-enrichment core (offline output).
//
// Reads OUR static catalog (assets/data/vybia_catalog.json), and for each PLACE
// entry asks a provider adapter for nearby real venues, matches the best one by
// name + proximity, and merges richer attributes (opening hours, rating, finer
// category, better coords) back into the entry. Provenance is recorded on the
// row (`source` gets the provider appended, `enrichedAt` stamped) and attributed
// in assets/data/NOTICES.md. The enriched JSON is BUNDLED → the app runtime stays
// fully offline. Keys are read from the shell env ONLY (never committed).
//
// Usage (from an entry script):
//   import { runEnrichment } from './_enrich_common.mjs';
//   await runEnrichment({ name:'geoapify', source:'geoapify', envKey:'GEOAPIFY_KEY',
//                         fetchNear, mapVenue });
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const CATALOG_PATH = join(__dirname, '..', 'assets', 'data', 'vybia_catalog.json');
export const NOTICES_PATH = join(__dirname, '..', 'assets', 'data', 'NOTICES.md');

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/// A non-retryable provider error (bad key, out of credits) — aborts the run
/// WITHOUT writing, so a misconfigured provider degrades cleanly to a no-op.
export class FatalProviderError extends Error {}

// --- text + geo helpers ---------------------------------------------------
export function norm(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // strip accents
    .replace(/[^a-z0-9 ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function nameScore(a, b) {
  const na = norm(a), nb = norm(b);
  if (!na || !nb) return 0;
  if (na === nb) return 1;
  if (na.startsWith(nb) || nb.startsWith(na)) return 0.9;
  const ta = new Set(na.split(' ')), tb = new Set(nb.split(' '));
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter++;
  return inter / Math.max(ta.size, tb.size);
}

export function haversineM(lat1, lng1, lat2, lng2) {
  const R = 6371000, toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1), dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/// Pick the best candidate venue for [place] from [venues], or null.
/// Requires a believable name overlap AND physical proximity.
export function bestMatch(place, venues) {
  let best = null, bestScore = 0;
  for (const v of venues) {
    if (v.lat == null || v.lng == null) continue;
    const dist = haversineM(place.lat, place.lng, v.lat, v.lng);
    if (dist > 150) continue; // must be the same spot
    const ns = nameScore(place.name, v.name);
    if (ns < 0.5) continue; // must be plausibly the same venue
    const score = ns - dist / 1500; // name dominates, distance tie-breaks
    if (score > bestScore) { bestScore = score; best = { v, dist, ns }; }
  }
  return best;
}

// --- main loop ------------------------------------------------------------
export async function runEnrichment({ name, source, envKey, fetchNear, mapVenue, limit = 1000, delayMs = 160 }) {
  const key = process.env[envKey];
  if (!key) {
    console.error(`[enrich:${name}] ${envKey} not set — pass it in the shell env, e.g.\n` +
      `  ${envKey}=… node tool/enrich_places_${name}.mjs\nNothing written.`);
    process.exit(2);
  }

  const db = JSON.parse(readFileSync(CATALOG_PATH, 'utf8'));
  const entries = db.entries;
  const places = entries.filter((e) => e.kind === 'place' && e.lat != null && e.lng != null);
  console.log(`[enrich:${name}] ${places.length} place(s) to consider.`);

  const stats = { tried: 0, matched: 0, hours: 0, rating: 0, coords: 0, errors: 0 };
  let processed = 0;

  for (const p of places) {
    if (processed >= limit) break;
    processed++;
    stats.tried++;
    try {
      const venues = await fetchNear(p, key);
      const m = bestMatch(p, venues);
      if (!m) { await sleep(delayMs); continue; }
      const facts = mapVenue(m.v);
      let touched = false;

      if (facts.openingHours && !p.openingHours) { p.openingHours = facts.openingHours; stats.hours++; touched = true; }
      if (facts.rating != null && p.rating == null) { p.rating = Math.round(facts.rating * 10) / 10; stats.rating++; touched = true; }
      if (facts.address && !p.address) { p.address = facts.address; touched = true; }
      if (facts.subcategory && (!p.subcategory || p.subcategory.length < 2)) { p.subcategory = facts.subcategory; touched = true; }
      // Nudge coords only if the provider's are very close (a refinement, not a move).
      if (m.dist <= 60 && facts.lat != null && facts.lng != null) {
        p.lat = facts.lat; p.lng = facts.lng; stats.coords++; touched = true;
      }

      if (touched) {
        stats.matched++;
        if (!String(p.source || '').includes(source)) {
          p.source = p.source ? `${p.source}+${source}` : source;
        }
        p.enrichedAt = new Date().toISOString();
        p.confidence = Math.min(0.9, Math.max(p.confidence || 0.5, 0.8));
      }
    } catch (e) {
      if (e instanceof FatalProviderError) {
        console.error(`[enrich:${name}] ABORT — ${e.message}\n` +
          `Provider not usable right now → catalog left UNCHANGED (graceful no-op).`);
        return { ...stats, aborted: true };
      }
      stats.errors++;
      if (stats.errors <= 3) console.error(`[enrich:${name}] ${p.name}: ${e.message}`);
    }
    await sleep(delayMs);
  }

  db.generated = new Date().toISOString();
  writeFileSync(CATALOG_PATH, JSON.stringify(db, null, 1) + '\n');
  appendNotice(name, source, stats);

  console.log(`[enrich:${name}] done — matched ${stats.matched}/${stats.tried} ` +
    `(+${stats.hours} hours, +${stats.rating} ratings, +${stats.coords} coords, ${stats.errors} errors).`);
  return stats;
}

function appendNotice(name, source, stats) {
  const marker = `<!-- enrich:${source} -->`;
  let txt = '';
  try { txt = readFileSync(NOTICES_PATH, 'utf8'); } catch (_) {}
  const stamp = new Date().toISOString().slice(0, 10);
  const line =
    `${marker}\n- **${name[0].toUpperCase()}${name.slice(1)} Places** (enrichi ${stamp}) — ` +
    `${stats.matched} lieux enrichis (horaires/note/coordonnées). Données © ${name} / OpenStreetMap, ` +
    `selon les conditions de ${name}. Enrichissement au BUILD ; le runtime reste hors-ligne.\n`;
  if (txt.includes(marker)) {
    txt = txt.replace(new RegExp(`${marker}[\\s\\S]*?(?=\\n<!-- |\\n## |$)`), line);
  } else {
    txt += (txt.endsWith('\n') ? '' : '\n') + '\n' + line;
  }
  writeFileSync(NOTICES_PATH, txt);
}
