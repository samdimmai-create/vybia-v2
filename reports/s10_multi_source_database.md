# S10 — Our multi-source activity + preference database (live)

**Sprint:** S10 (Parts A–F) · **City:** Montréal · **Schema:** `vybia.catalog.v1`
**Status:** complete — analyze clean, 125 tests green, `flutter build web --release` OK,
5/5 Chrome proofs captured. Engine + planner read OUR database (all kinds), offline,
no API key. Network is used ONLY at build time (one-off ingestion).

This report closes Part F. Parts A–E shipped in earlier commits
(`bf1605c` A · `a056952` B · `a9d9775` C · `4101478` D · `4d7af07` E).

---

## 1. Schema (Part A)

One serializable record type — `CatalogEntry`
(`lib/features/reco/db/catalog_entry.dart`) — covers every kind via a `kind`
field (`place | event | film | online | travel`); kind-specific fields are
nullable rather than subclasses, so a slice serialises cheaply into a prompt and
the repository stays flat + fast. Lossless `toJson`/`fromJson` round-trip so a
write-back never degrades a record.

- **Common:** id · name · kind · category · subcategory · descFr · imageRef ·
  `tags` (the 8 taste-dim affinities) · `motives` (3-motive affinity) · `lms`
  (4 Beard-&-Ragheb LMS motives) · life-context flags (kidFriendly,
  servesAlcohol, wheelchairAccessible, petFriendly, priceTier 0–3, effortLevel,
  indoor) · timeOfDay · seasons/winterFriendly · provenance
  (`source`, `sourceId`, `enrichedAt`, `confidence`).
- **Kind-specific (nullable):** lat/lng/neighbourhood/address (place·event);
  startsAt/endsAt (event); runtimeMin/year/genre/whereToWatch (film);
  url/provider (online); destination/distanceKm/duration (travel).
- `toActivity()` projects the rich record down to the engine's lean `Activity`
  scoring shape; `llmSlice()` emits the compact prompt-friendly map.
- **PreferenceTaxonomy as DATA** (`assets/data/preference_taxonomy.json` +
  `PreferenceTaxonomy`): dimensions, the 4 motives, and life-contexts with
  allowed values/labels — extensible without code changes.

## 2. Storage choice (Part A)

**Structured JSON + in-memory index + a writable overlay** — chosen over
SQLite/`drift` because it must run in Chrome **and** offline with zero plugins:
`drift`/`sqflite` add web/WASM weight and a worker setup that buys nothing for a
few-hundred-row read-mostly catalog. The bundled asset
(`assets/data/vybia_catalog.json`, 208 entries) loads once before first paint
into a list + by-id/by-kind indexes; a small **writable overlay** (S10E) layers
enriched/upserted records on top (overlay wins), persisted through the existing
local `AppStore`. Queries are linear scans over ~200 rows — sub-millisecond.

## 3. Sources used + licence + counts (Part B)

Ingested at build time by `tool/ingest.mjs`, normalised into the schema, deduped
and attributed. Full attributions in `assets/data/NOTICES.md`.

| Source | Licence | Entries | What we pulled |
|---|---|---:|---|
| **OpenStreetMap** (Overpass snapshot) | ODbL 1.0 | **161** | real Montréal places across 12 categories (café, restaurant, bar, cinema, theatre, museum, gallery, viewpoint, park, garden, market, sports), capped 16/category for balance |
| **Wikidata** (MediaWiki Action API, keyless) | CC0 1.0 | **35** | 11 films (runtime/year/genre), 11 Montréal festivals (events), 13 nearby travel destinations (coords → distance) |
| **Curated** (referencing open catalogs) | original FR copy | **12** | at-home/online activities referencing Internet Archive PD films, open MOOC directories, open recipe/fitness/podcast catalogs |

**Total: 208 entries** — place 161 · film 11 · event 11 · travel 13 · online 12.
Category spread: culture 69 · nature 42 · food 27 · creative 22 · nightlife 19 ·
active 16 · cafe 11 · wellness 2. Price tiers: 0→56, 1→81, 2→71. Life-context
flags populated on all 208 (kidFriendly true 178 / false 30).

**Considered, not used this build** (documented expansion path): TMDB (needs a
key — Wikidata used instead to stay keyless/offline); Eventbrite/Meetup
(gated/paid — festivals from Wikidata); Wikivoyage / OpenTripMap (viable free
travel sources — the Wikidata destination set already covers `travel` for this
seed). Wikimedia Commons / Openverse is the documented per-activity image path
(S10C; `imageAttribution`/`imageLicense` fields ready, 17 entries attributed).

## 4. Category → dimension / motive map (Part B)

`tool/ingest.mjs` maps each source category to our 8 taste dims + 3 motives +
context flags via one documented table (`PLACE`, `lmsAffinity`). Tag polarity:
energy calm→lively · social solo→group · novelty sure→new · indoor out→in ·
timing day→evening · budget cheap→splurge · vibe intimate→effervescent;
`distance` stays 0.5 (real haversine applied at runtime). The denormalised `lms`
mirrors Dart `LeisureMotivation.affinityFor` so the persisted readout matches
what the engine recomputes. Example rows:

