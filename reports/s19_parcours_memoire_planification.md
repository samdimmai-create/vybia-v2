# S19 — Parcours · Boucle · Mémoire · Planification

**Statut : livré.** `flutter analyze` propre · `flutter test` 254 vert (baseline 229,
+25 nouveaux). Aucun build local lourd (machine-safe respecté). Déployé via
`./tool/deploy.sh` (push → build cloud GitHub Pages).

**Live (à ouvrir sur iPhone) :** https://samdimmai-create.github.io/vybia-v2/

L'orbe, les seuils de commit, le throw/flick, l'effet de bord, le dégradé de coin,
la transition d'eau, la palette et le thème **n'ont pas été touchés** (validés S22,
5/5). Le travail S19 porte uniquement sur la boucle / mémoire / questions /
planification / fond d'accueil.

---

## Ce qui change, concrètement

### A — La boucle entrelacée + le MOMENT + zéro répétition (`S19A/B/C`)
- Nouveau modèle **`MomentContext`** : jour de la semaine + heure → un **créneau**
  (`matin / après-midi / soir / nuit`) + un **bucket d'humeur** (`posé / ouvert /
  plein d'élan`). Chaque réponse ET chaque réaction est estampillée du moment.
- La boucle Explorer alterne déjà rondes de recos ↔ petits lots de questions
  adaptatives (S9B) ; on y branche désormais l'enregistrement du moment, et la
  non-répétition : une activité déjà réagie dans la session n'est jamais re-montrée
  (set `decided` en mémoire), une question déjà répondue n'est jamais reposée.

### B — Mémoire temporelle inter-sessions (`S19B`)
- Nouveau **`PreferenceMemory`** (logique pure, persistée via `AppStore`) qui
  applique l'apprentissage **d'une session à l'autre** :
  - un **« Pas pour moi »** n'est **pas re-proposé dans le même créneau + humeur**
    (il peut ressortir à un autre moment / une autre humeur) ;
  - un **« intéressant » non encore vécu** est **re-proposé les AUTRES jours** —
    un rappel doux d'une envie pas encore vécue (petit bonus de score `+0.05`,
    jamais dominant) ;
  - une activité **planifiée** est marquée vécue → elle ne ressort plus ;
  - les **questions fermement répondues pour un contexte ne sont plus reposées**.
  Vybia donne le sentiment de **se souvenir** de toi.

### C — Questions pertinentes, variées, interreliées (`S19C`)
- Le moteur reste *information-greedy* (dimension la moins certaine), mais en cas
  d'égalité il **suit le fil** : il privilégie une question reliée à ce que la
  dernière réponse vient de toucher (cible + nudges), au lieu de sauter sur une
  question générique. Chaque réponse oriente donc visiblement la suivante.
- Aucune formulation répétée dans une session (une question par id, jamais
  reposée) ; la couche Claude (S15) revoice les libellés, repli déterministe.

### D — Planifier-depuis-zéro + écran RÉCAP/confirmation (`S19D`)
- **Planifier depuis l'Accueil (de zéro)** : `Quand ?` → `Avec qui ?` → humeur →
  on entre dans **la boucle** pour trouver l'activité, le brouillon de plan étant
  porté jusqu'au récap.
- Nouvel **écran RÉCAP** affiché **avant** d'enregistrer un (re)plan, par-dessus
  l'image de l'activité : image + titre + résumé + détails de planification (avec
  place réservée aux futures actions « compléter » : réservation, billets,
  itinéraire). Orbe sur cet écran :
  - **HAUT** = détails de la planification
  - **BAS** = confirmer / enregistrer
  - **GAUCHE** = partager / inviter (copie une invitation prête à partager)
  - **DROITE** = annuler / supprimer
  Les deux chemins (depuis une reco, et depuis-zéro) et le « Modifier » de Mes
  Plans convergent vers ce récap.

### E — Fond d'Accueil dynamique + finitions (`S19`)
- Le fond de l'Accueil est désormais une **vraie image qui change selon l'heure /
  le jour / l'humeur habituelle à ce moment** (historique persistant si dispo,
  sinon heure + saison ; week-end ≠ semaine ; matin d'hiver → image cosy). Une
  ligne d'invitation calme change aussi avec le moment.
- **Important** : le champ sea-glass validé (`CalmHomeField`) n'est pas remplacé —
  il est posé en **voile semi-transparent (0.66)** par-dessus la photo, donc le
  thème eau/glace domine toujours et l'orbe est intact. Sans image (tout premier
  lancement), on retombe exactement sur l'ancien fond plein.

---

## Décisions prises en autonomie (à signaler)
- **Suppression moment-aware plutôt que permanente** : avant S19 un « j'aime » ET
  un « pas pour moi » étaient bannis pour toujours. C'était incompatible avec
  « le “intéressant” ressort les autres jours ». La suppression inter-sessions est
  donc désormais pilotée par `PreferenceMemory` (créneau/humeur/jour), pas par le
  bannissement global. Le comportement hors-ligne (tests) reste l'ancien.
- **`markPlanned` au moment du `Planifier`** (sélection), pas à la confirmation du
  récap : choisir « Planifier » est déjà un signal d'intention fort. Conséquence
  mineure : annuler tout en bas du récap laisse l'activité marquée vécue. Acceptable.
- **Partager = copie presse-papier** (pas de plugin de partage natif embarqué) :
  une invitation prête à coller, plutôt que d'ajouter une dépendance.

## Tests ajoutés (25)
`moment_test`, `preference_memory_test`, `temporal_memory_loop_test`,
`plan_recap_test`, `accueil_backdrop_test` — couvrent : moment enregistré ;
pas-intéressant non re-montré même créneau (et ressort à un autre) ; intéressant
qui ressort les autres jours ; question non reposée ; plan-depuis-zéro atteint la
boucle ; le récap sauve / révèle ses détails ; le fond colle à l'heure/humeur.

## À vérifier sur iPhone
1. La boucle Explorer alterne questions ↔ recos **sans rien répéter**.
2. Vybia **se souvient** des réactions passées par moment (un « pas pour moi » du
   soir ne revient pas le soir ; un « intéressant » revient un autre jour).
3. L'écran **récap apparaît avant de confirmer** un plan, avec les 4 actions orbe.
4. Le **fond d'Accueil colle à l'heure** (et à ton humeur habituelle quand connue).
