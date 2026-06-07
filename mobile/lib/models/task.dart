import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { assigned, inProgress, done, approved }
extension TaskStatusX on TaskStatus {
  String get wire => switch (this) {
        TaskStatus.assigned => 'assigned',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
        TaskStatus.approved => 'approved',
      };
  static TaskStatus fromWire(String w) => switch (w) {
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        'approved' => TaskStatus.approved,
        _ => TaskStatus.assigned,
      };
}

enum TaskPriority { low, normal, high }
extension TaskPriorityX on TaskPriority {
  String get wire => name;
  static TaskPriority fromWire(String w) =>
      TaskPriority.values.firstWhere((p) => p.name == w, orElse: () => TaskPriority.normal);
}

class TaskReport {
  TaskReport({
    required this.text, required this.minutesSpent,
    required this.photoUrls, required this.photoCount,
  });
  final String text;
  final int minutesSpent;
  final List<String> photoUrls;
  final int photoCount;

  Map<String, dynamic> toMap() => {
        'text': text,
        'minutesSpent': minutesSpent,
        'photoUrls': photoUrls,
        'photoCount': photoCount,
        'submittedAt': FieldValue.serverTimestamp(),
      };

  static TaskReport? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return TaskReport(
      text: (m['text'] ?? '') as String,
      minutesSpent: (m['minutesSpent'] ?? 0) as int,
      photoUrls: List<String>.from(m['photoUrls'] ?? const []),
      photoCount: (m['photoCount'] ?? 0) as int,
    );
  }
}

class Task {
  Task({
    required this.id, required this.title, required this.description,
    required this.siteId, required this.assigneeId, required this.createdBy,
    required this.priority, required this.dueAt, required this.status, this.report,
  });
  final String id, title, description, siteId, assigneeId, createdBy;
  final TaskPriority priority;
  final DateTime? dueAt;
  final TaskStatus status;
  final TaskReport? report;

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'siteId': siteId,
        'assigneeId': assigneeId,
        'createdBy': createdBy,
        'priority': priority.wire,
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
        'status': status.wire,
        'report': report?.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Task fromMap(String id, Map<String, dynamic> m) => Task(
        id: id,
        title: (m['title'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        siteId: (m['siteId'] ?? '') as String,
        assigneeId: (m['assigneeId'] ?? '') as String,
        createdBy: (m['createdBy'] ?? '') as String,
        priority: TaskPriorityX.fromWire((m['priority'] ?? 'normal') as String),
        dueAt: (m['dueAt'] as Timestamp?)?.toDate(),
        status: TaskStatusX.fromWire((m['status'] ?? 'assigned') as String),
        report: TaskReport.fromMap(m['report'] as Map<String, dynamic>?),
      );
}
