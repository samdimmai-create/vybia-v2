# S15 — Brancher Claude : variété générée (avec repli déterministe)

**Sprint :** S15 — plug Claude (Anthropic) via a secure proxy for GENERATED
variety; deterministic fallback.
**Workspace :** `~/Desktop/vybia-v2` · web-first, cloud-built, machine-safe (aucun
build lourd local).

Le **moteur déterministe reste le cerveau** (scoring / sélection / faisabilité —
S11). Claude **écrit seulement le langage** à travers le seam `ContentProvider`
existant : la formulation des questions adaptatives, le « pourquoi ça te va »
par activité, et les phrases de réaction — **fraîches et non répétitives à chaque
session**, nourries par le contexte réel du moteur. En cas d'erreur / timeout /
absence de config, repli automatique sur le `TemplatedContentProvider` (l'appli
ne casse jamais).

Commits (un par partie) :

| Partie | Commit | Contenu |
|---|---|---|
| 0 | `S15.0: palette A default + persisted` | Palette A par défaut permanente + persistée entre rechargements |
| A | `S15A: claude proxy (server-side key)` | Worker Cloudflare qui détient la clé Anthropic |
| B | `S15B: LlmContentProvider via proxy` | Client proxy + provider LLM avec repli |
| C | `S15C: generated questions/why/responses live` | Sélection du provider + variété câblée sur 3 surfaces |
| D | `S15: Claude-generated variety live` | Tests, config build, ce rapport |

---

## 0 — Palette A verrouillée comme défaut permanent + persistée

- **Palette A (*Aurore glacée*)** est désormais le défaut **permanent** de toute
  l'appli (index 0). Le chip de sélection dev reste disponible mais n'est plus
  nécessaire pour le défaut.
- La sélection de palette **persiste entre rechargements complets** (elle était
  *session-scoped* en S14) : `AppStore.readPaletteIndex / savePaletteIndex`
  (clé `vybia.palette.v1`) ; `main()` hydrate le `ValueNotifier` avant le premier
  paint et sauvegarde chaque changement.

## A — Le proxy (détient la clé ; serverless minuscule)

- **Hôte : Cloudflare Workers** (généreux palier gratuit, fait pour ça, ne touche
  pas au site GitHub Pages qui fonctionne). Dossier `proxy/`.
- Le proxy accepte un POST `{system, context, task}`, appelle l'API Anthropic
  Messages avec le modèle **`claude-haiku-4-5`** (rapide + bon marché), un petit
  `max_tokens`, et **renvoie uniquement le texte généré**.
- **Stockage de la clé :** `ANTHROPIC_API_KEY` est un **secret de plateforme**
  Cloudflare (`wrangler secret put`). **Jamais** dans le bundle web, **jamais**
  dans git, **jamais** affichée/loguée/renvoyée. Le `.gitignore` du proxy garde
  `.dev.vars`, `node_modules/`, `.wrangler/` hors de git.
- **CORS :** restreint à l'origine GitHub Pages `https://samdimmai-create.github.io`
  (+ localhost pour le dev).
- **Garde-fous coût :** `max_tokens` plafonné à 320 dans le worker
  (`MAX_TOKENS_CAP`), prompts courts (le moteur a déjà raisonné — Claude n'écrit
  qu'une phrase), et un **rate-limit best-effort par IP** (30 req / 60 s par
  isolate). ⚠️ **À faire aussi :** régler une **limite de dépense** dans la
  console Anthropic (Settings → Limits).

### LA SEULE ÉTAPE FONDATEUR (à faire une fois)

