import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/punch.dart';
import '../outbox/outbox_db.dart';

class PunchRepository {
  PunchRepository(this._fs, this._outbox);
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;

  Future<String> createPunch({
    required String userId,
    required PunchKind kind,
    required double lat,
    required double lng,
    required double accuracy,
    required String? siteId,
    required String photoPath,
    String? taskId,
    DateTime? now,
  }) async {
    final ref = _fs.collection('punches').doc();
    final punch = Punch(
      id: ref.id, userId: userId, kind: kind,
      clientTimestamp: (now ?? DateTime.now()).toUtc(),
      lat: lat, lng: lng, accuracy: accuracy, siteId: siteId,
      photoStatus: PhotoStatus.pending, taskId: taskId,
    );
    // set() ne bloque pas hors ligne : Firestore met en cache et synchronise plus tard.
    ref.set(punch.toFirestore());
    await _outbox.enqueuePunch(ref.id, photoPath);
    return ref.id;
  }
}
