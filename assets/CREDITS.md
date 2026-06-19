# Image credits

All bundled images are free-to-use placeholders sourced from **Lorem Picsum**
(<https://picsum.photos>), which serves photographs from **Unsplash** under the
[Unsplash License](https://unsplash.com/license) (free for commercial and
non-commercial use, no attribution required — recorded here anyway for clarity).

Downloaded 2026-06-19 at fixed photo IDs for reproducibility. Re-fetched in S2
at higher resolution (1280×1600) for crisper full-bleed bubble scenes.

## Demo / recommendation scenes (`assets/images/recos/`)
| File | Source | Theme |
|------|--------|-------|
| `cafe.jpg` | picsum.photos/id/164 | cozy indoor |
| `rooftop.jpg` | picsum.photos/id/1059 | calm outdoor |
| `walk_night.jpg` | picsum.photos/id/1015 | city-night / outdoor |
| `cinema.jpg` | picsum.photos/id/1080 | indoor |

## Emotion bubbles (`assets/images/emotions/`)
| File | Source |
|------|--------|
| `calm.jpg` | picsum.photos/id/1025 |
| `curious.jpg` | picsum.photos/id/1039 |
| `social.jpg` | picsum.photos/id/1062 |
| `energetic.jpg` | picsum.photos/id/1074 |

These are stand-ins for the V1 → V2 image library; final curated art will replace
them in a later sprint. The point of S1 is to prove the universal refraction
treatment works on real bundled images.

## S3 seed catalog (20 Montréal activities)

The S3 activity catalog (`lib/features/reco/data/activity_catalog.dart`) reuses
the eight bundled images above, each mapped to the activity whose mood/category
it best evokes (e.g. `cafe.jpg` → café & librairie, `energetic.jpg` → randonnée,
vélo, kayak, escalade, `walk_night.jpg` → balade nocturne, patin, ciel étoilé).
Dedicated per-activity photography is a follow-up; the engine, scenes and
universal bubble are fully functional on these placeholders. Activity
coordinates are approximate real Montréal venue locations from OSM/Wikivoyage
open knowledge.
