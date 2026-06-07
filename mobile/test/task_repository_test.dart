import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/tasks/task_repository.dart';

void main() {
  test('createTask écrit un doc status=assigned avec createdBy', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TaskRepository(fs, OutboxDb.memory());

    final id = await repo.createTask(
        title: 'Réparer', description: 'd', siteId: 's1',
        assigneeId: 'tech_1', createdBy: 'mgr',
        priority: TaskPriority.high, dueAt: DateTime.utc(2026, 6, 10));

    final doc = await fs.collection('tasks').doc(id).get();
    expect(doc.data()!['status'], 'assigned');
    expect(doc.data()!['createdBy'], 'mgr');
    expect(doc.data()!['assigneeId'], 'tech_1');
  });

  test('startTask passe le statut à in_progress', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TaskRepository(fs, OutboxDb.memory());
    await fs.collection('tasks').doc('t1').set({'status': 'assigned'});

    await repo.startTask('t1');

    final doc = await fs.collection('tasks').doc('t1').get();
    expect(doc.data()!['status'], 'in_progress');
  });

  test('submitReport écrit status=done, le rapport, et enfile les photos', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    final repo = TaskRepository(fs, outbox);
    await fs.collection('tasks').doc('t1').set({'status': 'in_progress'});

    await repo.submitReport(
        taskId: 't1', text: 'fait', minutesSpent: 90,
        photoPaths: ['/tmp/a.jpg', '/tmp/b.jpg']);

    final doc = await fs.collection('tasks').doc('t1').get();
    expect(doc.data()!['status'], 'done');
    final report = doc.data()!['report'] as Map<String, dynamic>;
    expect(report['text'], 'fait');
    expect(report['minutesSpent'], 90);
    expect(report['photoCount'], 2);
    expect(await outbox.count(), 2); // 2 photos enfilées
    await outbox.close();
  });

  test('tasksForAssignee filtre par assigneeId', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TaskRepository(fs, OutboxDb.memory());
    await fs.collection('tasks').doc('t1').set({
      'title': 'a', 'assigneeId': 'tech_1', 'createdBy': 'mgr',
      'siteId': 's1', 'priority': 'normal', 'status': 'assigned', 'report': null,
      'description': '',
    });
    await fs.collection('tasks').doc('t2').set({
      'title': 'b', 'assigneeId': 'tech_2', 'createdBy': 'mgr',
      'siteId': 's1', 'priority': 'normal', 'status': 'assigned', 'report': null,
      'description': '',
    });

    final list = await repo.tasksForAssignee('tech_1').first;
    expect(list.length, 1);
    expect(list.single.id, 't1');
  });

  test('watchTask suit le statut de la tâche', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TaskRepository(fs, OutboxDb.memory());
    await fs.collection('tasks').doc('t1').set({
      'title': 'a', 'assigneeId': 'tech_1', 'createdBy': 'mgr',
      'siteId': 's1', 'priority': 'normal', 'status': 'assigned', 'report': null,
      'description': '',
    });

    final first = await repo.watchTask('t1').first;
    expect(first!.status, TaskStatus.assigned);

    await repo.startTask('t1');
    final after = await repo.watchTask('t1').first;
    expect(after!.status, TaskStatus.inProgress);
  });
}
