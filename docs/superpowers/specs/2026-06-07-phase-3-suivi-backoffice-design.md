# Phase 3 — Backoffice de suivi (board, alertes retard, stats)

**Date :** 2026-06-07
**Statut :** Design validé (brainstorming) — prêt pour plan d'implémentation
**Brique :** `web/` (Next.js 16 App Router, Vercel, réservé direction)

## Objectif

Donner à la direction un backoffice de **suivi** réellement exploitable : visualiser
l'avancement des tâches (board par statut, retards mis en évidence) et contrôler le
travail (statistiques heures / complétion / retards par technicien et par site).
Aujourd'hui le backoffice affiche des **IDs bruts** et n'a **aucune navigation** entre
ses pages — ce cycle corrige cela.

## Périmètre

### Dans ce cycle
- **Coquille de navigation** : barre latérale (sidebar) à gauche, enveloppant toutes les
  pages du dashboard ; lien actif surligné.
- **Résolution des noms** (transverse) : `uid → nom technicien`, `siteId → nom site`,
  avec repli sur l'ID si le nom manque.
- **Board des tâches** (lecture seule) : 3 colonnes par statut (À faire / En cours /
  Terminé), tâches en retard mises en évidence, filtre par site et par technicien.
- **Stats & présence** : période glissante (aujourd'hui / 7 derniers jours / 30 derniers
  jours). Cœur = heures pointées, taux de complétion des tâches, tâches en retard
  (par technicien et par site). Bonus si peu coûteux = anomalies de pointage,
  activité par site (heures + nb de tâches).
- **Style** : Tailwind (déjà installé) pour les nouvelles pages ; alignement léger des
  pages existantes (`presence`, `tasks`).

### Hors de ce cycle (reporté)
- **Écriture / validation manager** (`done → approved`, board interactif drag-drop, push
  retour à la soumission de rapport) → cycle #4. **Conséquence : aucune écriture
  Firestore, aucun changement de `firestore.rules` dans cette phase.**
- **Dette mobile** « managers = aussi techniciens » (pointage + auto-assignation) → cycle #5.

## Décisions d'architecture

- **Board en lecture seule.** La source de vérité du statut reste le terrain (technicien).
  Le board *reflète* l'état réel, il ne le force pas. Cela évite d'ouvrir l'écriture
  backoffice et une revue de sécurité des règles dans ce cycle.
- **Role gate centralisé.** Le contrôle d'accès (`canAccessBackoffice`) est aujourd'hui
  dupliqué dans chaque page ; on le remonte dans `(dashboard)/layout.tsx`.
- **Filtres et période via `searchParams`** (pas de JavaScript client) : le board et les
  stats restent des Server Components ; les filtres (`?site=`, `?tech=`) et la période
  (`?period=today|7d|30d`) passent par l'URL.
- **Agrégation en mémoire.** Pour les stats, on charge tous les `tasks` + les `punches`
  de la plage, puis on calcule tout en mémoire — évite les index composites Firestore à
  cette échelle.

> ⚠️ **Next.js 16** : APIs et conventions peuvent différer (cf. `web/AGENTS.md`). Lire la
> doc dans `node_modules/next/dist/docs/` avant de coder (notamment `searchParams` /
> `layout` / Server Components).

## Fichiers

### Nouveaux
- `web/src/app/(dashboard)/layout.tsx` — coquille sidebar + role gate centralisé.
- `web/src/components/Sidebar.tsx` — liens de navigation (Présence / Tâches / Board /
  Stats / Sites), lien actif surligné.
