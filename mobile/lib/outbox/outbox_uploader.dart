import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'outbox_db.dart';

typedef UploadFn = Future<String> Function(String punchId, String localPath);

class OutboxUploader {
  OutboxUploader(this._fs, this._outbox, {UploadFn? uploadFn})
      : _upload = uploadFn ?? _defaultUpload;
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;
  final UploadFn _upload;

  // Verrou anti-concurrence : une seule vidange à la fois. Si une autre est
  // demandée pendant qu'une vidange tourne, on la relance une fois à la fin
  // (capte les pointages créés en cours de route) au lieu de paralléliser.
  bool _draining = false;
  bool _again = false;

  static Future<String> _defaultUpload(String punchId, String localPath) async {
    final ref = FirebaseStorage.instance.ref('punches/$punchId.jpg');
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
            final url = await _upload(item.punchId, item.localPath);
            await _fs.collection('punches').doc(item.punchId).set(
              {'photoUrl': url, 'photoStatus': 'uploaded'},
              SetOptions(merge: true),
            );
            await _outbox.remove(item.punchId);
          } catch (_) {
            await _outbox.bumpAttempts(item.punchId);
          }
        }
      } while (_again);
    } finally {
      _draining = false;
    }
  }
}