Compte [Cloudflare](https://dash.cloudflare.com/sign-up) gratuit requis.

```bash
cd ~/Desktop/vybia-v2/proxy
npm install -g wrangler        # ou: npx wrangler ...
wrangler login                 # ouvre le navigateur, un clic
wrangler secret put ANTHROPIC_API_KEY
#   ^ colle ta clé Anthropic dans le terminal — elle va DIRECTEMENT à
#     Cloudflare comme secret, PAS dans git, PAS dans un fichier.
wrangler deploy                # imprime l'URL publique, ex :
#   https://vybia-claude-proxy.<ton-sous-domaine>.workers.dev
```

Copie cette **URL publique** : c'est `PROXY_URL` (étape variable ci-dessous). Ce
n'est **pas** un secret ; elle n'expose pas la clé. (Détails : `proxy/README.md`.)

## B — `LlmContentProvider` dans l'appli (appelle le proxy)

- `LlmClient` (`lib/features/reco/content/llm_client.dart`) : client proxy
  *fail-safe*. URL via `--dart-define=PROXY_URL=…` (baked au build cloud — **pas**
  un secret). Timeout court (4 s), petit cache mémoire, renvoie `null` sur **toute**
  défaillance (pas de config, timeout, réseau, non-200, JSON invalide, texte vide).
- `LlmContentProvider` (`…/llm_content_provider.dart`) `implements ContentProvider` :
  - Les méthodes **synchrones** (`why`, `imageFor`) délèguent au
    `TemplatedContentProvider` → le chemin du moteur n'est **jamais** bloqué par un
    appel réseau, et la copie déterministe s'affiche **instantanément**.
  - Les méthodes **génératives async** (`generateWhy`, `generateQuestionPrompt`,
    `generateReaction`) appellent le proxy et **reviennent au texte déterministe
    exact** sur toute défaillance.

## C — Câblage + variété, sans casser le ressenti ≤ 3 min

- **Sélection :** `appContentProvider()` renvoie `LlmContentProvider` quand
  `PROXY_URL` est configuré, sinon le `TemplatedContentProvider`. Le moteur, la
  boucle reco et la boucle questions lisent leur langage à travers ce point unique.
- **3 surfaces, toutes async + non bloquantes + repli garanti :**
  1. **pourquoi** — `RecoController.currentWhy` remplace le « pourquoi » affiché
     dès que Claude répond (écran reco + phase reco de la boucle via
     `LoopController.currentRecoWhy`) ;
  2. **formulation des questions** — `LoopController.currentQuestionPrompt`
     échange la formulation fraîche (même sens, autres mots) dans l'écran de
     boucle ;
  3. **phrases de réaction** — `LoopController.reactionLine` affiche un court
     accusé de réception (toast) sur Intéressant / Pas intéressant.
- **Variété vraie + ancrage :** le système de Claude lui interdit d'inventer un
  lieu ou une activité (« tu reformules SEULEMENT ce que le moteur a déjà
  choisi ») ; le contexte JSON envoyé porte l'activité réelle choisie, ses
  facteurs (`ScoreBreakdown` → chips déterministes), l'humeur et la météo. Le cache
  est mémoire seulement → il se vide au rechargement, donc **chaque run obtient une
  formulation neuve** (non-verbatim), tout en restant ancré dans les vrais facteurs.
- **Snappy :** les appels sont petits et lancés en arrière-plan ; la copie
  déterministe est montrée d'abord, la version Claude se substitue quand elle
  arrive. Aucune attente bloquante.

## D — Déploiement + vérif

- **Build cloud :** `.github/workflows/deploy.yml` passe maintenant
  `--dart-define=PROXY_URL=${{ vars.PROXY_URL }}` au `flutter build web`.
- **Étape fondateur (variable de repo, PAS un secret) :** GitHub →
  *Settings → Secrets and variables → Actions → Variables → New variable* →
  nom `PROXY_URL`, valeur = l'URL publique du worker. Non réglée → define vide →
  l'appli reste 100 % déterministe (le build est toujours sûr).
- **Qualité :** `flutter analyze` **0 issue** ; `flutter test` **203/203 vert**,
  dont `test/llm_content_provider_test.dart` (9 tests : repli sur erreur/timeout/
  non-200/texte vide, sélection du provider par `PROXY_URL`, et usage réel quand
  le proxy répond). **Aucun build lourd local** (Mac protégé).

### Chemin de repli déterministe (résumé)

| Situation | Comportement |
|---|---|
| `PROXY_URL` non configuré | `appContentProvider()` = templated ; aucune tentative LLM |
| Proxy injoignable / timeout / non-200 / JSON invalide / texte vide | `LlmClient.generate` → `null` → texte déterministe exact |
| Proxy répond | texte Claude (guillemets nettoyés) substitué à la volée |

### Rotation de la clé

`cd proxy && wrangler secret put ANTHROPIC_API_KEY` (nouvelle clé) puis
`wrangler deploy`. L'ancienne clé cesse d'être utilisée immédiatement ; révoque-la
dans la console Anthropic.

---

## À toi, fondateur

1. **Une fois :** déploie le worker (étape A ci-dessus) → récupère l'URL publique.
2. **Une fois :** mets cette URL dans la variable de repo `PROXY_URL` (étape D).
3. **À chaque livraison :** `./tool/deploy.sh` pousse → GitHub Actions build → URL
   Pages mise à jour. Ouvre l'URL **sur ton iPhone** (pas dans Chrome sur le Mac).
4. **Ce que tu dois voir :** questions / pourquoi / réponses **fraîches et variées
   à chaque run**. Si le proxy est coupé, ça **retombe silencieusement** sur la
   copie templated — jamais cassé.

> **URL live : https://samdimmai-create.github.io/vybia-v2/**
> Déployée le 2026-06-22 (run Actions `27927985809` — vert). Commit gelé
> `44d4caf`. Build cloud SANS `PROXY_URL` réglé → l'appli est en ligne en mode
> **déterministe** (palette A persistée incluse) ; la variété Claude s'active dès
> que tu fais les 2 étapes fondateur (worker + variable `PROXY_URL`) puis
> `./tool/deploy.sh`.
