# Cameroon Innovation — Pointage & gestion de tâches

Mémoire projet pour Claude Code. Lire ce fichier en début de session.

## Objectif
Contrôler les heures de techniciens déployés sur des sites changeants, et piloter
les tâches qui leur sont confiées. **Pointage = GPS + photo obligatoires**,
**offline-first** (souvent hors ligne, synchro dès retour réseau). Backoffice
réservé à la direction.

## Architecture (3 briques, dossiers disjoints)
- `mobile/` — app **Flutter (Android only)**, offline-first, Riverpod. Techniciens + managers.
- `web/`   — backoffice **Next.js 16 (App Router)** sur Vercel, direction uniquement.
- `firebase/` — **Firestore + Storage + Cloud Functions (TS) + FCM**, règles de sécurité.

**Auth** : **Clerk** = source d'identité (web + mobile). Sur mobile, un pont échange
le JWT Clerk contre un jeton Firebase personnalisé via la Cloud Function
`mintFirebaseToken` (qui pose le rôle en custom claim). Web : `@clerk/nextjs` +
Firebase Admin SDK côté serveur.

**Rôles** (`publicMetadata.role` dans Clerk) : `admin` (direction, tous droits),
`manager` (crée/assigne les tâches), `technician` (pointe, exécute, rapporte).

## Flux pointage
`PointageScreen` → GPS (`geolocator`) + photo (`image_picker`) → `PunchRepository`
écrit le doc Firestore `punches/{id}` (cache offline auto) + range la photo dans
l'**outbox Drift** local → `OutboxUploader` envoie la photo vers Storage
(`punches/{punchId}.jpg`) et patche le doc (`photoStatus: uploaded`).
`SyncController` déclenche la vidange : au démarrage + à chaque retour réseau +
périodiquement (20 s) + après chaque pointage. Vidanges fusionnées (verrou anti-concurrence).

## Données Firestore
- `users/{userId}` (userId = id Clerk) : name, phone, role, active, fcmTokens[]
- `sites/{siteId}` : name, geo{lat,lng}, radiusMeters
- `punches/{punchId}` : userId, kind(in/out), clientTimestamp, serverTimestamp, geo{lat,lng,accuracy}, photoUrl, photoStatus, siteId
- `tasks/{taskId}` : title, description, siteId, assigneeId, createdBy, priority, dueAt,
  status(assigned/in_progress/done/approved), report{...}, approvedBy, approvedAt, updatedAt

## Versions épinglées (ne pas « mettre à jour » sans raison)
- `flutter_riverpod: ^2.5.0` (3.x casse avec drift_dev via test_api)
- `drift`/`drift_dev: >=2.28 <2.32` + `sqlite3_flutter_libs: ^0.5.0` (≥ ces versions = hooks natifs `build.dart` qui cassent build_runner sur Dart 3.10)
- `clerk_flutter: 0.0.14-beta` + `dependency_overrides: clerk_auth: 0.0.14-beta` (tandem ; 0.0.15-beta publié sans ses fichiers l10n générés ; 0.0.14 seul est incompatible avec clerk_auth 0.0.15)
- Cloud Functions : Node 22, `firebase-functions` v2 ; `mintFirebaseToken` lie le secret `CLERK_SECRET_KEY` (`defineSecret`).

## Commandes
- Mobile : `cd mobile && flutter test` / `flutter analyze` / `flutter run -d <device> --dart-define=CLERK_PUBLISHABLE_KEY=pk_...`
- Web : `cd web && npx jest` / `npx next build` / `npm run dev`
- Functions : `cd firebase/functions && npx jest` ; règles : `firebase emulators:exec --only firestore "cd functions && npx jest rules"`
- Déploiement : `cd firebase && firebase deploy --only firestore:rules,storage,functions`

## Gotchas environnement (ce poste)
- **Build Android** : se lance UNIQUEMENT depuis le terminal de l'utilisateur (le contexte d'exécution de Claude bloque les connexions loopback dont Gradle a besoin). Claude valide via `flutter analyze` + `flutter test`, pas via le build APK.
- **Émulateur Firestore + Java 17** : nécessite un contournement de SelectorProvider (voir docs/SETUP.md) sinon erreur de socket.
- Projet sur `D:`, cache pub sur `C:` → `kotlin.incremental=false` dans `android/gradle.properties`.
- Mise en service complète (comptes/IAM/clés) : **docs/SETUP.md** (à suivre pour toute réinstallation).

## Conventions
- TDD : test rouge → vert → commit. Commits atomiques, messages en français, `feat/fix/chore/docs(scope):`.
- Identité git : `Cameroon Innovation <camerooninnovation58@gmail.com>`.
- Plans/specs : `docs/superpowers/`. Chaque phase = brainstorming → plan → exécution.

## Statut
- **Phase 0 (fondations + pont auth)** : ✅ fait + déployé + validé sur appareil.
- **Phase 1 (pointage offline-first)** : ✅ fait + validé de bout en bout (tablette → backoffice).
- **Phase 2 (tâches + rapports + push FCM)** : ✅ fait + déployé + **validé de bout en bout sur appareil**
  (manager crée → push FCM → technicien démarre → rapport+photos → backoffice). Inclut : création de
  site au backoffice (`/sites`), `mintFirebaseToken` enregistre name+phone, sélecteur de tâche au
  pointage (siteId hérité). Règles testées via émulateur (11/11). Backoffice web mergé sur `main`
  (déployer sur Vercel si pas déjà fait).
