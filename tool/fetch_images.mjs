#!/usr/bin/env node
// S10C — per-activity open-licensed images, fetched at BUILD TIME.
//
// Runtime stays OFFLINE: we download CC/CC0/Public-Domain images now, bundle
// them under assets/images/catalog/, and point each catalog entry's imageRef at
// the local asset. No image is fetched at runtime.
//
// Flow: catalog entry (Wikidata sourceId) -> P18 (Commons filename) ->
// Commons imageinfo (thumb url + licence + author) -> licence filter (CC/CC0/PD
// only) -> download 800px thumb -> rewrite imageRef + imageAttribution.
//
// Films rarely carry a free Commons image (posters are non-free) so they keep
// the category-accurate bundled image; travel + events get real per-entry shots.
//
// USAGE: node tool/fetch_images.mjs

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

async function getJson(url) {
  for (let a = 0; a < 4; a++) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': UA } });
      if (r.ok) return await r.json();
    } catch (_) {}
    await sleep(1200 * (a + 1));
  }
  return null;
}

function stripHtml(s) {
  return (s || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

// CC / CC0 / Public-domain only — never bundle a non-free image.
function licenseOk(short, url) {
  const s = (short || '').toLowerCase();
  const u = (url || '').toLowerCase();
  return (
    s.includes('cc') ||
    s.includes('public domain') ||
    s.includes('pd') ||
    u.includes('creativecommons.org') ||
    u.includes('publicdomain')
  );
}

async function p18Map(qids) {
  const out = {};
  for (let i = 0; i < qids.length; i += 45) {
    const batch = qids.slice(i, i + 45);
    const j = await getJson(
      `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${batch.join('|')}&props=claims&format=json`,
    );
    await sleep(300);
    if (!j?.entities) continue;
    for (const [qid, e] of Object.entries(j.entities)) {
      const f = e.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
      if (f) out[qid] = f;
    }
  }
  return out;
}

async function commonsInfo(filename) {
  const j = await getJson(
    `https://commons.wikimedia.org/w/api.php?action=query&titles=${encodeURIComponent('File:' + filename)}&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=900&format=json`,
  );
  await sleep(250);
  const pages = j?.query?.pages;
  if (!pages) return null;
  const p = Object.values(pages)[0];
  const ii = p?.imageinfo?.[0];
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
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!r.ok) return false;
  const buf = Buffer.from(await r.arrayBuffer());
  if (buf.length < 1200) return false; // guard against error stubs
  fs.writeFileSync(dest, buf);
  return true;
}

async function main() {
  const doc = JSON.parse(fs.readFileSync(path.join(DATA, 'vybia_catalog.json'), 'utf8'));
  const entries = doc.entries;

  // Wikidata-backed entries worth a real photo (travel + events + films).
  const targets = entries.filter(
    (e) => typeof e.sourceId === 'string' && /^Q\d+$/.test(e.sourceId) &&
      ['travel', 'event', 'film'].includes(e.kind),
  );
  const qids = [...new Set(targets.map((e) => e.sourceId))];
  console.log(`S10C — ${targets.length} candidate entries, ${qids.length} QIDs`);

  const p18 = await p18Map(qids);
  console.log(`  with P18 image: ${Object.keys(p18).length}`);

  const notices = [];
  let bundled = 0;
  for (const e of targets) {
    const file = p18[e.sourceId];
    if (!file) continue;
    const info = await commonsInfo(file);
    if (!info || !info.thumburl) continue;
    if (!licenseOk(info.license, info.licenseUrl)) {
      console.log(`  skip (non-free): ${e.name} [${info.license}]`);
      continue;
    }
    const dest = path.join(OUT, `${e.id}.jpg`);
    const ok = await download(info.thumburl, dest);
    if (!ok) continue;
    e.imageRef = `assets/images/catalog/${e.id}.jpg`;
    e.imageAttribution = `${info.artist} — ${info.license} (Wikimedia Commons)`;
    e.imageLicense = info.license;
    e.confidence = Math.min(1, (e.confidence || 0.6) + 0.1);
    notices.push(`- **${e.name}** (${e.kind}) — \`${e.id}.jpg\` · ${info.artist} · ${info.license} · File:${file}`);
    bundled++;
    console.log(`  bundled: ${e.name} [${info.license}]`);
  }

  fs.writeFileSync(path.join(DATA, 'vybia_catalog.json'), JSON.stringify(doc, null, 1));

  const header = `# Per-activity image attributions (S10C)\n\nReal, open-licensed images fetched at BUILD TIME from Wikimedia Commons via\nWikidata P18, downloaded under \`assets/images/catalog/\` and bundled (runtime is\noffline). CC / CC0 / Public-Domain only. Source © OpenStreetMap / Wikidata as\nlisted in \`assets/data/NOTICES.md\`.\n\n${bundled} per-activity images bundled this build.\n\n`;
  fs.writeFileSync(path.join(OUT, 'NOTICES.md'), header + notices.join('\n') + '\n');

  console.log(`\nWROTE ${bundled} images + assets/images/catalog/NOTICES.md`);
}

main();
