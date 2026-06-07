# Phase 2 — Tâches + rapports + notifications push (FCM)

**Date :** 2026-06-07
**Projet :** Cameroon Innovation — Pointage & gestion de tâches
**Statut :** Design validé, prêt pour le plan d'implémentation

## Objectif

Permettre aux managers de créer et assigner des tâches aux techniciens depuis le
mobile, aux techniciens de les exécuter et de produire un rapport (texte + photos +
temps passé) — **offline-first** côté exécution — et de notifier le technicien par
push (FCM) à l'assignation. Le backoffice web (direction) affiche les tâches en
**lecture seule** (suivi).

## Décisions de cadrage (brainstorming)

| Sujet | Décision |
|---|---|
| Surfaces | Mobile crée/assigne/exécute/rapporte ; web admin **lecture seule** |
| Offline | Technicien lit/exécute/rapporte hors-ligne (rejoué au retour réseau) ; manager crée **en ligne** (garantit un push immédiat) |
| Temps passé | **Saisie manuelle** par le technicien (découplé des pointages) |
| Site → pointage | Le pointage est rattaché à la tâche active → hérite du `siteId` (résout la dette hors-rayon) |
| Push | **Assignation → technicien uniquement** (sens unique) ; retours manager → Phase 3 |
| Statuts tâche | `assigned → in_progress → done` (rapport joint à la clôture) |
| Upload offline rapport | **Généraliser l'outbox Drift existant** (kind: punch \| report), migration schemaVersion 1→2 |

Hors périmètre (reportés) : board/alertes web complets, validation manager des
rapports, états `blocked`/`approved`, rappels d'échéance, push de retour vers le
manager — **Phase 3**. App Check, chemins Storage par user complets — **Phase 4**.

## Architecture

Trois briques disjointes (inchangé) : `mobile/` (Flutter), `web/` (Next.js, lecture
seule), `firebase/` (Firestore + Storage + Functions + FCM).

### 1. Modèle de données Firestore

**`tasks/{taskId}`** (nouveau)
```
title: string
description: string
siteId: string            // référence sites/{siteId}
assigneeId: string        // userId Clerk du technicien assigné
createdBy: string         // userId du manager (audit + push retour futur)
priority: 'low' | 'normal' | 'high'
dueAt: Timestamp | null   // échéance affichée (pas de rappel push cette phase)
status: 'assigned' | 'in_progress' | 'done'
createdAt: Timestamp      // serverTimestamp
updatedAt: Timestamp      // serverTimestamp
report: {                 // null tant que la tâche n'est pas clôturée
  text: string
  minutesSpent: number    // saisie manuelle
  photoUrls: string[]     // remplies progressivement par l'outbox (arrayUnion)
  photoCount: number      // nombre attendu (pour savoir si tout est monté)
  submittedAt: Timestamp
} | null
```

Le rapport est un **sous-objet du doc tâche** (pas une sous-collection) : un rapport
par tâche, lu/écrit toujours avec la tâche, taille bornée → un doc, une règle, une
écriture offline rejouable. Les photos vont dans Storage ; seules les URLs atterrissent
dans le doc.

**`punches/{punchId}`** — champ ajouté :
```
taskId: string | null     // tâche active choisie au pointage → fait hériter le siteId
```
Le `siteId` du punch est désormais renseigné depuis la tâche, ce qui rend
`isOutsideSite` (déjà présent côté web) exploitable.

**`users/{userId}`** — exploitation du champ déjà prévu `fcmTokens[]` (enregistré par
le mobile, nettoyé sur token invalide par la Function).

### 2. Mobile (Flutter / Riverpod, offline-first)

Unités à responsabilité unique, suivant les patterns Phase 1.

**Modèles** — `mobile/lib/models/task.dart` : `Task` + enums `TaskStatus`,
`TaskPriority`, sous-objet `TaskReport`, `toFirestore()` / `fromFirestore()` (miroir
de `punch.dart`).

**Tâches** — `mobile/lib/tasks/`
- `task_repository.dart` — streams (tâches assignées au tech ; tâches créées par le
  manager) + écritures (créer ; changer statut ; soumettre rapport). S'appuie sur le
  cache Firestore offline.
- `tasks_list_screen.dart` — liste role-gatée :
  - technicien → « Mes tâches » (`assigneeId == me`), groupées par statut ;
  - manager → « Tâches créées » + bouton **＋ Créer**.
- `task_detail_screen.dart` — détail + actions selon statut : *Démarrer*
  (`assigned→in_progress`), *Clôturer* (ouvre le formulaire rapport).
- `task_create_screen.dart` (manager, **en ligne**) — titre, description, sélection
  **site** (depuis `sites`), sélection **technicien** (depuis `users`, role=technician),
  priorité, échéance.
- `task_report_screen.dart` (technicien) — texte, minutes, photos multiples
  (`image_picker`) → écrit le statut `done` + `report` (avec `photoCount`) + enfile les
  photos dans l'outbox.

**Outbox généralisé** — `mobile/lib/outbox/`
- `outbox_db.dart` — `PendingPhotos` (clé `punchId`) → table générique
  `PendingUploads(id, kind, ownerId, localPath, attempts)` où `kind ∈ {punch, report}`
  et `ownerId` = punchId **ou** taskId. **Migration Drift schemaVersion 1→2.**
- `outbox_uploader.dart` — route selon `kind` :
  - `punch` → Storage `punches/{punchId}.jpg`, patche `photoUrl`/`photoStatus` (inchangé) ;
  - `report` → Storage `tasks/{taskId}/report/{uuid}.jpg`, **arrayUnion** sur
    `report.photoUrls`.
