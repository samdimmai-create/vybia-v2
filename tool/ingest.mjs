#!/usr/bin/env node
// S10B — multi-source BUILD-TIME ingestion for OUR activity database.
//
// Pulls from FREE, license-compatible sources, normalises into the S10A
// CatalogEntry schema, dedupes, attributes, and emits the bundled DB at
// assets/data/vybia_catalog.json + an attribution block for NOTICES.md.
//
// Runtime is OFFLINE: this script runs ONCE at build time. No API key needed.
//
// Sources actually used here:
//   * OpenStreetMap Montréal snapshot (assets/data/montreal_places.json) — ODbL.
//   * Wikidata via the MediaWiki Action API (CC0): structured facts for films,
//     Montréal festivals/events and nearby travel destinations. We use the
//     Action API (wbsearchentities + wbgetentities) rather than WDQS/SPARQL
//     because it is far more robust to throttling for our by-name fetches.
//   * Curated, documented at-home/online set (open catalogs; no clean free API).
//
// USAGE: node tool/ingest.mjs   (writes the catalog; prints counts per kind)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const DATA = path.join(ROOT, 'assets', 'data');
const RAW = path.join(__dirname, '_raw');
fs.mkdirSync(RAW, { recursive: true });

const UA = 'VybiaV2-ingest/1.0 (research; samdimmai@gmail.com)';
const MTL = { lat: 45.5019, lng: -73.5674 }; // Montréal centre (distance origin)
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const clamp01 = (v) => Math.max(0, Math.min(1, v));

// ---------------------------------------------------------------------------
// Wikidata Action API helpers (keyless, throttle-friendly)
// ---------------------------------------------------------------------------
async function api(params) {
  const url =
    'https://www.wikidata.org/w/api.php?' +
    new URLSearchParams({ format: 'json', ...params }).toString();
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': UA } });
      if (res.ok) return await res.json();
    } catch (_) {}
    await sleep(1500 * (attempt + 1));
  }
  return null;
}

async function searchEntity(query, lang = 'fr') {
  const j = await api({
    action: 'wbsearchentities',
    search: query,
    language: lang,
    uselang: lang,
    type: 'item',
    limit: '1',
  });
  await sleep(350);
  const hit = j && j.search && j.search[0];
  return hit ? hit.id : null;
}

async function getEntities(ids) {
  const out = {};
  for (let i = 0; i < ids.length; i += 45) {
    const batch = ids.slice(i, i + 45);
    const j = await api({
      action: 'wbgetentities',
      ids: batch.join('|'),
      props: 'labels|descriptions|claims',
      languages: 'fr|en',
    });
    await sleep(350);
    if (j && j.entities) Object.assign(out, j.entities);
  }
  return out;
}

const label = (e) =>
  (e.labels?.fr?.value) || (e.labels?.en?.value) || null;
const desc = (e) =>
  (e.descriptions?.fr?.value) || (e.descriptions?.en?.value) || '';
function claim(e, prop) {
  return e.claims?.[prop]?.[0]?.mainsnak?.datavalue?.value ?? null;
}
function claimQty(e, prop) {
  const v = claim(e, prop);
  return v && v.amount != null ? Math.abs(parseFloat(v.amount)) : null;
}
function claimYear(e, prop) {
  const v = claim(e, prop);
  if (v && v.time) {
    const m = /([+-])(\d{4})/.exec(v.time);
    if (m) return parseInt(m[2], 10);
  }
  return null;
}
function claimCoord(e) {
  const v = claim(e, 'P625');
  return v && v.latitude != null
    ? { lat: v.latitude, lng: v.longitude }
    : null;
}
function instanceOf(e) {
  return (e.claims?.P31 || [])
    .map((c) => c.mainsnak?.datavalue?.value?.id)
    .filter(Boolean);
}

function haversineKm(a, b) {
  const R = 6371, toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat), dLng = toRad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.sqrt(s)) * 10) / 10;
}

// ---------------------------------------------------------------------------
// Mapping tables  (category → engine taste profile)
// ---------------------------------------------------------------------------
// tags polarity: energy calm→lively · social solo→group · novelty sure→new ·
// distance near→far · indoor out→in · timing day→evening · budget cheap→splurge
// · vibe intimate→effervescent. distance left at 0.5 (real haversine at runtime).
const T = (energy, social, novelty, indoor, timing, budget, vibe) => ({
  energy, social, novelty, distance: 0.5, indoor, timing, budget, vibe,
});
const M = (hedonic, relaxation, eudaimonic) => ({ hedonic, relaxation, eudaimonic });

