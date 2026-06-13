# Design — Identité visuelle Cameroon Innovation (mobile + web)

**Date :** 2026-06-13
**Statut :** spec validée (brainstorming), prête pour le plan d'implémentation.
**Périmètre :** **Cycle 1** de la refonte design. Cycle 2 (refonte du formulaire de rapport CI-F-003)
fera l'objet d'une spec/plan séparés et **réutilisera** le champ `domaine` introduit ici.

## Objectif
Donner à l'app (mobile Flutter + backoffice web) l'identité de Cameroon Innovation : logo,
palette de marque (bleu nuit / noir / blanc / orange), et **représentation des 3 branches**
(Électricité · Informatique-vidéosurveillance · Plomberie) via un système couleur + icône, rendu
réel en taguant chaque tâche d'un `domaine`.

## Décisions actées (brainstorming)
- Logo : **recréé en SVG**, direction « accent orange » (écusson bleu nuit, monogramme `ci` blanc,
  pistes de circuit orange). Source du logo Word extraite mais inexploitable (250×188 px, fond
  sombre) → on redessine proprement.
- Thème : **clair** (lisibilité terrain), chrome bleu nuit + accents/CTA orange. Mobile **et** web.
- Branches : **couleur + icône par branche** (option A). L'orange reste l'accent d'action global.
- Profondeur : **data-driven** — champ `domaine` sur `Task`, affiché partout.

## 1. Fondations de marque (design tokens)
Centralisés **une fois par plateforme**.

| Rôle | Hex |
|---|---|
| Bleu nuit (primary/chrome) | `#1A3C5E` (foncé `#13314D`, clair `#2D7D9A`) |
| Orange (accent/CTA) | `#E67E22` (tint `#FEF0E3`) |
| Page / surface | `#F4F6F9` / `#FFFFFF` |
| Texte / secondaire | `#13314D` / `#5F6B78` |

Branches (fond clair / texte foncé / icône Tabler) :
| Branche | Couleur | Fond | Texte | Icône |
|---|---|---|---|---|
| Électricité (& solaire) | ambre | `#FBF0D6` | `#854F0B` | `bolt` |
| Informatique (réseaux & vidéosurveillance) | bleu | `#E1F0FA` | `#0C447C` | `device-cctv` |
| Plomberie (sanitaire) | teal | `#E1F5EE` | `#0F6E56` | `droplet` |
| Autre | gris | `#F1EFE8` | `#444441` | `tools` |

- **Flutter** : `mobile/lib/theme/app_colors.dart` (constantes) + `app_theme.dart` (`ThemeData`
  Material 3 clair). L'ambre Électricité est volontairement plus doré que l'orange CTA pour éviter
  la confusion.
- **Web** : variables CSS de marque dans `web/src/app/globals.css` + exposition au thème Tailwind 4.

## 2. Logo & assets
- Logo recréé en **SVG**, deux formes :
  - **marque** (`logo_mark.svg`) : écusson seul → icône d'app, petites tailles.
  - **lockup** (`logo_lockup.svg`) : écusson + circuit + wordmark « Cameroon INNOVATION » → splash,
    en-têtes, page de connexion.
- Emplacement : `mobile/assets/brand/` (Flutter) et `web/public/brand/` (web). Un **PNG 1024×1024**
  dérivé de la marque pour le lanceur (`logo_mark_1024.png`).
- **Mobile** : icône via `flutter_launcher_icons`, splash via `flutter_native_splash` (deps + config
  ajoutées) ; marque affichée dans les AppBars et l'écran de connexion. **La génération
  icône/splash et le build APK se lancent depuis le terminal de l'utilisateur** (le contexte Claude
  ne build pas l'APK) — Claude fournit les assets + la config + valide par `flutter analyze`/`test`.
- **Web** : composant `Logo` (SVG) dans la `Sidebar` (remplace le texte) et la page de connexion.

## 3. Thème appliqué
- **Mobile** : `main.dart` consomme `AppTheme` (au lieu de `ThemeData(colorSchemeSeed: Colors.indigo)`).
  `colorScheme` dérivé du bleu nuit + orange ; `AppBar` bleu nuit, boutons/FAB orange. Les couleurs
  inline existantes (`Colors.indigo/orange/red`) sont remplacées par le thème / `AppColors` là où
  c'est du chrome ou de l'action.
