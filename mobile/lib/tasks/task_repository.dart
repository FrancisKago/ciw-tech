import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../outbox/outbox_db.dart';

class TaskRepository {
  TaskRepository(this._fs, this._outbox);
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('tasks');

  /// Création (manager, en ligne). Renvoie l'id de la tâche.
  Future<String> createTask({
    required String title,
    required String description,
    required String siteId,
    required String assigneeId,
    required String createdBy,
    required TaskPriority priority,
    DateTime? dueAt,
  }) async {
    final ref = _col.doc();
    final task = Task(
      id: ref.id, title: title, description: description, siteId: siteId,
      assigneeId: assigneeId, createdBy: createdBy, priority: priority,
      dueAt: dueAt, status: TaskStatus.assigned, report: null,
    );
    await ref.set(task.toFirestore());
    return ref.id;
  }

  /// Démarrage par le technicien (rejouable offline).
  Future<void> startTask(String taskId) => _col.doc(taskId).set(
        {'status': TaskStatus.inProgress.wire, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// Clôture : écrit le rapport (status=done) et enfile les photos dans l'outbox.
  Future<void> submitReport({
    required String taskId,
    required String text,
    required int minutesSpent,
    required List<String> photoPaths,
  }) async {
    final report = TaskReport(
      text: text, minutesSpent: minutesSpent,
      photoUrls: const [], photoCount: photoPaths.length,
    );
    await _col.doc(taskId).set(
      {
        'status': TaskStatus.done.wire,
        'report': report.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    for (final path in photoPaths) {
      await _outbox.enqueueReport(taskId, path);
    }
  }

  /// Tâches assignées à un technicien.
  Stream<List<Task>> tasksForAssignee(String userId) => _col
      .where('assigneeId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => Task.fromMap(d.id, d.data())).toList());

  /// Tâches créées par un manager.
  Stream<List<Task>> tasksCreatedBy(String userId) => _col
      .where('createdBy', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => Task.fromMap(d.id, d.data())).toList());

  /// Observe une tâche unique (pour un écran détail réactif : le bouton suit le statut).
  Stream<Task?> watchTask(String taskId) => _col.doc(taskId).snapshots().map(
      (d) => d.exists ? Task.fromMap(d.id, d.data()!) : null);
}
