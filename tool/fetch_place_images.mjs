#!/usr/bin/env node
// S10.1C — per-activity open images for the STATIC catalog (kill the generic look).
//
// Most static rows are OSM places (cafés, parks, museums…) with NO Wikidata QID,
// so S10C's P18 path never reached them. Here we reconcile each static place to a
// Wikidata entity by NAME, then VERIFY the match geographically (the entity's
// coordinate P625 must sit within ~0.7 km of the venue) before trusting its P18
// image. Geo-verification is what keeps this precise: a real photo of THAT place,
// or nothing — a wrong photo is worse than the category-accurate fallback.
//
// Flow per place: wbsearchentities(name) -> wbgetentities(P625,P18) ->
// geo-verify -> Commons imageinfo (thumb + licence + author) -> CC/CC0/PD only
// -> download 900px -> rewrite imageRef + imageAttribution + imageLicense.
//
// Runtime stays OFFLINE: images are bundled under assets/images/catalog/.
// USAGE: node tool/fetch_place_images.mjs [--limit N] [--category cafe,nature]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const DATA = path.join(ROOT, 'assets', 'data');
const OUT = path.join(ROOT, 'assets', 'images', 'catalog');
fs.mkdirSync(OUT, { recursive: true });

const UA = 'VybiaV2-ingest/1.0 (research; samdimmai@gmail.com)';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const args = process.argv.slice(2);
const LIMIT = (() => {
  const i = args.indexOf('--limit');
  return i >= 0 ? parseInt(args[i + 1], 10) : Infinity;
})();
const CATS = (() => {
  const i = args.indexOf('--category');
  return i >= 0 ? new Set(args[i + 1].split(',')) : null;
})();
const GEO_KM = 0.7; // entity must be within this of the venue to trust its photo

async function getJson(url) {
  for (let a = 0; a < 4; a++) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': UA } });
      if (r.ok) return await r.json();
    } catch (_) {}
    await sleep(1000 * (a + 1));
  }
  return null;
}