// One profile per OSM place category.
const PLACE = {
  cafe:       { cat: 'cafe',      tags: T(0.25,0.45,0.30,0.85,0.30,0.25,0.35), m: M(0.45,0.80,0.25), price:1, indoor:true,  winter:true,  effort:0.1, img:'cafe',       tod:['matin','apresMidi'], flags:{kid:true,  alc:false, wheel:true,  pet:true } },
  restaurant: { cat: 'food',      tags: T(0.40,0.70,0.50,0.90,0.80,0.60,0.55), m: M(0.80,0.40,0.40), price:2, indoor:true,  winter:true,  effort:0.1, img:'restaurant', tod:['soir'],              flags:{kid:true,  alc:true,  wheel:true,  pet:false } },
  bar:        { cat: 'nightlife', tags: T(0.60,0.85,0.40,0.80,0.85,0.45,0.80), m: M(0.85,0.40,0.20), price:2, indoor:true,  winter:true,  effort:0.1, img:'bar',        tod:['soir','nuit'],       flags:{kid:false, alc:true,  wheel:true,  pet:false } },
  cinema:     { cat: 'culture',   tags: T(0.30,0.40,0.50,0.95,0.80,0.35,0.30), m: M(0.55,0.55,0.60), price:1, indoor:true,  winter:true,  effort:0.1, img:'cinema',     tod:['soir'],              flags:{kid:true,  alc:false, wheel:true,  pet:false } },
  theatre:    { cat: 'culture',   tags: T(0.40,0.55,0.60,0.90,0.85,0.55,0.50), m: M(0.55,0.45,0.65), price:2, indoor:true,  winter:true,  effort:0.1, img:'theatre',    tod:['soir'],              flags:{kid:true,  alc:false, wheel:true,  pet:false } },
  museum:     { cat: 'culture',   tags: T(0.30,0.40,0.60,0.95,0.30,0.40,0.35), m: M(0.40,0.50,0.80), price:1, indoor:true,  winter:true,  effort:0.2, img:'museum',     tod:['apresMidi'],         flags:{kid:true,  alc:false, wheel:true,  pet:false } },
  gallery:    { cat: 'creative',  tags: T(0.30,0.40,0.65,0.90,0.40,0.30,0.40), m: M(0.45,0.45,0.75), price:0, indoor:true,  winter:true,  effort:0.2, img:'gallery',    tod:['apresMidi'],         flags:{kid:true,  alc:false, wheel:true,  pet:false } },
  viewpoint:  { cat: 'nature',    tags: T(0.45,0.45,0.55,0.05,0.50,0.10,0.45), m: M(0.55,0.65,0.45), price:0, indoor:false, winter:false, effort:0.5, img:'viewpoint',  tod:['apresMidi','soir'],  flags:{kid:true,  alc:false, wheel:false, pet:true } },
  park:       { cat: 'nature',    tags: T(0.45,0.50,0.40,0.05,0.40,0.05,0.45), m: M(0.50,0.70,0.40), price:0, indoor:false, winter:true,  effort:0.4, img:'park',       tod:['matin','apresMidi'], flags:{kid:true,  alc:false, wheel:true,  pet:true } },
  garden:     { cat: 'nature',    tags: T(0.25,0.40,0.45,0.10,0.35,0.20,0.35), m: M(0.45,0.80,0.45), price:1, indoor:false, winter:false, effort:0.3, img:'garden',     tod:['matin','apresMidi'], flags:{kid:true,  alc:false, wheel:true,  pet:false } },
  market:     { cat: 'food',      tags: T(0.55,0.65,0.50,0.40,0.30,0.30,0.60), m: M(0.65,0.45,0.45), price:1, indoor:false, winter:true,  effort:0.3, img:'market',     tod:['matin','apresMidi'], flags:{kid:true,  alc:false, wheel:true,  pet:true } },
  sports:     { cat: 'active',    tags: T(0.80,0.55,0.45,0.70,0.50,0.40,0.55), m: M(0.55,0.35,0.55), price:1, indoor:true,  winter:true,  effort:0.8, img:'sports',     tod:['apresMidi','soir'],  flags:{kid:true,  alc:false, wheel:false, pet:false } },
};

