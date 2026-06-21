# S12 — Real data providers wired (weather / places / events / films)

**Sprint:** S12 · **Base:** S11 (`361a8b8`) · **Date:** 2026-06-21
**Status:** implemented, `flutter analyze` clean, `flutter test` green (185),
`flutter build web --release` OK, 5/5 Chrome proof frames captured.

S12 cabled real data sources into the live/data layer behind a secrets-safe config,
each degrading gracefully when its key is absent. Five parts, committed separately.

---

## Security model (hard rule, honoured)

- Every API key is read **only** from `--dart-define` via `String.fromEnvironment`
  (`lib/core/config/api_config.dart`). No key is hardcoded, printed, or committed.
- `.gitignore` excludes `tool/secrets.env`, `*.secrets.env`, `.dart-define*.json`.
  `tool/secrets.env.example` is the committed template; `tool/run_with_keys.sh`
  sources the gitignored `tool/secrets.env` and passes keys via `--dart-define`
  only (values never echoed).
- Build-time enrichment (Geoapify/Foursquare) reads keys from the **shell env**
  only; output is bundled JSON so the app **runtime stays fully offline**.
- Every keyed provider degrades gracefully: no key → unconfigured, empty result,
  `LiveFetchState.needsKey` status, **no crash, no block**. Runtime network lives
  only in the live layer (weather/events/films), each with a short timeout +
  session cache + offline fallback. The static catalog never reaches the network.

### How to pass keys

```bash
# App runtime (live providers) — Chrome:
flutter run -d chrome \
  --dart-define=TMDB_KEY=… \
  --dart-define=TICKETMASTER_KEY=…

# or via the helper (reads tool/secrets.env, gitignored):
./tool/run_with_keys.sh          # flutter run -d chrome
./tool/run_with_keys.sh build    # flutter build web --release

# Build-time place enrichment (offline output) — shell env:
GEOAPIFY_KEY=…   node tool/enrich_places_geoapify.mjs
FOURSQUARE_KEY=… node tool/enrich_places_foursquare.mjs
```

---

## Part A — config / secrets plumbing  (`6c7230c`)

`ApiConfig` exposes `hasGeoapify / hasFoursquare / hasTmdb / hasTicketmaster` and a
per-source `KeyedSourceStatus` (build-stage vs live-stage, what each key unlocks).
`LiveStreamingProvider` now sources its TMDB key from `ApiConfig` (one source of
truth). Test: config absence → providers disabled, statuses graceful.

## Part B — weather: Open-Meteo (keyless)  (`749fd2f`)

`WeatherService` (keyless) reads Open-Meteo current conditions for a lat/lng and
maps the WMO `weather_code` + temperature to the engine's `WeatherSignal`
(snow > rain > deep-cold > clear). Short timeout + session cache + offline
fallback (`null` → S11's weather filter stays skipped, by design).
`RecoController` fetches it in the background on build + on location change, folds
it into `RecoContext.weather`, and re-ranks → **S11 feasibility flips ON**:
rain/snow drop open-air, deep cold (≤ −10 °C) drops non-winter-friendly outdoors.
Threaded through LoopController/EngineLoopScreen/RecoScreen + a shared instance in
the router. Tests: WMO mapping, fetch+cache+offline, **same context clear→rain
shrinks the feasible set**.

## Part C — places enrichment: Geoapify + Foursquare (build-time, offline)  (`2bd52dd`)

Schema gained optional `openingHours` + `rating` on `CatalogEntry` + `Activity`
(round-tripped, projected, shown as chips in the detail overlay).
`tool/_enrich_common.mjs` matches our static places to real venues by
name + proximity, merges richer attributes, tags provenance (`source` += provider,
`enrichedAt` stamped), and attributes in `NOTICES.md`. Two entry scripts:

| Provider | Endpoint | Adds | Result this run |
|---|---|---|---|
| **Geoapify** | Place Details (`/v2/place-details`) | opening hours, finer category, refined coords (OSM-derived; **no ratings**) | **matched 158/161**, **+32 real opening hours**, +158 refined coords |
| **Foursquare** | Places API (`places-api.foursquare.com`, Bearer) | ratings, popularity, hours | integrated + verified; founder's account is **out of free credits (HTTP 429)** → script **aborts cleanly, catalog unchanged** (ratings pending credits) |

Runtime stays fully offline (bundled JSON). Test: round-trip + projection +
bundled-catalog real-hours coverage.

## Part D — live events (Ticketmaster) + films (TMDB)  (`54559de`)

`LiveTicketmasterProvider` (Discovery API, keyed via `ApiConfig`): real dated
concerts/sports/arts/theatre/film near the guest → projected into our schema
(`kind=event, availability=live`) for the **same S11 engine**, with venue coords,
poster image and booking URL. Registered in `LiveAvailabilityService.standard()`;
the merge now **blends + dedupes events by kind+normalised-title** across providers
(open-data first wins). No key → empty + needs-key standby; offline → empty,
never throws.

`LiveStreamingProvider` (TMDB) verified: now-playing films + real posters when
keyed; **snapshot-film fallback + needs-key** when absent. Tests: TM projection,
needs-key standby, offline safety, cross-provider dedupe.

## Part E — proof + report  (this commit)

`S12ProofTour` (`--dart-define=VYBIA_PROOF12=true`) renders five frames; captured
in a visible local Chrome via `tool/web_shoot.sh --tour` + `tool/cdp_capture.mjs`
(never the iOS simulator). All from the **real** runtime:

| File | What it proves |
|---|---|
| `screenshots/s12_weather_clear_vs_rain.png` | same context, clear keeps 3 open-air picks; **rain → ∅ (filtré)** |
| `screenshots/s12_place_enriched.png` | **McKibbins Irish Pub — Lun-Dim 11:30-3:00**, provenance `osm+geoapify` |
| `screenshots/s12_live_ticketmaster.png` | TM = **needs-key standby**; keyless Montréal open-data returned **6 live events** |
| `screenshots/s12_live_tmdb.png` | TMDB = **needs-key standby** → snapshot fallback, no crash |
| `screenshots/s12_offline_fallback.png` | no network/keys → **6 static recommendations**, top pick *Le Studio TD* |

---

## Per-source coverage & what still needs a key

| Source | Key | Stage | Status after S12 |
|---|---|---|---|
| Open-Meteo (weather) | none | live | **Live**, keyless, feasibility filter active |
| Geoapify (places) | provided | build | **Ran** — 158/161 enriched, +32 real hours (bundled, offline) |
| Foursquare (places) | provided | build | **Standby** — account out of free credits (429); ratings pending credits |
| Montréal open-data (events) | none | live | **Live**, keyless (6 events fetched in proof) |
| Ticketmaster (events) | **pending** | live | **Standby** — provider built, needs the (free) key the founder will create |
| TMDB (films) | **pending** | live | **Standby** — provider built, needs the (free) key the founder will create |

**To activate the two standby providers:** create the free TMDB + Ticketmaster
keys, then run with `--dart-define=TMDB_KEY=… --dart-define=TICKETMASTER_KEY=…`
(or put them in `tool/secrets.env` and use `./tool/run_with_keys.sh`). No code
change needed. **To add Foursquare ratings:** add credits to the FSQ account, then
`FOURSQUARE_KEY=… node tool/enrich_places_foursquare.mjs` and rebuild.

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → **185 passed** (incl. new: config absence, weather mapping +
  flip, enrichment round-trip + bundled coverage, Ticketmaster projection +
  dedupe + standby).
- `flutter build web --release` → Built `build/web` (Wasm dry-run OK).
- 5/5 Chrome proof frames captured from the real web build.
