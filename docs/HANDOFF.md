# Session Handoff — Cameroon Innovation

**Date :** 2026-06-13 (dernière session)
**Frontière actuelle :** **Cycle #5 (managers = aussi techniciens) livré + mergé sur `main`
(`b338f01`) + Functions déployées**, et **backoffice déployé sur Vercel** (auto-deploy sur push
`main`). Détails : section « Cycle #5 » et « Backoffice déployé sur Vercel » plus bas + « Pour
reprendre ». Reste optionnel : confirmation Partie B sur appareil. Prochain : Phase 4 ou dette
« Sans site ». — Historique des phases précédentes ci-dessous.

**État global (historique) :** Phases 0 + 1 + 2 **terminées, déployées et validées de bout en bout
sur appareil réel**. Phase 2 mergée sur `main` ; règles + Storage + Functions déployées
(`onTaskAssigned` en prod) ; parcours manager→push→technicien→rapport→backoffice confirmé.
**Phase 3 (backoffice de suivi) : livrée + mergée sur `main`** (navigation sidebar,
résolution des noms, board lecture seule, stats période glissante) — **+ 3 correctifs
post-livraison mergés** (noms depuis Clerk, stats comptant les tâches sans échéance, filtre
de période sur Présence). Lecture seule, aucun changement de règles Firestore. Validée par
`npx jest` (47/47), `npx tsc --noEmit`, `npx eslint .`, `npx next build`. **À faire côté
toi :** déployer le backoffice sur **Vercel** (toujours non configuré côté Claude) ; `main`
local est en avance sur `origin/main` après push — vérifier le déclenchement Vercel.

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

## Phase 3 — livré + mergé sur `main`
Brainstorming + spec + plan + exécution complète (subagent-driven, 14 tâches, TDD), mergé,
puis 3 correctifs post-livraison (issus du test sur appareil) également mergés.
Spec : `docs/superpowers/specs/2026-06-07-phase-3-suivi-backoffice-design.md`.
Plan : `docs/superpowers/plans/2026-06-07-phase-3-suivi-backoffice.md`.

- **Logique pure (testée jest)** : `web/src/lib/directory.ts` (`clerkDisplayName` + résolution
  noms), `web/src/lib/board.ts` (`groupByStatus`, `isLate`), `web/src/lib/stats.ts`
  (`parsePeriod`, `hoursPerTechnician`, `completionByKey`, `lateCountByKey`, `hoursPerSite`).
- **Coquille** : `web/src/components/Sidebar.tsx` (nav, lien actif) + `web/src/app/(dashboard)/layout.tsx`
  (role gate **centralisé** — retiré des pages individuelles).
- **Pages** : `(dashboard)/board/page.tsx` (3 colonnes par statut, retards en rouge,
  filtres site/technicien — **lecture seule**), `(dashboard)/stats/page.tsx` (période
  today/7d/30d ; heures + complétion + retards + anomalies par technicien et par site).
- **Refactor** : `presence` (noms + **sélecteur de période**) et `tasks` (noms) délèguent le
  gate au layout.