const CAT_IMG = {
  cafe: 'cafe', food: 'restaurant', nightlife: 'bar', culture: 'museum',
  nature: 'park', active: 'sports', wellness: 'garden', creative: 'gallery',
};
const imgPath = (cat) => `assets/images/places/${CAT_IMG[cat] || 'cafe'}.jpg`;

// LMS 4-motive readout, mirrored from Dart LeisureMotivation.affinityFor so the
// denormalised `lms` we persist matches what the engine recomputes at runtime.
function lmsAffinity(tags, m, cat) {
  const cerebral = cat === 'culture' || cat === 'creative';
  const active = cat === 'active' || cat === 'nature';
  return {
    intellectual: clamp01(0.5 * tags.novelty + 0.3 * m.eudaimonic + (cerebral ? 0.2 : 0)),
    social: clamp01(0.55 * tags.social + 0.25 * tags.vibe + 0.2 * m.hedonic),
    competence: clamp01(0.5 * tags.energy + 0.3 * m.eudaimonic + (active ? 0.2 : 0)),
    stimulusAvoidance: clamp01(0.45 * (1 - tags.energy) + 0.35 * m.relaxation + 0.2 * (1 - tags.social)),
  };
}

function entry(o) {
  // o carries kind/category/tags/m + the kind-specific extras.
  const lms = lmsAffinity(o.tags, o.m, o.category);
  return {
    id: o.id,
    name: o.name,
    kind: o.kind,
    category: o.category,
    subcategory: o.subcategory,
    descFr: o.descFr,
    imageRef: o.imageRef,
    tags: o.tags,
    motives: o.m,
    lms,
    tagList: o.tagList || [],
    kidFriendly: o.flags?.kid ?? null,
    servesAlcohol: o.flags?.alc ?? null,
    wheelchairAccessible: o.flags?.wheel ?? null,
    petFriendly: o.flags?.pet ?? null,
    priceTier: o.price,
    effortLevel: o.effort,
    indoor: o.indoor,
    timeOfDay: o.tod || [],
    seasons: o.seasons || ['printemps', 'ete', 'automne', 'hiver'],
    winterFriendly: o.winter,
    source: o.source,
    sourceId: o.sourceId,
    confidence: o.confidence ?? 0.6,
    lat: o.lat ?? null,
    lng: o.lng ?? null,
    neighbourhood: o.neighbourhood ?? null,
    address: o.address ?? null,
    startsAt: o.startsAt ?? null,
    endsAt: o.endsAt ?? null,
    runtimeMin: o.runtimeMin ?? null,
    year: o.year ?? null,
    genre: o.genre ?? null,
    whereToWatch: o.whereToWatch ?? null,
    url: o.url ?? null,
    provider: o.provider ?? null,
    destination: o.destination ?? null,
    distanceKm: o.distanceKm ?? null,
    duration: o.duration ?? null,
    imageAttribution: o.imageAttribution ?? null,
    imageLicense: o.imageLicense ?? null,
  };
}

// ---------------------------------------------------------------------------
// 1. PLACES — from the OSM snapshot (balanced subset, capped per category)
// ---------------------------------------------------------------------------
function ingestPlaces(capPerCat = 16) {
  const snap = JSON.parse(
    fs.readFileSync(path.join(DATA, 'montreal_places.json'), 'utf8'),
  );
  const byCat = {};
  for (const p of snap.places || []) {
    if (!p.name || !PLACE[p.category]) continue;
    (byCat[p.category] ||= []).push(p);
  }
  const out = [];
  for (const [cat, list] of Object.entries(byCat)) {
    const prof = PLACE[cat];
    // Prefer rows that carry a neighbourhood (richer), then take the cap.
    list.sort((a, b) => (b.neighbourhood ? 1 : 0) - (a.neighbourhood ? 1 : 0));
    for (const p of list.slice(0, capPerCat)) {
      out.push(entry({
        id: p.id,
        name: p.name,
        kind: 'place',
        category: prof.cat,
        subcategory: cat,
        descFr: placeDesc(cat, p.neighbourhood),
        imageRef: imgPath(prof.cat),
        tags: prof.tags, m: prof.m, price: prof.price, indoor: prof.indoor,
        winter: prof.winter, effort: prof.effort, tod: prof.tod,
        flags: prof.flags, seasons: prof.winter ? undefined : ['printemps','ete','automne'],
        source: 'osm', sourceId: p.id, confidence: 0.7,
        lat: p.lat, lng: p.lng, neighbourhood: p.neighbourhood,
      }));
    }
  }
  return out;
}
function placeDesc(cat, hood) {
  const where = hood ? ` à ${hood}` : ' à Montréal';
  const m = {
    cafe: `Un café${where} pour ralentir, un bon chaud entre les mains.`,
    restaurant: `Une table${where} où s’attabler et prendre son temps.`,
    bar: `Un bar${where} pour trinquer quand la soirée s’étire.`,
    cinema: `Une salle obscure${where} et l’histoire qui défile.`,
    theatre: `Une scène vivante${where}, le frisson du direct.`,
    museum: `Un musée${where} où flâner d’une salle à l’autre.`,
    gallery: `Une galerie${where}, des œuvres à hauteur d’yeux.`,
    viewpoint: `Un point de vue${where} où la ville se déplie.`,
    park: `Un parc${where} pour respirer et laisser filer le temps.`,
    garden: `Un jardin${where}, le calme et les allées qui serpentent.`,
    market: `Un marché${where}, les étals, les odeurs, le monde.`,
    sports: `Un endroit${where} pour bouger et se dépenser.`,
  };
  return m[cat] || `Un lieu${where} à découvrir.`;
}

