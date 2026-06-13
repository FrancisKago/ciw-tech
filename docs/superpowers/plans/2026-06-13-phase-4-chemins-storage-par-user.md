# Chemins Storage par utilisateur — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restreindre l'écriture des photos de pointage à leur propriétaire en passant de `punches/{punchId}.jpg` à `punches/{userId}/{punchId}.jpg`, sans casser l'offline-first.

**Architecture:** L'uploader (`OutboxUploader`) relit `userId` depuis le doc `punches/{punchId}` (cache local, repli serveur) au moment de l'upload pour construire le chemin imbriqué ; la règle Storage restreint l'écriture à `request.auth.uid == userId`. Aucune migration Drift, aucun changement du modèle Firestore. Les photos existantes restent visibles (URLs `getDownloadURL()` tokenisées).

**Tech Stack:** Flutter (Dart), `cloud_firestore`, `firebase_storage`, Drift (outbox) ; tests `flutter_test` + `fake_cloud_firestore`. Firebase Storage rules. Spec : `docs/superpowers/specs/2026-06-13-phase-4-chemins-storage-par-user-design.md`.

**Branche :** travailler sur `phase-4-chemins-storage-par-user` (déjà créée, contient la spec). Commandes mobile depuis `mobile/` (`cd mobile`). Le build APK n'est PAS lancé ici (validation appareil côté user) ; garde-fous = `flutter analyze` + `flutter test`.

---

## Structure des fichiers

| Fichier | Rôle | Action |
|---|---|---|
| `mobile/lib/outbox/outbox_uploader.dart` | Threading de `userId` + chemin Storage imbriqué pour les punches | Modifier |
| `mobile/test/outbox_uploader_test.dart` | Tests de l'uploader (nouvelle signature + cas userId) | Modifier |
| `firebase/storage.rules` | Règle `punches/{userId}/{fileName}` (write réservé au propriétaire) | Modifier |

---

## Task 1: Uploader — threading de `userId` et chemin imbriqué

**Files:**
- Modify: `mobile/lib/outbox/outbox_uploader.dart`
- Test: `mobile/test/outbox_uploader_test.dart`

TDD : on met à jour le fichier de tests vers la nouvelle signature `UploadFn` (rouge, car le code ne compile plus / n'a pas le comportement attendu), puis on implémente.

- [ ] **Step 1: Réécrire le fichier de tests (rouge)**

Remplacer **entièrement** `mobile/test/outbox_uploader_test.dart` par :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/outbox/outbox_uploader.dart';

void main() {
  test('drain upload une photo de pointage sous punches/{userId}/{punchId} et patche le punch',
      () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending', 'userId': 'u1'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    String? seenUserId;
    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, userId, path) async {
      seenUserId = userId;
      return 'https://storage/$userId/$ownerId.jpg';
    });
    await uploader.drainOnce();

    expect(seenUserId, 'u1'); // userId relu depuis le doc punch
    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'uploaded');
    expect(doc.data()!['photoUrl'], 'https://storage/u1/p1.jpg');
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('drain upload une photo de rapport et arrayUnion sur report.photoUrls (userId null)',
      () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('tasks').doc('t1').set({
      'status': 'done',
      'report': {'text': 'fait', 'photoUrls': <String>[], 'photoCount': 1},
    });
    await outbox.enqueueReport('t1', '/tmp/a.jpg');

    String? seenUserId = 'sentinelle';
    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, userId, path) async {
      seenUserId = userId;
      return 'https://storage/$ownerId/a.jpg';
    });
    await uploader.drainOnce();

    expect(seenUserId, isNull); // pas de userId pour un rapport
    final doc = await fs.collection('tasks').doc('t1').get();
    final report = doc.data()!['report'] as Map<String, dynamic>;
    expect(report['photoUrls'], contains('https://storage/t1/a.jpg'));
    // Non-régression : le merge ne doit PAS écraser les champs frères du rapport.
    expect(report['text'], 'fait');
    expect(report['photoCount'], 1);
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('un upload qui échoue bumpAttempts et garde l\'élément', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending', 'userId': 'u1'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (_, _, _, _) async => throw Exception('réseau'));
    await uploader.drainOnce();

    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    await outbox.close();
  });

  test('un punch sans userId lisible reste en attente sans upload ni patch', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    // Doc punch sans champ userId.
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    var uploadCalled = false;
    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, userId, path) async {
      uploadCalled = true;
      return 'https://storage/x.jpg';
    });
    await uploader.drainOnce();

    expect(uploadCalled, isFalse); // pas d'upload sur un chemin invalide
    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'pending'); // doc non patché
    expect(doc.data()!.containsKey('photoUrl'), isFalse);
    await outbox.close();
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: `cd mobile && flutter test test/outbox_uploader_test.dart`
Expected: FAIL (la signature `uploadFn: (kind, ownerId, userId, path)` ne correspond pas au `UploadFn` actuel à 3 paramètres → erreur de compilation).

