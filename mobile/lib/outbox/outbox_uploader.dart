import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'outbox_db.dart';

/// Upload réel : retourne l'URL de téléchargement. `kind` route le chemin Storage.
/// Pour un punch, `userId` (propriétaire) compose le chemin `punches/{userId}/{punchId}.jpg`.
typedef UploadFn = Future<String> Function(
    String kind, String ownerId, String? userId, String localPath);

class OutboxUploader {
  OutboxUploader(this._fs, this._outbox, {UploadFn? uploadFn})
      : _upload = uploadFn ?? _defaultUpload;
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;
  final UploadFn _upload;

  bool _draining = false;
  bool _again = false;

  static Future<String> _defaultUpload(
      String kind, String ownerId, String? userId, String localPath) async {
    final path = kind == 'report'
        ? 'tasks/$ownerId/report/${DateTime.now().microsecondsSinceEpoch}.jpg'
        : 'punches/$userId/$ownerId.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }

  /// Lit le `userId` du doc punch pour composer le chemin Storage.
  /// D'abord le cache (le doc, écrit par createPunch, y est garanti même hors
  /// ligne) ; repli sur un get serveur si le doc n'est pas dans le cache.
  Future<String?> _punchUserId(String punchId) async {
    final ref = _fs.collection('punches').doc(punchId);
    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get(const GetOptions(source: Source.cache));
      if (!snap.exists) snap = await ref.get();
    } on FirebaseException catch (_) {
      snap = await ref.get();
    }
    return snap.data()?['userId'] as String?;
  }

  /// Tente d'uploader toutes les photos en attente. Sûr à appeler souvent :
  /// les appels concurrents sont fusionnés.
  Future<void> drainOnce() async {
    if (_draining) {
      _again = true;
      return;
    }
    _draining = true;
    try {
      do {
        _again = false;
        for (final item in await _outbox.pending()) {
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
              // set(merge:true) fait un *deep merge* des maps imbriquées : seul
              // report.photoUrls est touché (arrayUnion), les champs frères
              // report.text/minutesSpent/photoCount écrits par submitReport sont
              // préservés. (Test outbox_uploader : vérifie la non-régression.)
              await _fs.collection('tasks').doc(item.ownerId).set(
                {'report': {'photoUrls': FieldValue.arrayUnion([url])}},
                SetOptions(merge: true),
              );
            } else {
              await _fs.collection('punches').doc(item.ownerId).set(
                {'photoUrl': url, 'photoStatus': 'uploaded'},
                SetOptions(merge: true),
              );
            }
            await _outbox.removeById(item.id);
          } catch (_) {
            await _outbox.bumpAttemptsById(item.id);
          }
        }
      } while (_again);
    } finally {
      _draining = false;
    }
  }
}