// ---------------------------------------------------------------------------
// 2. FILMS — Wikidata (search by title → fetch runtime/year/genre)
// ---------------------------------------------------------------------------
const FILM_TITLES = [
  'Inception', 'Le Fabuleux Destin d’Amélie Poulain', 'Le Voyage de Chihiro',
  'Parasite (film, 2019)', 'La La Land', 'Mad Max: Fury Road', 'Interstellar',
  'The Grand Budapest Hotel', 'Spider-Man: New Generation', 'Coco (film, 2017)',
  'Whiplash (film, 2014)', 'Blade Runner 2049', 'À couteaux tirés',
  'Everything Everywhere All at Once', 'Dune (film, 2021)', 'Incendies',
  'Le Seigneur des anneaux : La Communauté de l’anneau', 'Portrait de la jeune fille en feu',
];
const FILM_WATCH = ['cinema', 'netflix', 'prime', 'crave', 'disney'];

async function ingestFilms() {
  const ids = [];
  for (const t of FILM_TITLES) {
    const id = await searchEntity(t, 'fr');
    if (id) ids.push(id);
  }
  const ents = await getEntities(ids);
  const out = [];
  let i = 0;
  for (const id of ids) {
    const e = ents[id];
    if (!e || !instanceOf(e).includes('Q11424')) continue; // must be a film
    const name = label(e);
    if (!name) continue;
    const runtime = claimQty(e, 'P2047');
    const year = claimYear(e, 'P577');
    // Pick the first genre we recognise across all P136 statements.
    const genres = (e.claims?.P136 || [])
      .map((c) => GENRE[c.mainsnak?.datavalue?.value?.id])
      .filter(Boolean);
    const genre = genres[0] || null;
    const genreFr = genre || 'film';
    const evening = true;
    const tags = T(0.35, 0.45, 0.65, 0.95, evening ? 0.8 : 0.5, 0.3, 0.4);
    const watch = FILM_WATCH[i % FILM_WATCH.length];
    out.push(entry({
      id: `film_${id.toLowerCase()}`,
      name, kind: 'film', category: 'culture', subcategory: genre || 'film',
      descFr: `${name}${year ? ` (${year})` : ''} — ${genreFr}. ${desc(e) || 'À voir, posé, ce soir.'}`,
      imageRef: imgPath('culture'),
      tags, m: M(0.6, 0.5, 0.65), price: watch === 'cinema' ? 1 : 0,
      indoor: true, winter: true, effort: 0.0, tod: ['soir', 'nuit'],
      flags: { kid: false, alc: false, wheel: true, pet: true },
      source: 'wikidata', sourceId: id, confidence: 0.8,
      runtimeMin: runtime ? Math.round(runtime) : null,
      year, genre: genreFr, whereToWatch: watch,
      tagList: genre ? [genre] : ['film'],
    }));
    i++;
  }
  return out;
}
const GENRE = {
  Q496523: 'science-fiction', Q130232: 'drame', Q157443: 'comédie',
  Q1054574: 'romance', Q188473: 'action', Q200092: 'horreur',
  Q319221: 'aventure', Q224700: 'comédie dramatique', Q959790: 'thriller',
  Q20442589: 'comédie musicale', Q842256: 'film d’animation', Q471839: 'science-fiction',
  Q859369: 'comédie romantique', Q1361932: 'film catastrophe', Q645928: 'film policier',
  Q2484376: 'thriller', Q52207310: 'drame', Q1342372: 'film d’aventure',
};