- **Web** : Sidebar bleu nuit, boutons primaires orange, en-têtes de page accentués. On stylise le
  **chrome** (sidebar, en-têtes, CTA) avec les tokens de marque ; les gris neutres du corps de page
  restent. Pas de refonte fonctionnelle des pages.

## 4. Branches data-driven (champ `domaine`)
Enum partagé : `Électricité · Informatique · Plomberie · Autre`.

- **Mobile** (`mobile/lib/models/task.dart`) : `enum DomaineTrade { electricite, informatique,
  plomberie, autre }` + extension `wire`/`fromWire` ; `Task.domaine` (**nullable** pour le legacy) ;
  `toFirestore`/`fromMap` mis à jour. `TaskCreateScreen` : sélecteur de domaine (mise à jour du
  callback `onCreate` + câblage `firebase_auth_gate`). Puce de branche sur `tasks_list_screen` et
  `task_detail_screen`.
- **Web** (`web/src/lib/tasks.ts`) : `domaine?` ajouté à `TaskDoc`/`TaskRow` + `mapTaskDoc`. Puce de
  branche sur les cartes `board/page.tsx`, le détail `board/[taskId]/page.tsx`, et **nouvelle
  colonne « Domaine »** dans `tasks/page.tsx`. `stats/page.tsx` : **regroupement par branche**
  (heures + complétion), via des helpers purs (réutilise le style `*ByKey` de `stats.ts`).
- **Firestore** : **aucun changement de règles** — `domaine` est posé par le manager à la création
  (`tasks` create autorise des champs libres) et l'assigné ne peut modifier que `status`/`report`/
  `updatedAt` (diff borné). Confirmé dans `firebase/firestore.rules`.
- **Compat ascendante** : tâches existantes sans `domaine` → puce « Non précisé » (gris) ou masquée ;
  champ nullable, stats : regroupement « Non précisé ».

## 5. Composant puce de branche
Une seule source de vérité couleur/icône/libellé par plateforme :
- **Mobile** : widget `BranchChip(DomaineTrade?)` (icône + libellé + couleur de fond/texte).
- **Web** : composant `<BranchBadge domaine>` + helper pur `branchMeta(domaine) → {label, icon,
  bg, fg}` (testé).

## Tests
- **Mobile** : `flutter test` — round-trip `domaine` (`toFirestore`/`fromMap`), `TaskCreateScreen`
  expose le sélecteur et transmet `domaine`, `BranchChip` rend libellé/couleur par branche (dont
  le cas null → « Non précisé »). `flutter analyze` propre.
- **Web** : `npx jest` — `mapTaskDoc` mappe `domaine` (présent/absent), `branchMeta` (chaque branche
  + fallback), regroupement stats par branche. `npx tsc --noEmit`, `npx eslint .`, `npx next build`.
- Pas de tests émulateur/règles (aucun changement de règles). Génération icône/splash + APK = côté
  utilisateur.

## Hors périmètre (YAGNI)
- Refonte du **formulaire de rapport** (CI-F-003) → cycle 2 (réutilise `domaine`).
- **Thème sombre** (clair uniquement).
- Pages marketing/landing, écran « vitrine » dédié des branches (les branches apparaissent via les
  tâches et le thème).
- Migration des tâches existantes (champ nullable, dégradé propre).

## Déploiement & validation (côté utilisateur)
- **Web** : push `main` → auto-deploy Vercel ; valider le rendu sur Vercel.
- **Mobile** : `flutter pub run flutter_launcher_icons` + `flutter_native_splash:create`, puis build
  APK + validation appareil (icône, splash, thème, sélecteur de domaine, puces de branche).

## Conventions
- TDD côté logique pure (Dart + TS), commits atomiques en français (`feat/fix/chore(scope):`).
- Mobile validé par `flutter analyze`/`flutter test` (pas de build APK dans le contexte Claude) ;
  web par `jest`/`tsc`/`eslint`/`next build`.
