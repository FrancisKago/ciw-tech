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
- `tasks/{taskId}` : (Phase 2) title, description, siteId, assigneeId, priority, dueAt, status, attachments[], report{...}

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
- **Phase 4 (durcissement : App Check, anomalies, chemins Storage par user, publication Play Store)** : à faire.

Voir **docs/HANDOFF.md** pour reprendre exactement où on en est.