// ---------------------------------------------------------------------------
// 3. EVENTS — Montréal festivals (Wikidata search → coords; recurring month)
// ---------------------------------------------------------------------------
const FESTIVALS = [
  ['Festival international de jazz de Montréal', 'culture', 6],
  ['Juste pour rire', 'culture', 7],
  ['Osheaga', 'nightlife', 7],
  ['Igloofest', 'nightlife', 1],
  ['Festival Mural', 'creative', 6],
  ['Montréal en lumière', 'culture', 2],
  ['Festival du nouveau cinéma', 'culture', 10],
  ['Les Francos de Montréal', 'culture', 6],
  ['Festival international de la bière de Montréal', 'food', 5],
  ['Nuit blanche à Montréal', 'culture', 2],
  ['Fierté Montréal', 'nightlife', 8],
  ['Festival TransAmériques', 'culture', 5],
];
const MONTH_SEASON = (mo) =>
  mo <= 2 || mo === 12 ? 'hiver' : mo <= 5 ? 'printemps' : mo <= 8 ? 'ete' : 'automne';

async function ingestEvents() {
  const ids = [];
  const meta = {};
  for (const [name, cat, mo] of FESTIVALS) {
    const id = await searchEntity(name, 'fr');
    if (id) { ids.push(id); meta[id] = { name, cat, mo }; }
  }
  const ents = await getEntities(ids);
  const out = [];
  const year = new Date().getFullYear() + 1; // next edition
  for (const id of ids) {
    const e = ents[id];
    if (!e) continue;
    const { name, cat, mo } = meta[id];
    const coord = claimCoord(e) || MTL;
    const season = MONTH_SEASON(mo);
    const prof = cat === 'nightlife'
      ? PLACE.bar : cat === 'food' ? PLACE.market
      : cat === 'creative' ? PLACE.gallery : PLACE.theatre;
    const tags = { ...prof.tags, novelty: 0.7, vibe: 0.8, social: 0.8 };
    out.push(entry({
      id: `event_${id.toLowerCase()}`,
      name: label(e) || name, kind: 'event', category: cat,
      subcategory: 'festival',
      descFr: `${label(e) || name} — ${desc(e) || 'un rendez-vous montréalais'}. Édition de ${MONTH_FR[mo]}.`,
      imageRef: imgPath(cat),
      tags, m: M(0.8, 0.3, 0.5), price: 2, indoor: false,
      winter: season === 'hiver', effort: 0.3,
      tod: ['apresMidi', 'soir'], seasons: [season],
      flags: { kid: cat !== 'nightlife', alc: cat === 'nightlife', wheel: true, pet: false },
      source: 'wikidata', sourceId: id, confidence: 0.65,
      lat: coord.lat, lng: coord.lng, neighbourhood: 'Montréal',
      startsAt: `${year}-${String(mo).padStart(2, '0')}-15`,
      tagList: ['festival', season],
    }));
  }
  return out;
}
const MONTH_FR = {1:'janvier',2:'février',3:'mars',4:'avril',5:'mai',6:'juin',7:'juillet',8:'août',9:'septembre',10:'octobre',11:'novembre',12:'décembre'};

