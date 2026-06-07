# Session Handoff — Cameroon Innovation

**Date :** 2026-06-07
**État global :** Phases 0 + 1 **terminées et validées de bout en bout sur appareil réel**
(tablette Samsung SM X115 → backoffice). L'app de pointage est fonctionnelle.

## Ce qui a été livré cette session
1. **Conception + plan** : `docs/superpowers/specs/2026-06-05-...-design.md`,
   `docs/superpowers/plans/2026-06-05-cameroon-innovation-phases-0-1.md`.
2. **Code Phases 0+1** (mobile + web + firebase), en TDD, ~27 tests verts.
3. **Mise en service réelle** : projet Firebase `cameroon-innovation` (Blaze),
   Clerk, déploiement règles/fonction/Storage, comptes de service, IAM.
4. **Validation terrain** : connexion Clerk→Firebase, pointage GPS+photo offline,
   synchro auto, affichage backoffice — tout confirmé sur la tablette.

## Réglages de mise en service effectués (détail dans docs/SETUP.md)
- Firebase Blaze + APIs activées ; secret `CLERK_SECRET_KEY` posé.
- IAM : compute SA → `cloudbuild.builds.builder`, `iam.serviceAccountTokenCreator`,
  `datastore.user` ; adminsdk SA → `datastore.user` ; Cloud Run `mintfirebasetoken`
  → `allUsers`/`run.invoker`.
- Firebase **Authentication activé** (sinon `CONFIGURATION_NOT_FOUND`).
- Clerk : rôle `admin` mis sur le compte direction (`publicMetadata.role`).
  ⚠️ **À faire pour le mobile** : personnaliser le jeton de session Clerk avec
  `{ "public_metadata": "{{user.public_metadata}}" }` pour que le rôle remonte au pont.

## Secrets / config locale (NON commités, à recréer si besoin)
- `web/.env.local` : clés Clerk + compte de service Firebase.
- `firebase/functions` secret `CLERK_SECRET_KEY` (Secret Manager).
- `mobile/android/app/google-services.json` + `mobile/lib/firebase_options.dart`
  (générés par `flutterfire configure` ; google-services.json est commité, c'est toléré).
- Clé publishable Clerk passée au run : `--dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...`
  (récupérable dans Clerk → API Keys, aussi dans web/.env.local).

## Dette connue / à reprendre
- **Relancer `flutter run`** une fois pour intégrer le verrou anti-concurrence outbox
  (déjà commité) et `kotlin.incremental=false` (build plus propre).
- **Phase 4 — App Check** : non configuré (`No AppCheckProvider installed` dans les logs).
  À ajouter pour verrouiller l'accès au backend.
- **Phase 4 — chemins Storage par utilisateur** : aujourd'hui `punches/{punchId}.jpg`
  avec write pour tout utilisateur connecté ; passer à `punches/{userId}/{punchId}.jpg`.
- **Phase 4 — calcul hors-rayon** : `isOutsideSite` prêt côté web mais `siteId` est nul
  au pointage (pas encore d'affectation site→technicien ; viendra avec les tâches).

## Prochaine étape : Phase 2 (tâches + rapports + notifications push)
- Manager (mobile) : créer/assigner des tâches (titre, description, site, échéance, priorité, pièces jointes).
- Technicien (mobile) : recevoir (push FCM), passer in_progress, rapport (texte + photos + statut + temps passé).
- Cloud Function : trigger FCM à l'assignation.
- Ouvrir les règles Storage pour les pièces jointes tâches/rapports.
- Démarrer par un brainstorming léger → plan → exécution (même cycle que Phase 1).

## Pour reprendre
1. Lire `CLAUDE.md` (mémoire projet) + ce fichier.
2. `git pull` (remote : https://github.com/FrancisKago/ciw-tech).
3. Vérifier l'état : `cd mobile && flutter test` ; `cd web && npx jest`.
4. Lancer `/gsd-...` ou brainstorming pour la Phase 2.