- **Correctifs post-livraison** :
  1. **Noms depuis Clerk** — les docs Firestore `users` n'ont pas toujours de champ `name`
     (profil Clerk sans prénom/nom) ; `loadDirectory` lit le nom via `clerkClient`
     (`clerkDisplayName` : prénom+nom → username → email → id). Affichait l'uid brut avant.
  2. **Stats comptent les tâches sans échéance** — `completionByKey` rattache une tâche par
     `dueAt`, ou par `createdAt` à défaut (sinon une tâche sans échéance était invisible).
  3. **Filtre de période sur Présence** (aujourd'hui/7j/30j) — prévu par la spec, manquait.
- **Tests** : `npx jest` **47/47** ; `npx tsc --noEmit` propre ; `npx eslint .` propre ;
  `npx next build` OK (routes `/board` et `/stats`).
- **Observation données** : les `punches` peuvent avoir `siteId=null` (pointage sans tâche
  active → pas d'héritage du site) → ligne « Sans site » dans les stats. Vrai correctif =
  cycle #5 (rattacher le pointage à une tâche côté mobile).

### Reste à faire côté toi (Phase 3)
1. Déployer le backoffice sur **Vercel** (toujours non configuré côté Claude).

### Reporté aux cycles suivants
- **Cycle #4** — ✅ livré + déployé + validé sur appareil (voir section dédiée ci-dessous).
- **Cycle #5 — dette mobile « managers = aussi techniciens »** : laisser un manager pointer
  et s'auto-assigner des tâches (revoir `HomeShell` + écran de création côté Flutter).
- **Dette cosmétique notée à la revue** : `<main>` imbriqué (root layout + pages), liens
  période en `<a>` plutôt que `<Link>` — sans impact fonctionnel.

## Cycle #4 — boucle manager (validation) : livré + déployé + validé sur appareil ✅
Spec : `docs/superpowers/specs/2026-06-07-cycle-4-boucle-manager-design.md`.
Plan : `docs/superpowers/plans/2026-06-07-cycle-4-boucle-manager.md`.
Mergé sur `main` (merge `--no-ff` `ea7f3db`), poussé sur `origin/main`.

- **Functions** : `onTaskUpdated.ts` — un trigger `onDocumentUpdated('tasks/{taskId}')` route
  deux push (→done : au createdBy/manager ; →approved : à l'assigneeId/technicien), réutilise
  `splitInvalidTokens`. Tests jest verts.
- **Règles** : l'assigné ne peut poser `status` que dans {in_progress, done} ; `approved`
  réservé au manager ; un patch qui laisse le statut inchangé reste autorisé (sinon l'upload
  photo offline différé après validation casse). **Tests de règles 15/15 verts via émulateur.**
- **Web** : `mapTaskDoc` étendu (détail rapport + approvedBy/approvedAt) ; garde pure
  `canApprove` ; Server Action `approveTask` (re-check rôle serveur + transaction garde
  `status==='done'`) ; route détail `(dashboard)/board/[taskId]` (rapport + photos + Valider) ;
  cartes board cliquables + badges « à valider » / « ✓ validé ». `jest`/`tsc`/`eslint`/`next build` OK.
- **Mobile** : `TaskStatus.approved` en lecture seule (libellé « validé », aucune action).

### Déploiement & validation — faits le 2026-06-09
1. ✅ `firebase deploy --only "firestore:rules,functions"` — règles en prod + `onTaskUpdated`
   **créé** en prod (`onTaskAssigned`/`mintFirebaseToken` mis à jour). ⚠ quoter la virgule du
   `--only` (sinon PowerShell ne déploie que le 1er élément — bug rencontré et corrigé).
2. ✅ Tests de règles émulateur : **15/15 verts** (`firebase emulators:exec --only firestore
   "cd functions && npx jest rules"`).
3. ✅ Backoffice à jour (Vercel) + validé.
4. ✅ **Boucle complète validée de bout en bout sur appareil (tablette SM X115)** : technicien
   clôture → manager reçoit le push → détail backoffice → Valider → technicien reçoit le push.

## Cycle #5 — managers = aussi techniciens : livré + mergé + déployé ✅
Spec : `docs/superpowers/specs/2026-06-09-cycle-5-managers-aussi-techniciens-design.md`.
Plan : `docs/superpowers/plans/2026-06-09-cycle-5-managers-aussi-techniciens.md`.
**Mergé sur `main`** (merge `--no-ff` `b338f01`, poussé sur `origin/main`) ; **Functions déployées
en prod** ; manager 3 onglets **validé sur tablette** (technicien 2 onglets confirmé).
Approche A (chirurgicale). **Aucun changement de règles ni de modèle de données.**

- **Mobile** :
  - `HomeShell` : un manager cumule désormais 3 onglets (Pointage + Mes tâches + Tâches créées) ;
    technicien inchangé. (`088a39c`)
  - `TaskCreateScreen` : paramètre optionnel `self` → entrée « Moi (vous) » en tête du sélecteur
    d'assigné ; défaut = 1er technicien sinon soi ; soumission possible même sans technicien si
    `self` fourni. (`d21dc9c`)
  - Câblage `firebase_auth_gate` : `_openCreate` passe `self: (id: uid, name: 'Moi (vous)')`. (`8746bdf7`)
- **Functions (garde-fou anti-push-perso, `assigneeId == createdBy`)** :
  - `onTaskAssigned` : prédicat pur `shouldNotifyAssignment` → pas de push « Nouvelle tâche »
    en auto-assignation. (`1cf306d`)
  - `routeStatusChange` : pas de push « à valider » vers soi ; le push « validée » est **conservé**
    (informe le manager-exécutant). (`2608b07`)
- **Règles** : 2 tests documentaires d'auto-assignation ajoutés (création + démarrage par un
  manager-assigné). `tsc` propre. (`40b5ca2`)

### État des tests (Cycle #5)
- **Mobile** : `flutter analyze` propre + **43/43** verts (dont 2 nouveaux d'auto-assignation).
- **Functions (unitaires)** : **20/20** verts (`npx jest --testPathIgnorePatterns=rules`).
- **Règles** : **non exécutées ici** (émulateur Firestore bloqué sur ce poste, dette socket
  Java 17). À lancer dans ton terminal : `cd firebase && firebase emulators:exec --only
  firestore "cd functions && npx jest rules"` → **attendu 17/17** (15 + 2 nouveaux).

## Backoffice déployé sur Vercel ✅
Projet Vercel `ciw-tech`, **intégration Git** : push sur `main` → déploiement **production** auto ;
autres branches/PR → **preview**. Pièges réglés à la mise en place : Root Directory = **`web`**
(monorepo), framework = **Next.js** (créé en « Other » au départ), **5 variables d'env**
(Clerk + Firebase) en Production+Preview. ⚠ `FIREBASE_PRIVATE_KEY` : coller **sans guillemets**,
garder les `\n` littéraux (sinon `cert()` échoue → erreur Server Component après login). ⚠ Variables
manquantes → middleware Clerk jette → `MIDDLEWARE_INVOCATION_FAILED`. Détails : mémoire
`web-vercel-deploiement`. Note : `next dev` (Turbopack, Next 16) **crashe** sur `board/[taskId]` en
**local** ; `next build` + prod Vercel OK → valider la page détail sur Vercel, pas en dev local.

## Pour reprendre
1. Lire `CLAUDE.md` + ce fichier. **Cycle #5 est mergé sur `main` et déployé** ; backoffice en ligne
   sur Vercel (auto-deploy sur push `main`).
2. **Reste optionnel côté toi** :
   - Confirmation Partie B sur tablette SM X115 : un manager qui s'auto-assigne une tâche ne reçoit
     **aucun push perso** (« Nouvelle tâche » / « à valider ») ; le push « validée » arrive bien.
   - Tests de règles émulateur si tu veux les cocher : `cd firebase && firebase emulators:exec
     --only firestore "cd functions && npx jest rules"` → 17/17 attendu.
3. **Clerk** : instance **développement** (`pk_test_…`). Passage en prod = créer l'instance Clerk
   production + **réappliquer** la personnalisation du token de session
   (`{ "public_metadata": "{{user.public_metadata}}" }`), sinon le rôle mobile retombe sur technicien.
4. Chantier suivant : **Phase 4** (durcissement : App Check, anomalies, chemins Storage par user,
   Play Store), ou la dette « Sans site » des stats (rattacher tout pointage à un site/tâche).