- [ ] **Step 3: Mettre à jour le typedef et `_defaultUpload`**

Dans `mobile/lib/outbox/outbox_uploader.dart`, remplacer :

```dart
/// Upload réel : retourne l'URL de téléchargement. `kind` route le chemin Storage.
typedef UploadFn = Future<String> Function(String kind, String ownerId, String localPath);
```

par :

```dart
/// Upload réel : retourne l'URL de téléchargement. `kind` route le chemin Storage.
/// Pour un punch, `userId` (propriétaire) compose le chemin `punches/{userId}/{punchId}.jpg`.
typedef UploadFn = Future<String> Function(
    String kind, String ownerId, String? userId, String localPath);
```

et remplacer :

```dart
  static Future<String> _defaultUpload(String kind, String ownerId, String localPath) async {
    final path = kind == 'report'
        ? 'tasks/$ownerId/report/${DateTime.now().microsecondsSinceEpoch}.jpg'
        : 'punches/$ownerId.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }
```

par :

```dart
  static Future<String> _defaultUpload(
      String kind, String ownerId, String? userId, String localPath) async {
    final path = kind == 'report'
        ? 'tasks/$ownerId/report/${DateTime.now().microsecondsSinceEpoch}.jpg'
        : 'punches/$userId/$ownerId.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }
```

- [ ] **Step 4: Ajouter le helper de lecture de `userId` et l'appeler dans `drainOnce`**

Dans `mobile/lib/outbox/outbox_uploader.dart`, remplacer le corps de la boucle `for (final item in await _outbox.pending()) { ... }` :

```dart
          try {
            final url = await _upload(item.kind, item.ownerId, item.localPath);
            if (item.kind == 'report') {
```

