import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'outbox_db.dart';

/// Upload réel : retourne l'URL de téléchargement. `kind` route le chemin Storage.
typedef UploadFn = Future<String> Function(String kind, String ownerId, String localPath);

class OutboxUploader {
  OutboxUploader(this._fs, this._outbox, {UploadFn? uploadFn})
      : _upload = uploadFn ?? _defaultUpload;
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;
  final UploadFn _upload;

  bool _draining = false;
  bool _again = false;

  static Future<String> _defaultUpload(String kind, String ownerId, String localPath) async {
    final path = kind == 'report'
        ? 'tasks/$ownerId/report/${DateTime.now().microsecondsSinceEpoch}.jpg'
        : 'punches/$ownerId.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
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
            final url = await _upload(item.kind, item.ownerId, item.localPath);
            if (item.kind == 'report') {
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
