import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';

void main() {
  group('DomaineTrade', () {
    test('wire de electricite vaut "electricite"', () {
      expect(DomaineTrade.electricite.wire, 'electricite');
    });

    test('fromWire("plomberie") retourne DomaineTrade.plomberie', () {
      expect(DomaineTradeX.fromWire('plomberie'), DomaineTrade.plomberie);
    });

    test('fromWire(null) retourne null', () {
      expect(DomaineTradeX.fromWire(null), isNull);
    });

    test('fromWire("inconnu") retourne DomaineTrade.autre (fallback)', () {
      expect(DomaineTradeX.fromWire('inconnu'), DomaineTrade.autre);
    });

    test('round-trip avec domaine: informatique', () {
      final t = Task(
        id: 'rt1', title: 'Réseau', description: 'desc', siteId: 's1',
        assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.normal,
        dueAt: null, status: TaskStatus.assigned, report: null,
        domaine: DomaineTrade.informatique,
      );
      final m = t.toFirestore();
      final t2 = Task.fromMap('rt1', {
        ...m,
        // Firestore-only values not returned by toFirestore raw map
        'domaine': m['domaine'],
      });
      expect(t2.domaine, DomaineTrade.informatique);
    });

    test('round-trip avec domaine: null (compat legacy)', () {
      final t = Task(
        id: 'rt2', title: 'Câblage', description: 'desc', siteId: 's1',
        assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.normal,
        dueAt: null, status: TaskStatus.assigned, report: null,
        domaine: null,
      );
      final m = t.toFirestore();
      final t2 = Task.fromMap('rt2', {
        ...m,
        'domaine': m['domaine'],
      });
      expect(t2.domaine, isNull);
    });
  });

  test('toFirestore sérialise les champs et le statut', () {
    final t = Task(
      id: 't1', title: 'Réparer', description: 'desc', siteId: 's1',
      assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.high,
      dueAt: DateTime.utc(2026, 6, 10), status: TaskStatus.assigned, report: null,
    );
    final m = t.toFirestore();
    expect(m['title'], 'Réparer');
    expect(m['assigneeId'], 'tech_1');
    expect(m['priority'], 'high');
    expect(m['status'], 'assigned');
    expect(m['report'], isNull);
  });

  test('TaskReport sérialise minutesSpent et photoCount', () {
    final r = TaskReport(text: 'fait', minutesSpent: 90, photoUrls: const [], photoCount: 2);
    final m = r.toMap();
    expect(m['text'], 'fait');
    expect(m['minutesSpent'], 90);
    expect(m['photoCount'], 2);
    expect(m['photoUrls'], isEmpty);
  });

  test('fromFirestore reconstruit le statut et la priorité', () {
    final t = Task.fromMap('t9', {
      'title': 'x', 'description': '', 'siteId': 's1', 'assigneeId': 'tech_1',
      'createdBy': 'mgr', 'priority': 'low', 'status': 'in_progress', 'report': null,
    });
    expect(t.status, TaskStatus.inProgress);
    expect(t.priority, TaskPriority.low);
  });

  test('fromWire reconnaît approved (lecture seule)', () {
    expect(TaskStatusX.fromWire('approved'), TaskStatus.approved);
    expect(TaskStatus.approved.wire, 'approved');
  });
}
