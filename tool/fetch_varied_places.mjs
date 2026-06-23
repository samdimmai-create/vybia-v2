#!/usr/bin/env node
// S18C — VARIED per-category place images, fetched at BUILD TIME.
//
// The generic venue categories (café, bar, cinema, …) shipped with a SINGLE
// bundled image each, so two same-category recommendations always showed the
// same picture (the founder's "les images se répètent"). This adds a few extra
// REAL, free-licensed (CC-BY / CC-BY-SA / CC0 / PD) images per category so the
// assignment logic can spread the catalogue across a varied set — still fully
// offline at runtime (downloaded + bundled now).
//
// Flow: Commons search (category term) -> imageinfo (url + license + author) ->
// license filter -> download 800px thumb -> save assets/images/places/<cat>N.jpg
// -> append attribution to assets/images/NOTICES.md.
//
// USAGE: node tool/fetch_varied_places.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'assets', 'images', 'places');
const NOTICES = path.join(ROOT, 'assets', 'images', 'NOTICES.md');
fs.mkdirSync(OUT, { recursive: true });

const UA = 'VybiaV2-ingest/1.0 (research; samdimmai@gmail.com)';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// How many EXTRA variants to add per category (named <cat>2.jpg, <cat>3.jpg…),
// and the Commons search term used to find relevant, photogenic shots.
const PLAN = {
  cafe: { extra: 2, q: 'coffee shop interior' },
  bar: { extra: 2, q: 'cocktail bar interior' },
  restaurant: { extra: 1, q: 'restaurant dining room' },
  cinema: { extra: 1, q: 'cinema movie theater interior' },
  museum: { extra: 1, q: 'art museum gallery interior' },
  park: { extra: 1, q: 'city park green' },
};

const OK_LICENSES = [
  'cc0', 'public domain', 'cc-by', 'cc by', 'cc-by-sa', 'cc by-sa',
];

async function getJson(url) {
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
  return r.json();
}

function licenseOk(short) {
  if (!short) return false;
  const s = short.toLowerCase();
  return OK_LICENSES.some((l) => s.includes(l));
}

async function searchImages(term, limit) {
  const url =
    'https://commons.wikimedia.org/w/api.php?action=query&format=json' +
    '&generator=search&gsrnamespace=6&gsrlimit=' + (limit * 4) +
    '&gsrsearch=' + encodeURIComponent(term) +
    '&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=800';
  const j = await getJson(url);
  const pages = j?.query?.pages ? Object.values(j.query.pages) : [];
  const out = [];
  for (const p of pages) {
    const ii = p.imageinfo?.[0];
    if (!ii) continue;
    const meta = ii.extmetadata || {};
    const license = meta.LicenseShortName?.value || '';
    if (!licenseOk(license)) continue;
    const thumb = ii.thumburl || ii.url;
    if (!thumb || !/\.(jpg|jpeg|png)$/i.test(thumb)) continue;
    const author = (meta.Artist?.value || 'Unknown')
      .replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim().slice(0, 80);
    out.push({ title: p.title, thumb, license, author });
    if (out.length >= limit) break;
  }
  return out;
}

async function download(url, dest) {
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!r.ok) throw new Error(`download HTTP ${r.status}`);
  const buf = Buffer.from(await r.arrayBuffer());
  fs.writeFileSync(dest, buf);
  return buf.length;
}

const notices = [];

for (const [cat, cfg] of Object.entries(PLAN)) {
  let got = 0;
  try {
    const results = await searchImages(cfg.q, cfg.extra + 3);
    for (const res of results) {
      if (got >= cfg.extra) break;
      const n = got + 2; // existing image is <cat>.jpg, variants start at 2
      const name = `${cat}${n}.jpg`;
      const dest = path.join(OUT, name);
      try {
        const bytes = await download(res.thumb, dest);
        if (bytes < 3000) { fs.rmSync(dest, { force: true }); continue; }
        notices.push(
          `- places/${name} — ${res.title} — ${res.license} — ${res.author} — via Wikimedia Commons`,
        );
        got++;
        console.log(`OK ${name}  (${res.license})`);
        await sleep(300);
      } catch (e) {
        console.log(`skip ${name}: ${e.message}`);
      }
    }
  } catch (e) {
    console.log(`search failed for ${cat}: ${e.message}`);
  }
  if (got < cfg.extra) console.log(`WARN ${cat}: only ${got}/${cfg.extra}`);
}

if (notices.length) {
  const block = `\n## S18C varied per-category place images (Wikimedia Commons)\n${notices.join('\n')}\n`;
  fs.appendFileSync(NOTICES, block);
  console.log(`\nAppended ${notices.length} attributions to NOTICES.md`);
}
console.log('done');
