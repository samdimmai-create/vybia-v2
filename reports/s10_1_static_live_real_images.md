# S10.1 — STATIC snapshot + LIVE availability layer + real per-activity images

**Workspace:** `~/Desktop/vybia-v2` · **Base:** S10 (`vybia.catalog.v1`, 208 entries)
**Status:** analyze clean · **141 tests green** · `flutter build web --release` OK ·
4 Chrome proofs captured · committed in 4 parts (A→D).

The founder's split, shipped: **stable things stay in the offline snapshot;
time-sensitive things (films/events) are fetched LIVE and matched to mood/
ambiance like everything else**, with a safe offline fallback. Plus: the static
catalog no longer looks generic — many places now carry their own real photo.

---

## A — Static / live availability model

`Availability { fixed (=static) , live }`, derived from kind and overridable per
record:

- **static:** `place`, `travel`, `online` (cafés, restaurants, bars, museums,
  galleries, parks, gardens, viewpoints, markets, sports, seasonal, getaways,
  evergreen at-home/online).
- **live:** `film` (cinema + streaming) and dated `event` (festivals, screenings,
  markets, programming).

Carried on `CatalogEntry` **and** the lean scoring `Activity`. JSON only persists
the field when it overrides the kind default, so the 200+ snapshot rows stay
byte-stable (no migration). Repository slices keep live kinds OUT of the static
recommendation pool while preserving them as a fallback:
`staticEntries / liveEntries / staticActivities / liveFallbackActivities`.

## B — Live availability layer

`LiveSourceProvider` interface → `fetchAvailableNow(LiveQuery)` returns items
already projected into our `CatalogEntry` schema (`availability: live`), so the
**same** mood/ambiance/context scorer runs on a live event as on a static café.
`LiveAvailabilityService` is the safe front door: per-provider **short timeout +
catch-all + session cache + per-provider status**; offline → empty, never throws.

| Provider | Source | Free / Key | Behaviour |
|---|---|---|---|
| `LiveEventsProvider` | **Ville de Montréal open data** — "Événements publics" (CKAN `datastore_search_sql`), CC BY 4.0, CORS-enabled | **Free + keyless — working now** | Future-dated, geo-located, governance noise filtered out; real dates. Proof returned 6 events dated *today*. |
| `LiveStreamingProvider` | **TMDB** `movie/now_playing` (+watch/providers) | **Free key required** (`--dart-define=TMDB_KEY=…`) | Built against TMDB behind a config seam; **no key → returns empty + "needs key" status**, never crashes. |
| `LiveCinemaProvider` | — (no clean free Canada-wide showtimes API) | n/a | **Interface + stub**; reports unconfigured so the service skips it. Documented gap. |

**Blend & fallback (the recommender):** pool = static (always) + fresh live
items; for any live KIND the layer couldn't supply (offline / no key / error) the
snapshot rows of that kind are used as an **offline fallback**, so events/films
are served live when available and degrade to stale-but-safe otherwise — the loop
never starves and the app works **fully offline** on the static catalog. Fresh
live items are held in memory only (`ActivityRepository._liveNow`), never
persisted (availability goes stale; a relaunch re-fetches).

Wiring: `RecoController` / `LoopController` / screens take an optional
`liveService`; the router supplies one shared `LiveAvailabilityService.standard()`.
Widget tests pass `null` → fully offline. Live poster URLs render through the same
universal bubble via a network-aware `imageProviderFor`.

## C — Per-activity open images (kill the generic look)

`tool/fetch_place_images.mjs` (build-time, runtime stays offline): reconciles each
static OSM place to a Wikidata entity by name, **geo-verifies** the match (entity
coordinate within **0.7 km** of the venue) before trusting its P18 image, then
pulls the Commons thumbnail with a **CC/CC0/PD-only** licence filter. Geo-
verification is what keeps it precise: a real photo of THAT place, or the
category fallback — never a wrong photo.

**Coverage: 17 → 39 / 208** per-activity images (static entries with a real
photo: 11 → 33). +22 new place photos (Cinéma Beaubien, Musée de l'Oratoire, Club
Soda, Théâtre ESPACE GO, Pont Jacques-Cartier, Marché Atwater, Cinéma l'Amour…).
Generic cafés/bars/restaurants with no free per-venue photo keep the category-
accurate fallback **by design** (honest: free per-venue photos simply don't exist
for most generic venues). Attributions in `assets/images/catalog/NOTICES.md`.

## D — Proof (visible Chrome, no simulator)

`tool/web_shoot.sh --tour` against a release web build with
`--dart-define=VYBIA_PROOF101=true` (proof tour `S101ProofTour`):

| Screenshot | Proves |
|---|---|
| `screenshots/s10_1_images_gallery.png` | Several static recos, each with its OWN real photo (Cinéma Beaubien / l'Amour / Banque Scotia, Marché Atwater) — not generic. |
| `screenshots/s10_1_live_event.png` | 5 events fetched LIVE from the open-data calendar, each with a **real date (2026-06-21)**, neighbourhood, Gratuit. |
| `screenshots/s10_1_streaming_seam.png` | Per-source status: events **6 · OK**, TMDB **CLÉ REQUISE**, cinema **CLÉ REQUISE** — keyless-safe. |
| `screenshots/s10_1_live_fallback.png` | Network unreachable → every source fails gracefully (**REPLI**) → degrades to static suggestions; "100 % hors-ligne". |

## Tests added

- `availability_test.dart` (5) — static/live model + byte-stable JSON + slices.
- `live_availability_test.dart` (9) — provider projection, offline→empty,
  timeout→fallback, needs-key seams, static+live blend, image resolver.
- `image_coverage_test.dart` (2) — real-image floor + every `catalog/` ref exists.

## What a key would unlock

- **TMDB key (free):** real now-playing titles + per-title streaming providers
  (Netflix/Prime/Crave…) for the region, with real posters — flips
  `LiveStreamingProvider` from seam to live with no other change.
- **Showtimes source (keyed/paid):** in-cinema séance times — fills
  `LiveCinemaProvider.fetchAvailableNow`; nothing downstream changes.

## Remaining gaps

- Films are LIVE-only behind the TMDB key; without it, film recs fall back to the
  11 snapshot films (offline-safe).
- No free cinema-showtimes source — documented stub.
- Per-activity photos cover notable places (parks, museums, markets, cinemas,
  landmarks); most generic cafés/bars keep category fallbacks.
- Live open-data fetch depends on the browser allowing the cross-origin request
  (CORS verified on the Montréal CKAN; on failure the fallback path is the proof
  in `s10_1_live_fallback.png`).
