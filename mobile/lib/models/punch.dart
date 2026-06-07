import 'package:cloud_firestore/cloud_firestore.dart';

enum PunchKind { checkIn, checkOut }
extension PunchKindX on PunchKind {
  String get wire => this == PunchKind.checkIn ? 'in' : 'out';
  static PunchKind fromWire(String w) => w == 'in' ? PunchKind.checkIn : PunchKind.checkOut;
}

enum PhotoStatus { pending, uploaded }
extension PhotoStatusX on PhotoStatus {
  String get wire => this == PhotoStatus.pending ? 'pending' : 'uploaded';
}

class Punch {
  Punch({
    required this.id, required this.userId, required this.kind,
    required this.clientTimestamp, required this.lat, required this.lng,
    required this.accuracy, required this.siteId, required this.photoStatus,
    this.photoUrl, this.taskId,
  });
  final String id;
  final String userId;
  final PunchKind kind;
  final DateTime clientTimestamp;
  final double lat, lng, accuracy;
  final String? siteId;
  final PhotoStatus photoStatus;
  final String? photoUrl;
  final String? taskId;

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'kind': kind.wire,
        'clientTimestamp': Timestamp.fromDate(clientTimestamp),
        'serverTimestamp': FieldValue.serverTimestamp(),
        'geo': {'lat': lat, 'lng': lng, 'accuracy': accuracy},
        'siteId': siteId,
        'photoStatus': photoStatus.wire,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (taskId != null) 'taskId': taskId,
      };
}
