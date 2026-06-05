# Mise en service — étapes nécessitant vos comptes (à faire par la direction)

Le code des **Phases 0 + 1** est implémenté et testé (logique pure + émulateurs).
Les étapes ci-dessous n'ont **pas** pu être faites en autonomie car elles exigent
de vrais comptes/clés. Faites-les dans l'ordre.

## 1. Firebase
1. Créer un projet Firebase (id suggéré : `cameroon-innovation`). Passer au plan
   **Blaze** (requis pour les Cloud Functions ; paliers gratuits suffisants).
2. `firebase login` sur la machine de dev.
3. Si l'id réel diffère de `cameroon-innovation`, corriger `firebase/.firebaserc`.
4. Définir le secret Clerk pour la fonction (Functions v2) :
   `cd firebase/functions && firebase functions:secrets:set CLERK_SECRET_KEY`
   (la fonction lit `process.env.CLERK_SECRET_KEY`).
5. Déployer :
   `cd firebase && firebase deploy --only firestore:rules,storage,functions`

## 2. Clerk
1. Créer une application Clerk. Récupérer `PUBLISHABLE_KEY`, `SECRET_KEY`, l'issuer JWT.
2. Renseigner le **rôle** de chaque utilisateur dans Clerk → `publicMetadata.role`
   = `technician` | `manager` | `admin` (le pont d'auth lit ce champ).

## 3. Backoffice web
1. `cp web/.env.local.example web/.env.local` puis remplir :
   - clés Clerk ;
   - identifiants d'un **compte de service** Firebase (`FIREBASE_CLIENT_EMAIL`,
     `FIREBASE_PRIVATE_KEY`) — générer dans Firebase Console → Paramètres → Comptes de service.
2. `cd web && npm install && npm run dev` → tester la connexion Clerk + la page `/presence`.

## 4. App mobile
1. `cd mobile && flutterfire configure --project=<id-reel> --platforms=android`
   → **remplace le placeholder** `lib/firebase_options.dart` et génère
   `android/app/google-services.json`.
2. Ajouter Clerk : `flutter pub add clerk_flutter` (déféré pour éviter un conflit de
   versions au démarrage ; voir le commentaire dans `pubspec.yaml`).
3. Implémenter concrètement `lib/auth/clerk_auth_service.dart` (récupérer le JWT de
   session Clerk) et brancher l'écran de connexion ; vérifier l'API exacte de
   `clerk_flutter` (MCP context7 / pub.dev).
4. Dans `lib/main.dart`, remplacer `userId: 'TODO-from-auth'` par
   `FirebaseAuth.instance.currentUser!.uid` une fois le pont d'auth branché
   (envelopper l'app dans un `StreamBuilder` sur `authStateChanges()` : écran de
   connexion si non connecté, `PointageScreen` sinon).
5. `flutter build apk` (nécessite l'étape 1).

## 5. Vérifications d'intégration de bout en bout (non automatisables sans clés)
- Connexion Clerk sur mobile **et** web → identité Firebase obtenue avec le bon rôle.
- Pointage hors ligne (mode avion) → doc créé en cache + photo en outbox → retour
  réseau → photo uploadée + doc patché `photoStatus: uploaded`.
- Page `/presence` du backoffice : heures par technicien, anomalies, hors-rayon.

## Notes / dette connue
- **Émulateur Firestore + Java 17 (ce poste)** : un contournement (provider de
  sélecteur NIO forçant le repli TCP) a été nécessaire pour exécuter les tests de
  règles. Voir le rapport d'exécution ; à reproduire si les tests `rules` échouent
  avec une erreur de socket Unix.
- **Header backoffice (Clerk v7)** : `<SignedIn>`/`<SignedOut>` remplacés par
  `<Show when="signed-in/out">`. À vérifier visuellement une fois les clés en place.
- **Versions Flutter** : `flutter_riverpod` maintenu en 2.x et `drift`/`sqlite3`
  bornés sous les lignes à hooks natifs (incompatibles build_runner sur Dart 3.10).
  Commentaires explicatifs dans `mobile/pubspec.yaml`.

## État des tests (au moment de la livraison)
- Cloud Functions : 4 tests purs + 4 tests de règles (émulateur) ✓
- Backoffice web : 6 tests (heures, géo) ✓
- Mobile Flutter : 13 tests (modèles, outbox, repo, uploader, sync, widgets) ✓