const stripHtml = (s) => (s || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();

function licenseOk(short, url) {
  const s = (short || '').toLowerCase();
  const u = (url || '').toLowerCase();
  return (
    s.includes('cc') || s.includes('public domain') || s.includes('pd') ||
    u.includes('creativecommons.org') || u.includes('publicdomain')
  );
}

function haversineKm(aLat, aLng, bLat, bLng) {
  const R = 6371, toR = (d) => (d * Math.PI) / 180;
  const dLat = toR(bLat - aLat), dLng = toR(bLng - aLng);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toR(aLat)) * Math.cos(toR(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

async function searchEntities(name) {
  const j = await getJson(
    `https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${encodeURIComponent(name)}&language=fr&uselang=fr&type=item&limit=5&format=json`,
  );
  await sleep(180);
  return (j?.search || []).map((s) => s.id).filter(Boolean);
}

async function entitiesClaims(qids) {
  if (!qids.length) return {};
  const j = await getJson(
    `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${qids.join('|')}&props=claims&format=json`,
  );
  await sleep(180);
  const out = {};
  for (const [qid, e] of Object.entries(j?.entities || {})) {
    const coord = e.claims?.P625?.[0]?.mainsnak?.datavalue?.value;
    const img = e.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
    out[qid] = { coord, img };
  }
  return out;
}

async function commonsInfo(filename) {
  const j = await getJson(
    `https://commons.wikimedia.org/w/api.php?action=query&titles=${encodeURIComponent('File:' + filename)}&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=900&format=json`,
  );
  await sleep(160);
  const pages = j?.query?.pages;
  if (!pages) return null;
  const ii = Object.values(pages)[0]?.imageinfo?.[0];
  if (!ii) return null;
  const em = ii.extmetadata || {};
  return {
    thumburl: ii.thumburl,
    license: em.LicenseShortName?.value || em.License?.value,
    licenseUrl: em.LicenseUrl?.value,
    artist: stripHtml(em.Artist?.value) || 'Wikimedia Commons',
  };
}

async function download(url, dest) {
  try {
    const r = await fetch(url, { headers: { 'User-Agent': UA } });
    if (!r.ok) return false;
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length < 1500) return false;
    fs.writeFileSync(dest, buf);
    return true;
  } catch (_) {
    return false;
  }
}

const isStatic = (e) =>
  e.availability ? e.availability === 'static' : ['place', 'travel', 'online'].includes(e.kind);

async function main() {
  const doc = JSON.parse(fs.readFileSync(path.join(DATA, 'vybia_catalog.json'), 'utf8'));
  const entries = doc.entries;

  const before = entries.filter((e) => (e.imageRef || '').startsWith('assets/images/catalog/')).length;

  let targets = entries.filter(
    (e) =>
      isStatic(e) &&
      !(e.imageRef || '').startsWith('assets/images/catalog/') &&
      typeof e.lat === 'number' && typeof e.lng === 'number',
  );
  if (CATS) targets = targets.filter((e) => CATS.has(e.category));
  if (targets.length > LIMIT) targets = targets.slice(0, LIMIT);

  console.log(`S10.1C — ${before} real images before · scanning ${targets.length} static places (geo-verified ≤ ${GEO_KM} km)`);

  const notices = [];
  let bundled = 0, tried = 0;
  for (const e of targets) {
    tried++;
    const qids = await searchEntities(e.name);
    if (!qids.length) continue;
    const claims = await entitiesClaims(qids);
    // first candidate that is geo-near AND has an image
    let file = null, matchedQid = null;
    for (const qid of qids) {
      const c = claims[qid];
      if (!c?.coord || !c.img) continue;
      const km = haversineKm(e.lat, e.lng, c.coord.latitude, c.coord.longitude);
      if (km <= GEO_KM) { file = c.img; matchedQid = qid; break; }
    }
    if (!file) continue;

    const info = await commonsInfo(file);
    if (!info?.thumburl) continue;
    if (!licenseOk(info.license, info.licenseUrl)) {
      console.log(`  skip non-free: ${e.name} [${info.license}]`);
      continue;
    }
    const dest = path.join(OUT, `${e.id}.jpg`);
    if (!(await download(info.thumburl, dest))) continue;

    e.imageRef = `assets/images/catalog/${e.id}.jpg`;
    e.imageAttribution = `${info.artist} — ${info.license} (Wikimedia Commons)`;
    e.imageLicense = info.license;
    e.confidence = Math.min(1, (e.confidence || 0.6) + 0.1);
    notices.push(`- **${e.name}** (${e.category}) — \`${e.id}.jpg\` · ${matchedQid} · ${info.artist} · ${info.license} · File:${file}`);
    bundled++;
    if (bundled % 5 === 0 || bundled === 1) console.log(`  [${bundled}] ${e.name} [${info.license}]`);
  }

  fs.writeFileSync(path.join(DATA, 'vybia_catalog.json'), JSON.stringify(doc, null, 1));

  const after = before + bundled;
  const header = `# Per-activity place images (S10.1C)\n\nReal, open-licensed photos fetched at BUILD TIME from Wikimedia Commons via a\nNAME→Wikidata reconciliation that is GEO-VERIFIED (entity coordinate within\n${GEO_KM} km of the venue). CC / CC0 / Public-Domain only. Runtime is offline\n(images bundled under assets/images/catalog/).\n\n${bundled} new place images this run · ${after} per-activity images total.\n\n`;
  // append to the existing S10C notices rather than clobbering them
  const existing = fs.existsSync(path.join(OUT, 'NOTICES.md'))
    ? fs.readFileSync(path.join(OUT, 'NOTICES.md'), 'utf8')
    : '';
  fs.writeFileSync(path.join(OUT, 'NOTICES.md'), header + notices.join('\n') + '\n\n---\n\n' + existing);

  console.log(`\nDONE — tried ${tried}, bundled ${bundled}. Coverage ${before} → ${after} / ${entries.length}.`);
}

main();