| OSM cat | our category | energy/social/novelty/timing/vibe | motives (hed/relax/eudai) | flags |
|---|---|---|---|---|
| cafe | cafe | .25/.45/.30/.30/.35 | .45/.80/.25 | kid✓ alc✗ wheel✓ pet✓ |
| bar | nightlife | .60/.85/.40/.85/.80 | .85/.40/.20 | kid✗ alc✓ wheel✓ |
| museum | culture | .30/.40/.60/.30/.35 | .40/.50/.80 | kid✓ alc✗ wheel✓ |
| park | nature | .45/.50/.40/.40/.45 | .50/.70/.40 | kid✓ alc✗ wheel✓ pet✓ |
| sports | active | .80/.55/.45/.50/.55 | .55/.35/.55 | kid✓ effort .8 |

## 5. The engine reads our DB (Part D)

`liveActivityCatalog()` (`reco_controller.dart`) prefers OUR database when loaded,
falling back to the thin OSM snapshot, then the hand-authored seed — so the loop
never starves. The engine handles all kinds (non-geo films/online get a null
distance so they're neither distance-filtered nor falsely rewarded as "right
here"). `ActivityRepository` exposes fast queries: `byKind`, `byCategory`,
`feasibleFor(contexts)`, `entryById`.

**LLM-ready seam — `queryForContext(profile, contexts, context, kind, limit)`** —
returns a `CandidateSlice` = the exact shape a future Claude curation/enrichment
call will receive: a `context` header (mood, profile axes, active contexts,
location, hour, month, optional kind) + a small ranked `candidates` list of
`CatalogEntry.llmSlice()` maps + their ids. Deterministic, on-device, no network.

## 6. Enrichment seam (Part E)

`EnrichmentService.proposeEnrichment(entry) → patch` is the single contract a
provider implements. Today: `LocalRuleEnrichmentProvider` (deterministic,
on-device) fills ONE gap at a time in a fixed order (description → neighbourhood
→ time-of-day → a capped confidence nudge), so the read→propose→enrich→save loop
is real and testable without a model. Write path:
`ActivityRepository.upsert` / `enrichActivity(id, patch, source, enrichedAt)` /
`enrichWith(service, id)` — all persisted through `AppStore.saveOverlay`, hydrated
on next launch via `hydrateOverlay`. **Swapping the stub for a Claude-backed
provider changes nothing else.**

## 7. Proof (Part F)

Visible local Chrome (`tool/web_shoot.sh` + `tool/cdp_capture.mjs`), no
simulator. Built with `--dart-define=VYBIA_PROOF10=true`
(`lib/features/dev/s10_proof_tour.dart`, wired in `lib/app.dart`); every frame is
backed by the REAL `ActivityRepository` + `RecommendationEngine`.

| Screenshot | Proves |
|---|---|
| `screenshots/s10_reco_place.png` | place rec ("Théâtre du Rideau Vert") — DB attributes + image + tailored "pourquoi" + universal bubble |
| `screenshots/s10_reco_film.png` | film rec ("Inception") — kind-specific line `Culture · 2010 · science-fiction · cinema` |
| `screenshots/s10_reco_travel.png` | travel rec ("Bromont") — `Escapade · Bromont · journée` |
| `screenshots/s10_context_db.png` | life-context filter on the NEW flags: `feasibleFor({avecEnfants, sansAlcool})` → **163/208** kept, drops the bar AND a non-kid-friendly film (spans kinds) |
| `screenshots/s10_enriched.png` | an entry AFTER stub enrichment persisted: AVANT (empty desc, source osm) → APRÈS (filled FR desc, `source: claude`, `enrichi: 2026-06-20`) |

Tests added across A–E (run green): schema round-trip per kind
(`catalog_entry_test.dart`), repository queries by context/kind/time + write-back
persists + reloads + engine serves multiple kinds (`activity_repository_test.dart`).

## 8. Coverage gaps + what's left for Claude / the image layer

- **Per-activity imagery is sparse.** Most entries fall back to a category image
  (`assets/images/places/<cat>.jpg`); only 17 carry an open-licensed Commons
  image. Next: bulk Wikimedia Commons / Openverse fetch (S10C path) + the
  AI-generated layer (the `imageRef` field is ready, the bubble works on any
  image).
- **Breadth tilts local/place (161/208).** Films (11), events (11), travel (13)
  and online (12) are seed-thin — enough to prove every kind end to end, not yet
  a deep catalog. Expansion: TMDB (films, with a key), Wikivoyage/OpenTripMap
  (travel), city open-data calendars (events with real dates).
- **`wellness` is underfilled (2).** No clean free source mapped this build.
- **Enrichment is rule-based.** The stub fills structural gaps; richer copy,
  "where to watch" freshness, and real event dates are exactly the
  `queryForContext` → Claude-provider seam, already wired and tested.
- **Minor:** the stub's templated description is gender-agnostic ("une option
  créatif") — a cosmetic FR-grammar gap a Claude provider naturally fixes.

`assets/data/NOTICES.md` carries every attribution. Final commit:
`S10: our multi-source database live`.
