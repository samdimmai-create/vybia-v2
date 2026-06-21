# Vybia V2 — data & image attributions

OUR multi-source activity database (`assets/data/vybia_catalog.json`) is assembled
at BUILD TIME (one-off) by `tool/ingest.mjs` from FREE, license-compatible
sources. The STATIC catalog is read **fully offline** — no runtime network, no
API key.

**S10.1 network policy:** the static catalog stays offline; runtime network is
now allowed but ONLY for the LIVE availability layer (time-sensitive films/
events), and only via FREE/keyless or graceful-fallback sources (see below).

Counts (static build): **208 entries** — place 161 · film 11 · event 11 · travel 13 · online 12.
Films/events are tagged `availability: live` and served by the live layer at
runtime; their snapshot rows remain as an offline fallback only.

## Data sources used

| Source | Licence | What we pulled | How |
|---|---|---|---|
| **OpenStreetMap** | ODbL 1.0 | 161 real Montréal places across 12 categories (café, restaurant, bar, cinema, theatre, museum, gallery, viewpoint, park, garden, market, sports) | Build-time Overpass snapshot `montreal_places.json`, normalised + balanced (cap 16/category) |
| **Wikidata** | CC0 1.0 (public domain) | 11 films (runtime, year, genre), 11 Montréal festivals (events), 13 nearby travel destinations (coords → distance) | MediaWiki Action API (`wbsearchentities` + `wbgetentities`) — chosen over WDQS/SPARQL for robustness to throttling |
| **Curated (open catalogs)** | n/a — original FR copy | 12 at-home/online activities referencing open catalogs (Internet Archive public-domain films, open MOOC directories, open recipe/fitness/podcast catalogs) | Hand-authored, documented per entry's `sourceId` |

## Live availability layer (S10.1B) — RUNTIME network

Time-sensitive kinds are fetched at runtime, each behind a short timeout + cache
+ graceful offline fallback (never blocks, never crashes).

| Source | Licence / key | What it serves | Status |
|---|---|---|---|
| **Ville de Montréal — données ouvertes** ("Événements publics", CKAN `datastore_search_sql`) | CC BY 4.0, **keyless**, CORS-enabled | Real dated events (festivals, ateliers, marchés, expos…) projected to `kind:event, availability:live` | **Working now** |
| **TMDB** (`movie/now_playing` + watch/providers) | Free **API key required** (`--dart-define=TMDB_KEY=…`) | Films now-playing + streaming availability with posters | **Seam** — returns empty + "needs key" when absent |
| **Cinema showtimes** | No free Canada-wide source | In-cinema séances/horaires | **Stub** — interface only; documented gap |

- **Ville de Montréal** open data © Ville de Montréal, Creative Commons
  Attribution 4.0 (CC BY 4.0). https://donnees.montreal.ca/
- A TMDB key unlocks real now-playing titles + per-title streaming providers
  (Netflix/Prime/Crave…) for the region, with real posters.
- A keyed/paid showtimes source would unlock in-cinema séance times.

### Attribution notes
- **OpenStreetMap** © OpenStreetMap contributors, licensed under the Open
  Database License (ODbL). https://www.openstreetmap.org/copyright
- **Wikidata** content is released under CC0 (public domain dedication).
  https://www.wikidata.org/wiki/Wikidata:Licensing
- Per-entry provenance is stored on every record (`source`, `sourceId`,
  `confidence`) so any entry is traceable back to its origin.

### Sources considered but not used this build
- **TMDB** (films) — requires a free API key; films sourced from Wikidata
  (keyless) instead to keep the build fully offline/keyless.
- **Eventbrite / Meetup** — gated/paid APIs; Montréal festivals sourced from
  Wikidata instead.
- **Wikivoyage / OpenTripMap** — viable free sources for travel; the curated
  Wikidata destination set already covers the travel kind for this seed, so they
  are left as a documented expansion path.

## Image attributions

Bundled category images live in `assets/images/places/` and `assets/images/emotions/`
(see `assets/images/NOTICES.md`). Per-activity open-licensed imagery is recorded
on each catalog entry via `imageAttribution` + `imageLicense`, with the Wikimedia
Commons file + author + licence listed in `assets/images/catalog/NOTICES.md`:

- **S10C** — travel/event/film entries via Wikidata P18.
- **S10.1C** — static OSM places reconciled to Wikidata by name, **geo-verified**
  (entity coordinate within 0.7 km of the venue) before trusting its P18 image,
  CC/CC0/PD only. Per-activity coverage **17 → 39 / 208**; generic venues with no
  free per-venue photo keep the category-accurate fallback by design.

Live items (films/events) carry their source's image at runtime (e.g. a TMDB
poster URL), rendered via the same universal bubble (`imageProviderFor`).