// ---------------------------------------------------------------------------
// 4. TRAVEL — nearby destinations (Wikidata search → coords → distanceKm)
// ---------------------------------------------------------------------------
const DESTINATIONS = [
  ['Ville de Québec', 'culture'], ['Mont-Tremblant', 'nature'],
  ['Ottawa', 'culture'], ['Gatineau', 'nature'], ['Sherbrooke', 'culture'],
  ['Trois-Rivières', 'culture'], ['Mont Saint-Hilaire', 'nature'],
  ['Saguenay (ville)', 'nature'], ['Tadoussac', 'nature'], ['Magog', 'nature'],
  ['Parc national d’Oka', 'nature'], ['Bromont', 'active'],
  ['Vieux-Québec', 'culture'], ['Parc national du Mont-Tremblant', 'nature'],
];
function travelDuration(km) {
  if (km < 80) return 'journée';
  if (km < 220) return 'journée ou nuitée';
  return 'week-end';
}
async function ingestTravel() {
  const ids = [];
  const meta = {};
  for (const [name, cat] of DESTINATIONS) {
    const id = await searchEntity(name, 'fr');
    if (id) { ids.push(id); meta[id] = { name, cat }; }
  }
  const ents = await getEntities(ids);
  const out = [];
  for (const id of ids) {
    const e = ents[id];
    if (!e) continue;
    const coord = claimCoord(e);
    if (!coord) continue;
    const { name, cat } = meta[id];
    const km = haversineKm(MTL, coord);
    const prof = cat === 'nature' ? PLACE.park : cat === 'active' ? PLACE.sports : PLACE.museum;
    const tags = { ...prof.tags, novelty: 0.75, distance: 0.9 };
    out.push(entry({
      id: `travel_${id.toLowerCase()}`,
      name: label(e) || name, kind: 'travel', category: cat,
      subcategory: 'escapade',
      descFr: `${label(e) || name} — ${desc(e) || 'une escapade à portée'}. À ~${km} km, ${travelDuration(km)}.`,
      imageRef: imgPath(cat),
      tags, m: cat === 'nature' ? M(0.5, 0.7, 0.6) : M(0.55, 0.45, 0.7),
      price: 2, indoor: false, winter: cat !== 'nature', effort: cat === 'active' ? 0.7 : 0.4,
      tod: ['matin', 'apresMidi'], seasons: ['printemps', 'ete', 'automne'],
      flags: { kid: true, alc: false, wheel: cat === 'culture', pet: true },
      source: 'wikidata', sourceId: id, confidence: 0.7,
      lat: coord.lat, lng: coord.lng,
      destination: label(e) || name, distanceKm: km, duration: travelDuration(km),
      tagList: ['escapade', cat],
    }));
  }
  return out;
}

// ---------------------------------------------------------------------------
// 5. ONLINE / AT-HOME — curated, documented (no clean free API)
// ---------------------------------------------------------------------------
const ONLINE = [
  ['online_recipe', 'Cuisiner une nouvelle recette', 'food', 'Choisir un plat jamais tenté et se lancer, tablier noué.', T(0.4,0.4,0.7,1,0.6,0.2,0.4), M(0.6,0.5,0.6), 0, ['apresMidi','soir'], 'open recipe catalogs', null, ['cuisine','maison']],
  ['online_course', 'Suivre un cours en ligne', 'creative', 'Un MOOC ouvert : apprendre quelque chose, à son rythme.', T(0.3,0.2,0.8,1,0.5,0.0,0.3), M(0.3,0.4,0.85), 0, ['apresMidi','soir'], 'open MOOC catalogs', 'https://www.classcentral.com', ['apprentissage','maison']],
  ['online_pdfilm', 'Soirée film du domaine public', 'culture', 'Un classique libre de droits, lumières tamisées.', T(0.25,0.3,0.5,1,0.85,0.0,0.3), M(0.55,0.6,0.55), 0, ['soir','nuit'], 'Internet Archive (public domain)', 'https://archive.org/details/feature_films', ['film','maison']],
  ['online_yoga', 'Séance de yoga à la maison', 'wellness', 'Dérouler le tapis, respirer, relâcher les épaules.', T(0.35,0.2,0.4,1,0.4,0.0,0.25), M(0.4,0.85,0.5), 0, ['matin','soir'], 'open fitness videos', null, ['bien-être','maison']],
  ['online_boardgame', 'Soirée jeux de société', 'creative', 'Sortir une boîte, rassembler le monde autour de la table.', T(0.55,0.85,0.5,1,0.7,0.1,0.6), M(0.8,0.4,0.4), 0, ['soir','nuit'], 'curated', null, ['jeux','social','maison']],
  ['online_language', 'Apprendre une langue', 'creative', 'Vingt minutes par jour, une langue qui s’installe.', T(0.3,0.2,0.7,1,0.5,0.0,0.3), M(0.3,0.4,0.85), 0, ['matin','soir'], 'open language apps', null, ['apprentissage','maison']],
  ['online_drawing', 'Carnet de croquis', 'creative', 'Un crayon, une page blanche, aucune attente.', T(0.3,0.2,0.6,1,0.4,0.0,0.3), M(0.5,0.6,0.7), 0, ['apresMidi','soir'], 'curated', null, ['créatif','maison']],
  ['online_podcast', 'Marche et podcast', 'wellness', 'Un épisode dans les oreilles, le quartier sous les pieds.', T(0.5,0.2,0.6,0,0.5,0.0,0.3), M(0.45,0.7,0.6), 0, ['matin','apresMidi'], 'open podcast directories', null, ['audio','plein air']],
  ['online_baking', 'Pâtisser un dessert', 'food', 'La maison qui sent bon, la patience récompensée.', T(0.4,0.4,0.6,1,0.5,0.2,0.4), M(0.65,0.55,0.5), 0, ['apresMidi'], 'open recipe catalogs', null, ['cuisine','maison']],
  ['online_stargaze', 'Observer les étoiles', 'nature', 'Sortir, lever les yeux, laisser le ciel faire le reste.', T(0.3,0.4,0.6,0,0.95,0.0,0.35), M(0.5,0.8,0.6), 0, ['nuit'], 'curated', null, ['nature','soir']],
  ['online_writing', 'Atelier d’écriture', 'creative', 'Dix minutes, une consigne, et voir ce qui sort.', T(0.3,0.2,0.7,1,0.6,0.0,0.3), M(0.4,0.6,0.8), 0, ['soir'], 'curated', null, ['créatif','maison']],
  ['online_documentary', 'Documentaire à la maison', 'culture', 'Un sujet qui intrigue, le canapé et la curiosité.', T(0.25,0.3,0.7,1,0.8,0.0,0.3), M(0.4,0.6,0.75), 0, ['soir','nuit'], 'open archives', null, ['documentaire','maison']],
];
function ingestOnline() {
  return ONLINE.map(([id, name, cat, d, tags, m, price, tod, src, url, tagList]) =>
    entry({
      id, name, kind: 'online', category: cat, subcategory: 'à la maison',
      descFr: d, imageRef: imgPath(cat), tags, m, price,
      indoor: cat !== 'nature', winter: true, effort: cat === 'wellness' ? 0.3 : 0.1,
      tod, seasons: ['printemps', 'ete', 'automne', 'hiver'],
      flags: { kid: true, alc: false, wheel: true, pet: true },
      source: 'curated', sourceId: src, confidence: 0.6,
      url, provider: url ? new URL(url).hostname.replace('www.', '') : null,
      tagList,
    }),
  );
}

