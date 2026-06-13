# Design — Phase 4 (cycle) : Chemins Storage par utilisateur

**Date :** 2026-06-13
**Statut :** spec validée (brainstorming), prête pour le plan d'implémentation.
**Périmètre :** chantier de durcissement Phase 4 (sécurité Storage). Indépendant des autres chantiers
Phase 4 (App Check, Play Store), qui auront chacun leur cycle.

## Objectif
Fermer une faille : aujourd'hui n'importe quel utilisateur connecté peut écrire la photo de
pointage `punches/{punchId}.jpg` (la règle ne lie pas le fichier à son propriétaire). On passe au
chemin **`punches/{userId}/{punchId}.jpg`** et on restreint l'écriture à
`request.auth.uid == userId`. L'offline-first est **préservé**.

## Principe
Le doc `punches/{punchId}` porte déjà `userId` (= id Clerk = `auth.uid` via `mintFirebaseToken`).
L'uploader le **relit en cache** au moment de l'upload pour construire le chemin imbriqué.
**Aucune migration Drift, aucun changement du modèle Firestore, aucun changement de
`PunchRepository`/`Punch`.** Les photos déjà uploadées restent visibles : les URLs
`getDownloadURL()` stockées dans `photoUrl` contiennent un token d'accès et sont servies
indépendamment des règles Storage.

## Composants

### 1. `mobile/lib/outbox/outbox_uploader.dart`
- Le typedef devient :
  ```dart
  typedef UploadFn = Future<String> Function(String kind, String ownerId, String? userId, String localPath);
  ```
- Dans `drainOnce`, pour un item `kind == 'punch'` : lire `userId` depuis `punches/{punchId}`
  via `Source.cache` (le doc, écrit par `createPunch`, est garanti en cache local) **avant**
  l'upload ; repli sur un `get()` serveur si le doc est absent du cache (couvre une ligne d'outbox
  en vol après un éventuel vidage de cache). Passer `userId` à `_upload`. Pour `kind == 'report'` :
  `userId == null`.
- `_defaultUpload` construit :
  - punch → `punches/$userId/$ownerId.jpg`
  - report → `tasks/$ownerId/report/${DateTime.now().microsecondsSinceEpoch}.jpg` (inchangé)
- Si `userId` est introuvable/vide pour un punch : traiter comme **échec d'upload**
  (`bumpAttemptsById`, l'item reste en attente), ne jamais uploader sur un chemin invalide.
- Le patch du doc (`photoUrl` + `photoStatus: 'uploaded'`) et le deep-merge des rapports restent
  inchangés.

### 2. `firebase/storage.rules`
- Remplacer le bloc `match /punches/{fileName}` par :
  ```
  // Photos de pointage : chemin `punches/{userId}/{punchId}.jpg`.
  // Écriture réservée au propriétaire (auth.uid == userId), ≤ 10 Mo ; managers/admins lisent.
  match /punches/{userId}/{fileName} {
    allow write: if isSignedIn() && request.auth.uid == userId
                 && request.resource.size < 10 * 1024 * 1024;
    allow read: if isManager();
  }
  ```
- Le bloc `match /tasks/{taskId}/report/{fileName}` reste **inchangé** (écriture déjà restreinte à
  l'assigné via `firestore.get`). Le `match /{allPaths=**} { allow read, write: if false; }` reste.

## Hors périmètre (YAGNI)
- **Reports** : déjà owner-scopés. Aucun changement.
- **Pas de migration** des anciennes photos `punches/{punchId}.jpg` (URLs tokenisées encore
  valides ; le backoffice affiche `photoUrl`, pas un chemin).
- **Pas de colonne Drift** ni de migration de schéma ; pas de changement de `Punch`/`PunchRepository`.
- **Pas de durcissement de la lecture** au-delà de l'existant (lecture manager).

## Flux de données
```
createPunch  → écrit punches/{punchId} (avec userId) + enqueuePunch(punchId, localPath)   [inchangé]
drainOnce    → pour chaque item 'punch' :
                 userId = lire punches/{punchId} (Source.cache, repli serveur).userId
                 url    = _upload('punch', punchId, userId, localPath)
                          → upload vers punches/{userId}/{punchId}.jpg
                 patch punches/{punchId} { photoUrl: url, photoStatus: 'uploaded' }          [inchangé]
             → pour chaque item 'report' : userId=null, comportement inchangé
```

## Gestion d'erreurs
- `userId` illisible/vide → échec contrôlé (`bumpAttemptsById`, réessai ultérieur), jamais
  d'écriture sur un chemin invalide.
- Lignes d'outbox en vol après mise à jour de l'app : traitées par le nouvel uploader qui relit
  `userId` (cache, repli serveur) → écrit le nouveau chemin. Aucune écriture sur l'ancien chemin
  après mise à jour.
- Photos existantes : intactes, toujours affichées via `photoUrl` stocké (URL tokenisée).

## Tests
- **`mobile/test/outbox_uploader_test.dart`** :
  - Mettre à jour la signature du faux `uploadFn` en `(kind, ownerId, userId, path)`.
  - **Punch** : seeder `punches/p1` = `{photoStatus:'pending', userId:'u1'}` ; vérifier que
    l'uploader lit `userId` et que le chemin/URL reflète `punches/u1/p1.jpg` (assertion sur
    l'argument `userId` reçu par le faux uploadFn **et** sur l'URL retournée patchée dans le doc) ;
    `photoStatus` passe à `uploaded`.
  - **Report** : `userId == null` ; non-régression du deep-merge (`report.text`/`photoCount`
    préservés) déjà couverte — l'adapter à la nouvelle signature.
  - **Échec réseau** : `bumpAttempts` (inchangé, adapter la signature `(_, _, _, _)`).
  - **`userId` manquant pour un punch** : l'item reste en attente (`count == 1`, `attempts`
    incrémenté), aucun patch du doc.
- **Règles Storage** : cas couverts si tu lances l'émulateur
  (`firebase emulators:exec --only storage "..."`, analogue aux tests de règles Firestore) :
  écrire `punches/{sonUid}/x.jpg` (autorisé), `punches/{autreUid}/x.jpg` (refusé), lecture par un
  non-manager (refusée). Sinon syntaxe via `firebase deploy --only storage --dry-run`.
- Garde-fous mobile : `flutter analyze` + `flutter test`.

## Déploiement & validation (côté user)
- **`cd firebase && firebase deploy --only storage`** (changement de règles).
- **Rebuild Android + validation sur appareil** (le build APK se fait depuis le terminal de
  l'utilisateur) : pointer dans le rayon avec photo → vérifier dans la console Storage que le
  fichier apparaît sous `punches/{userId}/{punchId}.jpg`, et que la photo s'affiche au backoffice.

## Conventions
- TDD (rouge → vert → commit), commits atomiques en français (`feat/fix/test/chore(scope):`).
- Mobile : logique testable, `flutter analyze`/`flutter test` comme garde-fous (le build APK n'est
  pas lancé dans le contexte Claude — validation appareil côté user).
