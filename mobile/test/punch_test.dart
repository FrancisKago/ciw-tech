import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/punch.dart';

void main() {
  test('toFirestore sérialise les champs attendus', () {
    final p = Punch(
      id: 'p1', userId: 'u1', kind: PunchKind.checkIn,
      clientTimestamp: DateTime.utc(2026, 6, 5, 8, 0),
      lat: 4.05, lng: 9.7, accuracy: 12.0, siteId: 's1',
      photoStatus: PhotoStatus.pending,
    );
    final map = p.toFirestore();
    expect(map['userId'], 'u1');
    expect(map['kind'], 'in');
    expect(map['geo'], {'lat': 4.05, 'lng': 9.7, 'accuracy': 12.0});
    expect(map['photoStatus'], 'pending');
    expect(map.containsKey('serverTimestamp'), true); // sentinel
  });

  test('kind sérialisé en in/out', () {
    expect(PunchKind.checkOut.wire, 'out');
    expect(PunchKindX.fromWire('in'), PunchKind.checkIn);
  });

  test('toFirestore inclut taskId quand fourni', () {
    final p = Punch(
      id: 'p1', userId: 'u1', kind: PunchKind.checkIn,
      clientTimestamp: DateTime.utc(2026, 6, 7), lat: 4, lng: 9, accuracy: 5,
      siteId: 's1', photoStatus: PhotoStatus.pending, taskId: 't1',
    );
    expect(p.toFirestore()['taskId'], 't1');
    expect(p.toFirestore()['siteId'], 's1');
  });
}
