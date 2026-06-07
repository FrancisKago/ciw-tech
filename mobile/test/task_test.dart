import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';

void main() {
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