- **Phase 3 (suivi backoffice : board, alertes retard, stats)** : ✅ livré (code) + mergé sur `main`.
  Navigation sidebar, résolution des noms (uid/siteId → noms), board lecture seule (3 colonnes par
  statut + retards + filtres site/technicien), stats période glissante (today/7d/30d ; heures +
  complétion + retards par technicien et par site). **Lecture seule, aucun changement de règles.**
  Tests 39/39, `tsc`/`eslint`/`next build` OK. **Reste côté user : déployer sur Vercel.** Reporté :
  cycle #4 (boucle manager : écriture statut, `done → approved`, push retour → ouvre l'écriture
  backoffice + revue des règles) et cycle #5 (dette mobile « managers = aussi techniciens »).
- **Cycle #4 (boucle manager : validation)** : ✅ livré + déployé + **validé de bout en bout
  sur appareil** (tablette SM X115). Backoffice : vue détail de tâche (rapport + photos) +
  bouton Valider (Server Action, `done → approved`). Cloud Function `onTaskUpdated` (push
  technicien→manager à la soumission, manager→technicien à la validation) **créée en prod**.
  Règles durcies (l'assigné ne peut plus poser `approved` ; patch rapport autorisé si statut
  inchangé) — **tests de règles 15/15 verts (émulateur)**. Mergé+poussé sur `main`.
- **Cycle #5 (managers = aussi techniciens)** : ✅ livré + mergé sur `main` (merge `--no-ff`
  `b338f01`) + Functions déployées en prod. Mobile : `HomeShell` cumule 3 onglets pour un
  manager (Pointage + Mes tâches + Tâches créées) — **validé sur tablette** (manager 3 onglets,
  technicien 2 onglets) ; `TaskCreateScreen` propose l'auto-assignation (option « Moi (vous) »).
  Functions : garde-fou anti-push-perso quand `assigneeId == createdBy` (pas de push « Nouvelle
  tâche » ni « à valider » vers soi ; push « validée » conservé) — **déployé**. **Aucun changement
  de règles ni de modèle.** Tests : mobile 43/43 + analyze propre, Functions unitaires 20/20 ;
  règles 2 tests documentaires (émulateur côté user → attendu 17/17). Reste optionnel côté user :
  confirmation Partie B sur appareil (aucun push perso).
- **Backoffice déployé sur Vercel** : projet `ciw-tech`, intégration Git (auto-deploy sur push
  `main`, previews sur les autres branches). Root Directory `web`, framework Next.js, 5 variables
  d'env (Clerk + Firebase). ⚠ `FIREBASE_PRIVATE_KEY` : coller sans guillemets, garder les `\n`.
  ⚠ instance Clerk **développement** (`pk_test_…`) — passer en prod = réappliquer la
  personnalisation du token de session (`{ "public_metadata": "{{user.public_metadata}}" }`).
- **Phase 4 (durcissement)** — décomposée en 4 chantiers indépendants (chacun son cycle spec→plan→exec) :
  - **Détection d'anomalies de pointage** : ✅ livré (code) + mergé sur `main` (merge `--no-ff`).
    Librairie pure `web/src/lib/anomalies.ts` (`detectAnomalies` : hors-rayon tolérant via
    `geo.ts:distanceMeters`, GPS imprécis >100 m, photo manquante grâce 24 h, sans-site, doublon
    <5 min même technicien+kind, horloge asymétrique client>serveur >10 min) + page backoffice
    `/alertes` (lecture seule, filtres site/technicien/période en formulaire GET, heure en
    Africa/Douala, tri alertes d'abord). `directory.ts` expose désormais geo+radiusMeters des sites.
    **Aucun changement de règles/Function/mobile.** Tests `npx jest` **74/74**, `tsc`/`eslint`/
    `next build` OK. Spec : `docs/superpowers/specs/2026-06-13-phase-4-detection-anomalies-design.md`,
    plan : `docs/superpowers/plans/2026-06-13-phase-4-detection-anomalies.md`. **Reste côté user :
    rien (auto-deploy Vercel sur push `main`) ; valider la page `/alertes` sur Vercel.**
  - **Chemins Storage par utilisateur** : ✅ livré (code) + mergé sur `main` (merge `--no-ff`).
    Photos de pointage : `punches/{punchId}.jpg` → `punches/{userId}/{punchId}.jpg` ; règle Storage
    durcie (write si `request.auth.uid == userId`). `OutboxUploader` relit `userId` du doc punch
    (cache, repli serveur ; `FirebaseException` ciblée) — **aucune migration Drift, aucun changement
    de modèle**. Reports inchangés. Tests `flutter test` **44/44**, `flutter analyze` propre. Spec/plan :
    `docs/superpowers/{specs,plans}/2026-06-13-phase-4-chemins-storage-par-user*`. **Reste côté user
    (⚠ ORDRE) : 1) mettre à jour l'app sur tous les appareils, PUIS 2) `cd firebase && firebase
    deploy --only storage`** (sinon une vieille app écrivant l'ancien chemin plat est refusée) ;
    valider sur appareil (photo sous `punches/{userId}/{punchId}.jpg` en console Storage). Pousser
    `main` n'active PAS cette règle (seul le backoffice web s'auto-déploie sur Vercel).
  - **App Check** (attestation Play Integrity, enforcement progressif) : à faire.
  - **Publication Play Store** (signing, fiche, confidentialité, rollout) : à faire.

Voir **docs/HANDOFF.md** pour reprendre exactement où on en est.