// ---------------------------------------------------------------------------
// Assemble, dedupe, emit
// ---------------------------------------------------------------------------
function dedupe(entries) {
  const seen = new Set();
  const out = [];
  for (const e of entries) {
    const key = `${e.kind}:${e.name.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(e);
  }
  return out;
}

async function main() {
  console.log('S10B ingestion — pulling free sources…');
  const places = ingestPlaces();
  console.log(`  places (OSM):   ${places.length}`);
  const online = ingestOnline();
  console.log(`  online (curated): ${online.length}`);

  let films = [], events = [], travel = [];
  try { films = await ingestFilms(); } catch (e) { console.log('  films FAILED', e.message); }
  console.log(`  films (Wikidata): ${films.length}`);
  try { events = await ingestEvents(); } catch (e) { console.log('  events FAILED', e.message); }
  console.log(`  events (Wikidata): ${events.length}`);
  try { travel = await ingestTravel(); } catch (e) { console.log('  travel FAILED', e.message); }
  console.log(`  travel (Wikidata): ${travel.length}`);

  const all = dedupe([...places, ...films, ...events, ...travel, ...online]);
  const counts = {};
  for (const e of all) counts[e.kind] = (counts[e.kind] || 0) + 1;

  const doc = {
    schema: 'vybia.catalog.v1',
    generated: new Date().toISOString(),
    city: 'Montréal',
    origin: MTL,
    sources: {
      osm: 'OpenStreetMap (ODbL) — Montréal snapshot',
      wikidata: 'Wikidata (CC0) — films, festivals, travel facts via Action API',
      curated: 'Curated at-home/online set referencing open catalogs',
    },
    counts,
    total: all.length,
    entries: all,
  };
  fs.writeFileSync(path.join(DATA, 'vybia_catalog.json'), JSON.stringify(doc, null, 1));
  // raw cache for reproducibility / debugging
  fs.writeFileSync(path.join(RAW, 'counts.json'), JSON.stringify(counts, null, 2));
  console.log('\nWROTE assets/data/vybia_catalog.json');
  console.log('counts:', JSON.stringify(counts), 'total', all.length);
}

main();
