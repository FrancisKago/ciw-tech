# Session Handoff — Cameroon Innovation

**Date :** 2026-06-07
**État global :** Phases 0 + 1 + 2 **terminées, déployées et validées de bout en bout
sur appareil réel**. Phase 2 mergée sur `main` ; règles + Storage + Functions déployées
(`onTaskAssigned` en prod) ; parcours manager→push→technicien→rapport→backoffice confirmé.
Suite logique : Phase 3 (board, alertes, stats + dette « managers = aussi techniciens »).

## Phase 2 — ce qui a été livré (code)
Plan exécuté : `docs/superpowers/plans/2026-06-07-phase-2-taches-rapports-push.md`
(design : `docs/superpowers/specs/2026-06-07-phase-2-taches-rapports-push-design.md`).

- **Firebase**
  - `firestore.rules` : collection `tasks` (create manager+createdBy, read manager|assigné,
    update borné pour l'assigné à `status`/`report`/`updatedAt`, delete interdit).
  - `storage.rules` : `tasks/{taskId}/report/{file}` (write réservé à l'assigné via
    `firestore.get`, read signé). Syntaxe validée par `firebase deploy --only storage --dry-run`.
  - `functions/src/tasks/onTaskAssigned.ts` : trigger `onDocumentCreated('tasks/{taskId}')`
    → push FCM multicast au technicien + purge des tokens invalides. Helpers purs testés (jest).
- **Mobile (Flutter)**
  - `models/task.dart` (Task/TaskReport/TaskStatus/TaskPriority) ; `Punch.taskId` ajouté.
  - Outbox Drift **généralisé** : table `PendingUploads(kind: punch|report)`, **migration
    schemaVersion 1→2** (étapes SQL exposées + testées) ; `OutboxUploader` route punch/report.
  - `tasks/task_repository.dart` (créer, start, submitReport offline, streams par rôle).
  - `notifications/fcm_service.dart` (enregistrement token, arrayUnion idempotent).
  - Écrans : `home_shell` (navigation role-gatée), `tasks_list`, `task_detail`,
    `task_report`, `task_create` (garde « en ligne »).
  - Pointage rattaché à la **tâche active** → hérite du `siteId` (résout la dette hors-rayon).
  - Câblage : rôle lu via `getIdTokenResult`, FCM démarré après le pont auth, navigation
    branchée (`firebase_auth_gate.dart`, `main.dart`).
  - Permission Android `POST_NOTIFICATIONS`.
- **Web (lecture seule)** : `src/app/(dashboard)/tasks/page.tsx` (table serveur Firebase
  Admin, role-gatée comme `presence`, aucune écriture) + `src/lib/tasks.ts` (`mapTaskDoc`).

## État des tests
- **Mobile** : `flutter analyze` propre, `flutter test` **38/38 vert**.
- **Functions (unitaires)** : `npx jest` **6/6** (onTaskAssigned, mintFirebaseToken, clerkVerify).
- **Web** : `npx jest` **12/12** ; `npx next build` OK (route `/tasks`).
- **Règles Firestore** : tests écrits (`functions/test/rules.test.ts`) mais **non exécutés
  ici** — l'émulateur Firestore ne démarre pas sur ce poste (dette socket Netty/Java 17,
  cf. `docs/SETUP.md`). **À lancer dans ton terminal** :
  `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`.

## Reste à faire côté toi (Tâche 18 du plan)
1. **Relire/merger la branche** `phase-2-taches-rapports-push` sur `main`.
2. **Tests de règles** via l'émulateur (commande ci-dessus).
3. **Déployer** : `cd firebase && firebase deploy --only firestore:rules,storage,functions`
   (vérifier que `onTaskAssigned` apparaît dans la liste des fonctions).
4. **Prérequis push** : le jeton de session Clerk doit exposer
   `{ "public_metadata": "{{user.public_metadata}}" }` pour que le rôle remonte au pont
   (sinon navigation role-gatée → `technician` par défaut).
5. **Build/validation appareil** depuis ton terminal (Claude ne peut pas builder l'APK) :
   ```
   cd "D:\App pointage\mobile"
   flutter run -d <device> --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...
   ```
   Parcours : compte manager crée une tâche (en ligne) → le technicien reçoit le push →
   *Démarrer* → pointe en sélectionnant la tâche (siteId hérité) → *Clôturer* avec rapport
   + photos → photos montées au retour réseau (`report.photoUrls`) → tâche + rapport
   visibles au backoffice web.

## Dette / notes connues
- `mobile/lib/outbox/outbox_db.g.dart` est **maintenu à la main** (build_runner inopérant
  sur Dart 3.10 ici : `'dart compile' does not support build hooks`). Prouvé correct par
  les tests Drift. Si tu disposes d'un poste où build_runner tourne, une régénération
  canonique est possible (devrait être un no-op).
- App Check (Phase 4) toujours non configuré.
- Chemins Storage par user pour les pointages (`punches/{userId}/...`) : Phase 4.
- **Correctif post-déploiement** : l'écran « Tâches » (manager) n'avait pas de bouton de
  déconnexion → manager bloqué sans sortie. Ajout d'une action déconnexion (icône logout
  dans l'AppBar) sur `TasksListScreen`, câblée pour les deux rôles (commit `017cb48`).
- **Dette produit (Phase 3) — managers = aussi des techniciens** : aujourd'hui la
  navigation est cloisonnée par rôle (`HomeShell` : manager → uniquement « Tâches créées » ;
  technicien → Pointage + Mes tâches). Or un manager est aussi un technicien de terrain.
  À faire plus tard : permettre au manager de **pointer** (accès à l'onglet Pointage) et de
  **s'auto-assigner des tâches** (s'inclure dans la liste des assignés à la création, et voir
  ses propres tâches assignées). Implique de revoir `HomeShell` (onglets cumulés pour un
  manager : Pointage + Mes tâches + Tâches créées) et l'écran de création (autoriser
  `assigneeId == self`).
- **Optimisation (Phase 3)** : `firebase_auth_gate` ouvre deux listeners Firestore sur
  `tasksForAssignee(uid)` (onglet pointage + onglet « Mes tâches »). Coût négligeable à
  cette échelle ; à mutualiser (un seul stream broadcast) lors du refactor board Phase 3.
- **Revue de code** : la revue finale avait signalé un risque de perte des champs frères du
  rapport ; vérifié **faux positif** (`set(merge:true)` deep-merge les maps). Verrouillé par
  un test de non-régression. Correctifs réels appliqués : mémoïsation du rôle, cycle de vie
  de la souscription FCM, garde `assigneeId` dans la Function.

## Phase 3 (suite) — amorce
Suivi backoffice complet : board des tâches (drag statut), alertes retard (échéances),
stats par technicien/site, et boucle de retour manager (push à la soumission de rapport,
validation `done → approved`). Voir le périmètre reporté dans le design Phase 2.

## Pour reprendre
1. Lire `CLAUDE.md` + ce fichier. 2. `git checkout phase-2-taches-rapports-push`.
3. Dérouler « Reste à faire côté toi » ci-dessus.
