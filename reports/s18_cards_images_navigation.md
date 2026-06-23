# S18 — Cartes · Images réelles · Navigation (+ correctifs orbe & thème)

**Date :** 2026-06-23
**Live (à ouvrir sur iPhone, pas Chrome sur le Mac) :** https://samdimmai-create.github.io/vybia-v2/
**Build cloud :** ✅ vert (Flutter web release → GitHub Pages, run #28010990197)
**`flutter analyze` :** ✅ `No issues found`
**`flutter test` :** ✅ `All tests passed` (229 tests)
**Machine-safe :** aucun build/run local lourd — validation via analyze + suite de tests + build cloud.

---

## Contexte

Les sprints S18/S19 avaient été sautés (les rapports passent de S17 à S20 ;
le travail avait bifurqué sur l'orbe/eau en S20–S22). Ce sprint rattrape donc
le vrai backlog S18 (cartes / images / navigation) **et** corrige ce que tu as
signalé sur l'orbe et le thème.

Ce que tu avais signalé :
- **Orbe :** direction imprécise · le **lancé** ne marche pas · **disparaît quand on lâche**.
- **Thème :** pas assez transparent · transition eau/glace · effet de bord.

---

## Correctifs ORBE — `e0a1685`

| Symptôme | Cause trouvée | Correctif |
|---|---|---|
| L'orbe **disparaît quand on lâche** | Le bain liquide n'avait aucun « plancher » au repos (`_ambient = 0.0`) : au relâché la présence retombait à 0 et l'orbe s'évanouissait totalement. | Plancher ambiant `0.16` dans la scène : un joyau verre-d'eau **doux et permanent** reste au repos ; au contact il monte à plein, au relâché il **revient à ce plancher** au lieu de disparaître. |
| Le **lancé ne marche pas** | Seuil de flick trop haut (900 px/s) : un vrai flick sur iPhone ne le franchissait quasi jamais → le lancé n'arrivait jamais. Et même lancé, trop de friction le faisait mourir avant le bord. | `throwVelocity 900 → 520`, `friction 1.7 → 1.0`, `stopSpeed 150 → 80`, marge de bord `44 → 52` : un flick naturel est reconnu **et** porte l'orbe jusqu'au bord où il valide. |
| **Direction imprécise** | Validation trop stricte : il fallait 72 px de course **et** un axe très dominant (1.25 ≈ ±38°). Un swipe normal légèrement en biais tombait dans la zone « ambiguë » et **se dissolvait en silence** → ressenti « ça ne prend pas ». | `threshold 72 → 56`, `kAxisDominance 1.25 → 1.12` (±42°) : un swipe franc même un peu en biais valide son bord dominant ; un vrai ~45° reste rejeté. |

## Correctifs THÈME — `e0a1685`

- **Plus de transparence :** la lentille verre/eau veilait trop la photo. Réduit :
  assombrissement de bord `0.34 → 0.20`, teinte sea-glass `0.18 → 0.11`, éclat
  `0.5 → 0.38`, point spéculaire `0.85 → 0.6`. La photo se lit **à travers** le verre.
- **Effet de bord :** la vague décisive inondait presque opaque (`0.82`). Adoucie à
  `0.62` (et le halo de l'orbe `0.58 → 0.46`) : la couleur du bord reste lisible
  mais l'image reste visible dessous — un verre teinté, pas de la peinture.
- **Transition eau/glace :** l'eau translucide (S22E) a été rendue encore plus
  see-through (alpha intérieur/extérieur baissés) pour que la scène **plonge sous
  l'eau** plutôt que d'être recouverte. *À confirmer sur iPhone : ce geste
  (maintien → accueil) demande un retour terrain pour le réglage final.*

---

## S18A — Bottom bubble sur toutes les cartes — `142619a`

- Les scènes de **planification** (la « selected-plan ») portent maintenant la
  **bulle du bas universelle** (titre/description + ligne d'info avec l'activité),
  comme les reco et les questions. Toutes les cartes image/activité sont cohérentes.
- Reco + questions/mood l'avaient déjà : couverture désormais complète.

## S18B — Calque du détail + contenu + % compat — `142619a`

- **Bug de calque corrigé :** la page « Plus d'infos » était un voile translucide
  (`0.82`) qui laissait **transparaître** le titre/pourquoi de la scène en dessous.
  Elle est maintenant adossée à **l'image opaque de l'activité** sous un voile
  sombre → page propre, plus aucun saignement.
- Contenu détail : pourquoi + facteurs + distance/ETA + note + horaires + budget +
  intérieur/plein air + dimensions, **+ un badge `% compatible`** (score moteur).

## S18C — Images réelles variées — `87c3ad7`

- **Problème :** les catégories génériques (café, bar, …) n'avaient **qu'une seule**
  image → deux reco de même catégorie montraient la même photo.
- **Correctif :** `tool/fetch_varied_places.mjs` télécharge (build-time, bundlé,
  offline) des **variantes réelles libres de droits** (CC-BY/CC-BY-SA/CC0/PD) via
  Wikimedia Commons — 8 nouvelles images (cafe2/3, bar2/3, restaurant2, cinema2,
  museum2, park2). Attribution dans `assets/images/NOTICES.md`.
- `imageFor` répartit désormais le choix par **id d'activité + vibe** : chaque
  catégorie a ≥3 candidates et deux cartes voisines de même catégorie ne tombent
  plus sur la même image.
- **Reste à faire (honnête) :** les **lieux/films spécifiques** réels passent déjà
  par la bibliothèque enrichie `assets/images/catalog/` (osm_/event_/film_, ~40
  images). Pour pousser plus loin la couverture « une vraie photo par lieu précis »
  sur tout le catalogue statique, il faudra étoffer la bibliothèque (le pipeline et
  la logique d'assignation sont prêts à absorber plus d'images sans changement de code).

## S18D — Vrai retour arrière + orbe de compatibilité — `17ebbaa`

- **Vrai « Back » d'une étape :** dans la boucle moteur, le double-tap **revient à
  la question précédente** (avec restauration d'un *snapshot* du profil pris avant
  cette réponse, donc l'apprentissage de cette réponse est défait proprement) au
  lieu de quitter toute la boucle. Les étapes de planification reviennent aussi
  d'**une** étape (moment → quitte, avec qui → moment, confirm → avec qui).
  → règle exactement le bug « 2e question, double-tap saute à la page de l'activité ».
- **Orbe de compatibilité :** un petit orbe **rempli d'eau** (on-brand) en haut à
  droite des reco, **plus ou moins plein** selon le score du moteur + le `%`.

---

## À vérifier sur iPhone

1. L'orbe **ne disparaît plus** au relâché (joyau doux toujours présent).
2. Le **lancé** (flick) propulse l'orbe jusqu'au bord et valide.
3. La **direction** d'un swipe franc prend de façon fiable.
4. Le verre/eau et l'effet de bord laissent **mieux voir la photo**.
5. **Chaque carte** a la bulle du bas (reco, questions, planification).
6. La page **détail** est propre (aucun texte qui transparaît) + badge `% compatible`.
7. **Images variées** : deux cafés/bars d'affilée ne montrent plus la même photo.
8. **Double-tap = une seule étape en arrière** (questions ET planification).
9. **Orbe de compatibilité** plus ou moins plein selon le fit.

Puis : retour terrain sur le réglage *feel* de l'orbe (seuils) et sur la
transition eau/glace, qui se peaufinent au doigt sur l'appareil.