par (lire `userId` pour les punches avant l'upload, échec contrôlé si absent) :

```dart
          try {
            String? userId;
            if (item.kind == 'punch') {
              userId = await _punchUserId(item.ownerId);
              if (userId == null || userId.isEmpty) {
                throw StateError('userId introuvable pour le punch ${item.ownerId}');
              }
            }
            final url = await _upload(item.kind, item.ownerId, userId, item.localPath);
            if (item.kind == 'report') {
```

Puis ajouter le helper privé dans la classe `OutboxUploader` (par exemple juste avant `_defaultUpload`) :

```dart
  /// Lit le `userId` du doc punch pour composer le chemin Storage.
  /// D'abord le cache (le doc, écrit par createPunch, y est garanti même hors
  /// ligne) ; repli sur un get serveur si le doc n'est pas dans le cache.
  Future<String?> _punchUserId(String punchId) async {
    final ref = _fs.collection('punches').doc(punchId);
    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get(const GetOptions(source: Source.cache));
      if (!snap.exists) snap = await ref.get();
    } catch (_) {
      snap = await ref.get();
    }
    return snap.data()?['userId'] as String?;
  }
```

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run: `cd mobile && flutter test test/outbox_uploader_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Analyse statique**

Run: `cd mobile && flutter analyze lib/outbox/outbox_uploader.dart test/outbox_uploader_test.dart`
Expected: aucune erreur (« No issues found! »).

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/outbox/outbox_uploader.dart mobile/test/outbox_uploader_test.dart
git commit -m "feat(outbox): upload des photos de pointage sous punches/{userId}/{punchId}"
```

---

## Task 2: Règle Storage `punches/{userId}/{fileName}`

**Files:**
- Modify: `firebase/storage.rules`

Pas de test automatisé exécuté ici (l'émulateur Storage n'est pas câblé dans le contexte Claude ; validation syntaxe par dry-run côté user). Le changement est une substitution exacte.

- [ ] **Step 1: Remplacer le bloc `punches`**

Dans `firebase/storage.rules`, remplacer :

```
    // Photos de pointage : chemin `punches/{punchId}.jpg`.
    // Un utilisateur connecté peut déposer sa photo (≤ 10 Mo) ; managers/admins lisent.
    // NOTE durcissement (phase 4) : passer à `punches/{userId}/{punchId}.jpg`
    // pour restreindre l'écriture au propriétaire.
    match /punches/{fileName} {
      allow write: if isSignedIn() && request.resource.size < 10 * 1024 * 1024;
      allow read: if isManager();
    }
```

par :

```
    // Photos de pointage : chemin `punches/{userId}/{punchId}.jpg`.
    // Écriture réservée au propriétaire (auth.uid == userId), ≤ 10 Mo ; managers/admins lisent.
    match /punches/{userId}/{fileName} {
      allow write: if isSignedIn() && request.auth.uid == userId
                   && request.resource.size < 10 * 1024 * 1024;
      allow read: if isManager();
    }
```

Ne rien changer d'autre (bloc `tasks/{taskId}/report/{fileName}` et `match /{allPaths=**}` inchangés).

- [ ] **Step 2: Vérifier la cohérence du fichier**

Lire `firebase/storage.rules` et confirmer : le nouveau bloc est en place, le bloc report est intact, le `match /{allPaths=**} { allow read, write: if false; }` final est toujours présent.

- [ ] **Step 3: Commit**

```bash
git add firebase/storage.rules
git commit -m "feat(storage-rules): écriture des photos de pointage réservée au propriétaire"
```

---

## Task 3: Garde-fous finaux

**Files:** aucun (vérification globale).

- [ ] **Step 1: Suite de tests mobile complète**

Run: `cd mobile && flutter test`
Expected: PASS (suite existante + 4 tests outbox). Le compte doit rester ≥ 43 (la base actuelle) — aucun test cassé.

- [ ] **Step 2: Analyse statique globale**

Run: `cd mobile && flutter analyze`
Expected: « No issues found! ».

- [ ] **Step 3: Finalisation de branche**

La branche `phase-4-chemins-storage-par-user` est prête. Utiliser la sous-compétence **superpowers:finishing-a-development-branch** pour décider du merge (`--no-ff` vers `main` comme Cycle #4/#5). Mettre à jour `CLAUDE.md` (statut Phase 4 : chantier Storage par user livré) et `docs/HANDOFF.md`.

---

## Notes de validation / déploiement (côté user — après merge)
- **Contrairement au cycle anomalies, ce cycle change les règles Storage** → déployer :
  `cd firebase && firebase deploy --only storage` (syntaxe vérifiable au préalable par
  `firebase deploy --only storage --dry-run`).
- **Rebuild Android + validation appareil** (build APK depuis le terminal user, pas dans le
  contexte Claude) : pointer dans le rayon avec photo → vérifier dans la console Storage que le
  fichier apparaît sous `punches/{userId}/{punchId}.jpg`, et que la photo s'affiche au backoffice.
- Optionnel : tests de règles Storage via l'émulateur (analogue aux tests de règles Firestore) :
  un utilisateur écrit `punches/{sonUid}/x.jpg` (autorisé) / `punches/{autreUid}/x.jpg` (refusé) ;
  lecture par un non-manager (refusée).
- Les photos déjà uploadées sous l'ancien chemin restent affichées (URLs `photoUrl` tokenisées).