- `web/src/lib/directory.ts` — `loadDirectory(db)` → `{ users: Map, sites: Map }` : **noms
  d'utilisateurs résolus depuis Clerk** (source d'identité — `clerkDisplayName` = prénom+nom
  → username → email → id), sites depuis Firestore. `displayUser(uid, dir)` /
  `displaySite(id, dir)` (« Sans site » si pas de `siteId`, repli sur l'ID sinon).
  `clerkDisplayName` + helpers d'affichage **purs, testables** (import dynamique de
  `clerkClient` pour garder le module testable en env node).
  > Décision révisée après livraison : les docs Firestore `users` n'ont pas toujours de champ
  > `name` (profil Clerk sans prénom/nom → `mintFirebaseToken` l'omet). Lire le nom depuis
  > Clerk est robuste et aligné sur « Clerk = source d'identité ».
- `web/src/lib/board.ts` — `groupByStatus(tasks)` → colonnes ; `isLate(task, now)`.
  **Purs, testables.**
- `web/src/app/(dashboard)/board/page.tsx` — Server Component : charge `tasks` + directory,
  groupe par statut, applique les filtres (`searchParams`), rend les colonnes.
- `web/src/lib/stats.ts` — agrégation pure : `(punches, tasks, period) →` métriques par
  technicien et par site. Réutilise `computeWorkedMinutes` de `lib/hours.ts`.
- `web/src/app/(dashboard)/stats/page.tsx` — Server Component : période via `searchParams`
  (défaut 7 j), charge données, agrège, rend.

### Modifiés
- `web/src/app/(dashboard)/presence/page.tsx` — noms résolus (au lieu de l'`uid`),
  **sélecteur de période (aujourd'hui / 7 j / 30 j, défaut aujourd'hui)** calculant les heures
  sur la période choisie, suppression du role gate dupliqué (désormais dans le layout),
  habillage Tailwind léger.
- `web/src/app/(dashboard)/tasks/page.tsx` — noms résolus (site + assigné), suppression du
  role gate dupliqué, habillage Tailwind léger.

## Flux de données

### Board (`/board`)
1. Server Component, `force-dynamic`.
2. Charge `tasks` (`orderBy('createdAt', 'desc')`) + `loadDirectory(db)`.
3. Filtres depuis l'URL (`?site=`, `?tech=`) appliqués côté serveur.
4. `groupByStatus(filteredTasks)` → 3 colonnes.
5. Rendu : carte = titre + technicien (nom) + site (nom) + échéance + état rapport.
   Retard (`isLate`) = liseré rouge + badge ⚠. Terminé = ✓ rapport remis.

### Stats (`/stats`)
1. Server Component, `force-dynamic`.
2. Période depuis `searchParams` (`today|7d|30d`, défaut `7d`) → plage `[start, end]`.
3. Charge tous les `tasks` + les `punches` où `clientTimestamp >= start`.
4. `stats.ts` calcule en mémoire :
   - **Heures pointées** par technicien (via `computeWorkedMinutes`).
   - **Anomalies** par technicien (bonus, déjà détecté par `computeWorkedMinutes`).
   - **Taux de complétion** = tâches `done` / tâches **rattachées à la période** (par `dueAt`
     si présent, sinon par `createdAt`), par technicien et par site.
   - **Tâches en retard** = `dueAt < now` ET statut ∈ {assigned, in_progress},
     comptées par technicien et par site (point-dans-le-temps, indépendant de la période).
   - **Activité par site** (bonus) = heures pointées + nb de tâches, agrégées par site.
5. Rendu : tableaux/cartes par technicien et par site, noms résolus.

## Définitions

- **En retard** : `dueAt < maintenant` ET statut ∈ {`assigned`, `in_progress`}
  (une tâche `done` n'est jamais « en retard »).
- **Taux de complétion sur la période** : numérateur = tâches `done` rattachées à la période ;
  dénominateur = toutes les tâches rattachées à la période. **Rattachement** : par l'échéance
  `dueAt` si la tâche en a une, sinon par sa date de création `createdAt` (correctif
  post-livraison — sans quoi une tâche sans échéance était invisible dans les stats).
- **Statuts de tâche** : `assigned`, `in_progress`, `done` (le futur `approved` relève du
  cycle #4 ; s'il apparaît, il est traité comme « terminé » à l'affichage).

## Gestion des erreurs / cas limites

- Nom manquant (technicien inactif, site supprimé) → repli sur l'ID, jamais de crash.
- États vides explicites : « Aucune tâche », « Aucun pointage sur la période ».
- Accès refusé : UI existante conservée, centralisée dans `(dashboard)/layout.tsx`.

## Tests (TDD — rouge → vert → commit)

- `lib/board.ts` : `groupByStatus` (répartition correcte, statut inconnu), `isLate`
  (limites : échéance future, passée, tâche `done`).
- `lib/stats.ts` : agrégation par technicien et par site, taux de complétion, comptage des
  retards, filtrage par période ; réutilise/valide `computeWorkedMinutes`.
- `lib/directory.ts` : `displayUser` / `displaySite` (nom présent, repli sur l'ID).
- Les **12 tests web existants restent verts** ; `npx next build` doit passer
  (nouvelles routes `/board` et `/stats`).
- **Pas d'émulateur Firestore nécessaire** (aucun changement de règles, lecture seule).

## Critères de réussite

1. Une barre latérale permet de naviguer entre Présence / Tâches / Board / Stats / Sites.
2. Le board affiche les tâches en 3 colonnes avec **noms** (pas d'IDs), retards en évidence,
   filtrables par site et technicien.
3. La page Stats affiche, pour une période choisie, heures pointées + taux de complétion +
   retards par technicien et par site, avec noms.
4. `presence` et `tasks` affichent des noms et partagent le role gate du layout.
5. `flutter`/mobile **inchangés** ; `npx jest` et `npx next build` verts.
