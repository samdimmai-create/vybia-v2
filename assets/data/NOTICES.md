# Vybia V2 — data & image attributions

OUR multi-source activity database (`assets/data/vybia_catalog.json`) is assembled
at BUILD TIME (one-off) by `tool/ingest.mjs` from FREE, license-compatible
sources. The app reads it **offline** — no runtime network, no API key.

Counts (last build): **208 entries** — place 161 · film 11 · event 11 · travel 13 · online 12.

## Data sources used

| Source | Licence | What we pulled | How |
|---|---|---|---|
| **OpenStreetMap** | ODbL 1.0 | 161 real Montréal places across 12 categories (café, restaurant, bar, cinema, theatre, museum, gallery, viewpoint, park, garden, market, sports) | Build-time Overpass snapshot `montreal_places.json`, normalised + balanced (cap 16/category) |
| **Wikidata** | CC0 1.0 (public domain) | 11 films (runtime, year, genre), 11 Montréal festivals (events), 13 nearby travel destinations (coords → distance) | MediaWiki Action API (`wbsearchentities` + `wbgetentities`) — chosen over WDQS/SPARQL for robustness to throttling |
| **Curated (open catalogs)** | n/a — original FR copy | 12 at-home/online activities referencing open catalogs (Internet Archive public-domain films, open MOOC directories, open recipe/fitness/podcast catalogs) | Hand-authored, documented per entry's `sourceId` |

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
(see `assets/images/NOTICES.md`). Per-activity open-licensed imagery (S10C) is
recorded on each catalog entry via `imageAttribution` + `imageLicense`, and
the Wikimedia Commons file + author + licence are listed in
`assets/images/catalog/NOTICES.md`.