- `sync_controller.dart` — **inchangé** (un seul drain couvre les deux kinds ; le verrou
  anti-concurrence et les retries restent).

**Pointage** — `mobile/lib/pointage/pointage_screen.dart` : sélecteur de **tâche
active** (pré-sélection auto si une seule tâche `in_progress`, sinon liste) ; le `taskId`
+ le `siteId` hérité partent dans le punch.

**FCM** — `mobile/lib/notifications/fcm_service.dart` : demande la permission, récupère
le token, l'écrit dans `users/{me}.fcmTokens` (arrayUnion), rafraîchit sur rotation,
gère la réception foreground/background. Enregistré après le pont auth Firebase.

**Navigation** : point d'entrée role-gaté (techniciens : Pointage + Mes tâches ;
managers : Tâches créées + Créer), à partir du rôle déjà présent dans le custom claim
Firebase.

### 3. Cloud Functions (FCM)

`firebase/functions/src/tasks/onTaskAssigned.ts` — trigger Firestore v2
`onDocumentCreated('tasks/{taskId}')` :
1. lit `assigneeId`, charge `users/{assigneeId}.fcmTokens` ;
2. envoie un push multicast (titre = titre de tâche, corps = site + priorité, `data`
   = `{ taskId }` pour deep-link) ;
3. **nettoie les tokens invalides** (`messaging/registration-token-not-registered`
   → `arrayRemove`).

Exporté depuis `index.ts` à côté de `mintFirebaseToken`. Node 22, `firebase-functions`
v2. Pas de nouveau secret (Admin SDK déjà initialisé).

### 4. Règles de sécurité

**Firestore** (`firestore.rules`) — bloc `tasks/{taskId}` :
- `create` : `isManager()` **et** `request.resource.data.createdBy == auth.uid` ;
- `read` : `isManager()` **ou** `resource.data.assigneeId == auth.uid` ;
- `update` : soit `isManager()` (édition) ; soit l'assigné mais **borné** — il ne peut
  modifier que `status` (transitions `assigned→in_progress→done`), `report` et
  `updatedAt`, sans toucher `assigneeId`/`siteId`/`createdBy` (comparaison
  `request.resource.data` vs `resource.data`) ;
- `delete` : `false`.
- Punch `update` : l'ajout de `taskId`/`siteId` reste couvert par la règle owner-only
  existante.

**Storage** (`storage.rules`) — pièces jointes rapport :
- `tasks/{taskId}/report/{file}` : `write` si signé et assigné de la tâche (lecture du
  doc tâche via `firestore.get`) ; `read` si signé. Aligné sur le durcissement Phase 4
  (chemins par propriétaire).

### 5. Web (backoffice, lecture seule)

`web/src/app/(dashboard)/tasks/page.tsx` — table serveur (Firebase Admin) : titre,
site, assigné, statut, échéance, présence rapport. Réutilise `firebaseAdmin.ts` et le
pattern de `presence/page.tsx`. **Aucune écriture.** La **vue détail (rapport + photos)
est optionnelle** dans cette phase — peut glisser en Phase 3.

## Flux principaux

**Assignation (manager, en ligne)**
`task_create_screen` → `task_repository.create()` écrit `tasks/{id}` (status=assigned)
→ trigger `onTaskAssigned` → push multicast au technicien.

**Exécution (technicien, offline-first)**
Push/ouverture → `task_detail_screen` → *Démarrer* (`status=in_progress`, écriture
rejouable offline) → *Clôturer* → `task_report_screen` (texte + minutes + photos) écrit
`status=done` + `report` + enfile les photos dans l'outbox → `OutboxUploader` monte
chaque photo et fait un `arrayUnion` sur `report.photoUrls` au retour réseau.

**Pointage rattaché**
`pointage_screen` → sélection tâche active → punch hérite `taskId` + `siteId` → permet
le calcul hors-rayon côté web.

## Gestion des erreurs

- **Écritures offline** : déléguées au cache Firestore (rejeu auto) ; les photos de
  rapport passent par l'outbox (retries + `attempts`, verrou anti-concurrence existant).
- **Tokens FCM invalides** : nettoyés par la Function (`arrayRemove`).
- **Transitions de statut illégales** : refusées par les règles Firestore et gardées
  côté UI (boutons conditionnels au statut).
- **Manager hors-ligne au moment de créer** : la création est explicitement en ligne ;
  l'UI bloque/avertit si pas de réseau (le push dépend de la synchro immédiate).

## Stratégie de tests (TDD)

- **Mobile** : `task.dart` (sérialisation), `task_repository` (transitions de statut +
  garde-fous), outbox généralisé (routing punch vs report, **migration 1→2**),
  `fcm_service` (écriture token). `flutter test` + `flutter analyze`.
- **Functions** : `onTaskAssigned` (multicast appelé, nettoyage token invalide) —
  `npx jest`.
- **Règles** : émulateur Firestore (manager crée / tech borné à status+report / tech
  d'une autre tâche interdit) — `firebase emulators:exec --only firestore`.
- **Web** : rendu de la table tâches (jest), léger.
- **Validation appareil** : build APK depuis le terminal utilisateur (Claude ne build
  pas), parcours manager → technicien → push → rapport → web.

## Risques / points d'attention

- **Migration Drift 1→2** : à écrire et tester soigneusement (données outbox en cours ne
  doivent pas être perdues à la mise à jour de l'app).
- **Personnalisation du jeton Clerk** : le rôle doit remonter au pont
  (`{ "public_metadata": "{{user.public_metadata}}" }`) pour que la navigation role-gatée
  et les règles fonctionnent — déjà noté dans le HANDOFF, prérequis de cette phase.
- **Permissions notifications Android 13+** : `POST_NOTIFICATIONS` à demander à l'exécution.
```
