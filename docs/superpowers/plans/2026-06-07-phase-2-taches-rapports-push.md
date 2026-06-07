# Phase 2 — Tâches + rapports + push FCM — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre aux managers de créer/assigner des tâches (mobile, en ligne), aux techniciens de les exécuter et rapporter (offline-first), notifier le technicien par push à l'assignation, et afficher les tâches en lecture seule au backoffice web.

**Architecture:** On étend les trois briques existantes sans en casser les patterns. Firestore gagne une collection `tasks` (rapport en sous-objet) ; le pointage hérite d'un `taskId`/`siteId`. L'outbox Drift est généralisé (`kind: punch|report`, migration schemaVersion 1→2) pour porter aussi les photos de rapport via le mécanisme de synchro déjà validé. Une Cloud Function v2 `onTaskAssigned` envoie le push FCM. Le web ajoute une page serveur en lecture seule.

**Tech Stack:** Flutter/Riverpod + Drift + cloud_firestore/firebase_storage/firebase_messaging ; Cloud Functions v2 (Node 22, firebase-functions ^5) ; Firestore/Storage rules ; Next.js 16 App Router + Firebase Admin.

**Spec :** `docs/superpowers/specs/2026-06-07-phase-2-taches-rapports-push-design.md`

**Ordre :** Firebase (règles + Function) → données mobile (modèle, outbox, repo, FCM) → UI mobile → web. Chaque tâche est rouge → vert → commit.

**Commandes de référence :**
- Mobile : `cd mobile && flutter test` / `flutter analyze` / `dart run build_runner build --delete-conflicting-outputs`
- Functions : `cd firebase/functions && npx jest`
- Règles : `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
- Web : `cd web && npx jest`

---

## File Structure

**firebase/**
- Modifier `firestore.rules` — bloc `tasks/{taskId}`.
- Modifier `storage.rules` — bloc `tasks/{taskId}/report/{file}`.
- Créer `functions/src/tasks/onTaskAssigned.ts` — trigger FCM + helpers purs testables.
- Modifier `functions/src/index.ts` — export du trigger.
- Créer `functions/test/onTaskAssigned.test.ts` — tests unitaires des helpers.
- Modifier `functions/test/rules.test.ts` — règles `tasks`.

**mobile/**
- Créer `lib/models/task.dart` — `Task`, `TaskStatus`, `TaskPriority`, `TaskReport`.
- Modifier `lib/models/punch.dart` — champ `taskId`.
- Modifier `lib/outbox/outbox_db.dart` — table `PendingUploads`, migration 1→2.
- Modifier `lib/outbox/outbox_uploader.dart` — routage `punch|report`.
- Créer `lib/tasks/task_repository.dart` — créer/streams/transitions/rapport.
- Créer `lib/notifications/fcm_service.dart` — enregistrement token.
- Créer `lib/tasks/tasks_list_screen.dart`, `task_detail_screen.dart`, `task_create_screen.dart`, `task_report_screen.dart`.
- Créer `lib/tasks/home_shell.dart` — navigation role-gatée.
- Modifier `lib/pointage/punch_repository.dart`, `lib/pointage/pointage_screen.dart` — sélection tâche active.
- Modifier `lib/auth/firebase_auth_gate.dart`, `lib/main.dart` — rôle + branchement tâches/FCM.
- Tests miroirs sous `mobile/test/`.

**web/**
- Créer `src/app/(dashboard)/tasks/page.tsx` — table lecture seule.
- Créer `src/lib/tasks.ts` — accès Admin + mapping.
- Créer test `web/__tests__/tasks.test.ts` (ou à côté, selon config jest).

---

## Task 1 : Règles Firestore — collection `tasks`

**Files:**
- Modify: `firebase/firestore.rules`
- Test: `firebase/functions/test/rules.test.ts`

- [ ] **Step 1 : Écrire les tests qui échouent (règles `tasks`)**

Ajouter ce `describe` à la fin de `firebase/functions/test/rules.test.ts` (avant la dernière `}`) :

```ts
describe("règles tasks", () => {
  const baseTask = {
    title: "Réparer", description: "", siteId: "s1",
    assigneeId: "tech_1", createdBy: "mgr", priority: "normal",
    dueAt: null, status: "assigned",
  };

  it("un manager peut créer une tâche dont il est createdBy", async () => {
    const db = ctx("mgr", "manager");
    await assertSucceeds(setDoc(doc(db, "tasks/t1"), baseTask));
  });

  it("un technicien ne peut PAS créer de tâche", async () => {
    const db = ctx("tech_1", "technician");
    await assertFails(setDoc(doc(db, "tasks/t2"), baseTask));
  });

  it("un manager ne peut PAS créer une tâche au nom d'un autre createdBy", async () => {
    const db = ctx("mgr", "manager");
    await assertFails(setDoc(doc(db, "tasks/t3"), { ...baseTask, createdBy: "autre" }));
  });

  it("l'assigné peut lire sa tâche", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t4"), baseTask));
    const db = ctx("tech_1", "technician");
    await assertSucceeds(getDoc(doc(db, "tasks/t4")));
  });

  it("un technicien non assigné ne peut PAS lire la tâche", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t5"), baseTask));
    const db = ctx("tech_2", "technician");
    await assertFails(getDoc(doc(db, "tasks/t5")));
  });

  it("l'assigné peut passer status à in_progress", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t6"), baseTask));
    const db = ctx("tech_1", "technician");
    await assertSucceeds(setDoc(doc(db, "tasks/t6"),
      { ...baseTask, status: "in_progress" }));
  });

  it("l'assigné ne peut PAS se réassigner la tâche", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t7"), baseTask));
    const db = ctx("tech_1", "technician");
    await assertFails(setDoc(doc(db, "tasks/t7"),
      { ...baseTask, assigneeId: "tech_1_autre" }));
  });
});
```

- [ ] **Step 2 : Lancer les tests, vérifier l'échec**

Run: `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected: FAIL — les nouveaux cas échouent (pas de bloc `tasks`, tout est refusé par le `match` par défaut absent → erreurs sur les cas `assertSucceeds`).

- [ ] **Step 3 : Ajouter le bloc `tasks` aux règles**

Dans `firebase/firestore.rules`, après le bloc `match /punches/{punchId} { ... }` et avant la `}` fermante du `match /databases/...`, insérer :

```
    match /tasks/{taskId} {
      // Champs que l'assigné a le droit de modifier (les autres doivent rester inchangés).
      function assigneeOnlyChangesAllowed() {
        return request.resource.data.diff(resource.data).affectedKeys()
                 .hasOnly(['status', 'report', 'updatedAt']);
      }

      allow create: if isManager()
                    && request.resource.data.createdBy == request.auth.uid;
      allow read:   if isManager() || resource.data.assigneeId == request.auth.uid;
      allow update: if isManager()
                    || (resource.data.assigneeId == request.auth.uid
                        && assigneeOnlyChangesAllowed());
      allow delete: if false;
    }
```

- [ ] **Step 4 : Lancer les tests, vérifier le succès**

Run: `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected: PASS — tous les cas `tasks` + les anciens cas `punches` passent.

- [ ] **Step 5 : Commit**

```bash
git add firebase/firestore.rules firebase/functions/test/rules.test.ts
git commit -m "feat(rules): regles Firestore collection tasks (create manager, update borne assigne)"
```

---

## Task 2 : Règles Storage — pièces jointes de rapport

**Files:**
- Modify: `firebase/storage.rules`

> Note : les règles Storage utilisant `firestore.get(...)` ne sont pas couvertes par les tests `@firebase/rules-unit-testing` du projet (pas d'émulateur Storage configuré). On valide par revue + test terrain. Garder la règle simple et conservatrice.

- [ ] **Step 1 : Ajouter le bloc report avant le catch-all**

Dans `firebase/storage.rules`, remplacer le bloc commentaire/catch-all final par :

```
    // Pièces jointes de rapport : `tasks/{taskId}/report/{fileName}`.
    // Écriture réservée à l'assigné de la tâche (vérifié via le doc Firestore) ;
    // lecture par tout utilisateur connecté (managers/admins consultent au backoffice).
    match /tasks/{taskId}/report/{fileName} {
      allow read: if isSignedIn();
      allow write: if isSignedIn()
        && request.resource.size < 10 * 1024 * 1024
        && firestore.get(/databases/(default)/documents/tasks/$(taskId)).data.assigneeId
           == request.auth.uid;
    }

    // Tout le reste reste verrouillé.
    match /{allPaths=**} {
      allow read, write: if false;
    }
```

- [ ] **Step 2 : Vérifier la syntaxe des règles**

Run: `cd firebase && firebase deploy --only storage --dry-run` *(si le `--dry-run` n'est pas dispo sur ta version, sauter et valider au déploiement réel plus tard)*
Expected: pas d'erreur de compilation des règles.

- [ ] **Step 3 : Commit**

```bash
git add firebase/storage.rules
git commit -m "feat(rules): Storage pieces jointes rapport reservees a l'assigne de la tache"
```

---

## Task 3 : Cloud Function `onTaskAssigned` — helpers purs (rouge/vert sans émulateur)

**Files:**
- Create: `firebase/functions/src/tasks/onTaskAssigned.ts`
- Create: `firebase/functions/test/onTaskAssigned.test.ts`

On sépare la logique pure (testable en jest pur, façon `buildTokenResponse`) du trigger v2.

- [ ] **Step 1 : Écrire les tests des helpers**

Créer `firebase/functions/test/onTaskAssigned.test.ts` :

```ts
import { buildAssignmentMessage, splitInvalidTokens } from "../src/tasks/onTaskAssigned";

describe("buildAssignmentMessage", () => {
  it("construit titre, corps et data avec le taskId", () => {
    const msg = buildAssignmentMessage("task_1", {
      title: "Changer disjoncteur", siteId: "s1", priority: "high",
    });
    expect(msg.notification.title).toBe("Nouvelle tâche : Changer disjoncteur");
    expect(msg.notification.body).toContain("s1");
    expect(msg.notification.body).toContain("high");
    expect(msg.data).toEqual({ taskId: "task_1" });
  });
});

describe("splitInvalidTokens", () => {
  it("sépare les tokens à supprimer selon les réponses d'envoi", () => {
    const tokens = ["tA", "tB", "tC"];
    const responses = [
      { success: true },
      { success: false, error: { code: "messaging/registration-token-not-registered" } },
      { success: false, error: { code: "messaging/internal-error" } },
    ];
    const { invalid } = splitInvalidTokens(tokens, responses as never);
    expect(invalid).toEqual(["tB"]); // pas tC (erreur transitoire, on garde)
  });
});
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd firebase/functions && npx jest onTaskAssigned`
Expected: FAIL — module introuvable.

- [ ] **Step 3 : Implémenter le module**

Créer `firebase/functions/src/tasks/onTaskAssigned.ts` :

```ts
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

interface TaskLite { title: string; siteId: string; priority: string; }

export function buildAssignmentMessage(taskId: string, task: TaskLite) {
  return {
    notification: {
      title: `Nouvelle tâche : ${task.title}`,
      body: `Site ${task.siteId} · priorité ${task.priority}`,
    },
    data: { taskId },
  };
}

interface SendResponse { success: boolean; error?: { code: string }; }

/** Sépare les tokens définitivement invalides (à retirer) des autres. */
export function splitInvalidTokens(tokens: string[], responses: SendResponse[]) {
  const invalid: string[] = [];
  responses.forEach((r, i) => {
    const code = r.error?.code;
    if (!r.success &&
        (code === "messaging/registration-token-not-registered" ||
         code === "messaging/invalid-registration-token")) {
      invalid.push(tokens[i]);
    }
  });
  return { invalid };
}

export const onTaskAssigned = onDocumentCreated("tasks/{taskId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const task = snap.data() as TaskLite & { assigneeId: string };
  const taskId = event.params.taskId;

  const userSnap = await admin.firestore().doc(`users/${task.assigneeId}`).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];
  if (tokens.length === 0) return;

  const message = buildAssignmentMessage(taskId, task);
  const res = await admin.messaging().sendEachForMulticast({
    tokens, notification: message.notification, data: message.data,
  });

  const { invalid } = splitInvalidTokens(tokens, res.responses as never);
  if (invalid.length > 0) {
    await admin.firestore().doc(`users/${task.assigneeId}`).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
    });
  }
});
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd firebase/functions && npx jest onTaskAssigned`
Expected: PASS — les deux tests passent.

- [ ] **Step 5 : Exporter le trigger**

Modifier `firebase/functions/src/index.ts` :

```ts
import * as admin from "firebase-admin";
admin.initializeApp();

export { mintFirebaseToken } from "./auth/mintFirebaseToken";
export { onTaskAssigned } from "./tasks/onTaskAssigned";
```

- [ ] **Step 6 : Vérifier la compilation TypeScript**

Run: `cd firebase/functions && npx tsc --noEmit`
Expected: pas d'erreur.

- [ ] **Step 7 : Commit**

```bash
git add firebase/functions/src/tasks/onTaskAssigned.ts firebase/functions/test/onTaskAssigned.test.ts firebase/functions/src/index.ts
git commit -m "feat(functions): push FCM a l'assignation d'une tache + purge tokens invalides"
```

---

## Task 4 : Modèle `Task` (mobile)

**Files:**
- Create: `mobile/lib/models/task.dart`
- Test: `mobile/test/task_test.dart`

- [ ] **Step 1 : Écrire les tests de sérialisation**

Créer `mobile/test/task_test.dart` :

```dart
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
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/task_test.dart`
Expected: FAIL — `task.dart` introuvable.

- [ ] **Step 3 : Implémenter le modèle**

Créer `mobile/lib/models/task.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { assigned, inProgress, done }
extension TaskStatusX on TaskStatus {
  String get wire => switch (this) {
        TaskStatus.assigned => 'assigned',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
      };
  static TaskStatus fromWire(String w) => switch (w) {
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
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
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/task_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/models/task.dart mobile/test/task_test.dart
git commit -m "feat(mobile): modele Task + TaskReport (serialisation Firestore)"
```

---

## Task 5 : Généraliser l'outbox Drift (`PendingUploads`, migration 1→2)

**Files:**
- Modify: `mobile/lib/outbox/outbox_db.dart`
- Regenerate: `mobile/lib/outbox/outbox_db.g.dart` (build_runner)
- Test: `mobile/test/outbox_db_test.dart`

> Risque clé (cf. spec) : ne pas perdre les uploads en attente lors de la mise à jour de l'app. On expose les étapes SQL de migration comme constante, utilisée par `onUpgrade` ET par le test.

- [ ] **Step 1 : Réécrire les tests outbox (kinds + migration)**

Remplacer le contenu de `mobile/test/outbox_db_test.dart` par :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/outbox_db.dart';

void main() {
  late OutboxDb db;
  setUp(() => db = OutboxDb.memory());
  tearDown(() => db.close());

  test('enqueuePunch puis pending retourne un upload kind=punch', () async {
    await db.enqueuePunch('p1', '/tmp/p1.jpg');
    final items = await db.pending();
    expect(items.length, 1);
    expect(items.first.kind, 'punch');
    expect(items.first.ownerId, 'p1');
    expect(items.first.localPath, '/tmp/p1.jpg');
  });

  test('enqueueReport accepte plusieurs photos pour la même tâche', () async {
    await db.enqueueReport('task_1', '/tmp/a.jpg');
    await db.enqueueReport('task_1', '/tmp/b.jpg');
    final items = await db.pending();
    expect(items.where((i) => i.kind == 'report' && i.ownerId == 'task_1').length, 2);
  });

  test('removeById vide une ligne précise', () async {
    await db.enqueuePunch('p1', '/tmp/p1.jpg');
    final id = (await db.pending()).first.id;
    await db.removeById(id);
    expect(await db.count(), 0);
  });

  test('bumpAttemptsById incrémente', () async {
    await db.enqueuePunch('p1', '/tmp/p1.jpg');
    final id = (await db.pending()).first.id;
    await db.bumpAttemptsById(id);
    expect((await db.pending()).first.attempts, 1);
  });

  test('migration v1→v2 copie les pending_photos en uploads kind=punch', () async {
    // Reconstruit l'état v1 puis rejoue les étapes de migration exposées.
    await db.customStatement('DROP TABLE pending_uploads');
    await db.customStatement(
      'CREATE TABLE pending_photos (punch_id TEXT NOT NULL PRIMARY KEY, '
      'local_path TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0)');
    await db.customStatement(
      "INSERT INTO pending_photos (punch_id, local_path, attempts) "
      "VALUES ('p9', '/tmp/p9.jpg', 3)");
    for (final stmt in migrationV1toV2Sql) {
      await db.customStatement(stmt);
    }
    final rows = await db.pending();
    expect(rows.single.kind, 'punch');
    expect(rows.single.ownerId, 'p9');
    expect(rows.single.attempts, 3);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/outbox_db_test.dart`
Expected: FAIL — `enqueuePunch`/`pending().kind`/`migrationV1toV2Sql` n'existent pas.

- [ ] **Step 3 : Réécrire `outbox_db.dart`**

Remplacer le contenu de `mobile/lib/outbox/outbox_db.dart` par :

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'outbox_db.g.dart';

/// File d'attente générique d'uploads (photos) à synchroniser.
/// `kind` ∈ {'punch','report'} ; `ownerId` = punchId ou taskId.
class PendingUploads extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get ownerId => text()();
  TextColumn get localPath => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

/// Étapes SQL de migration v1→v2 (exposées pour être testées et rejouées).
const List<String> migrationV1toV2Sql = [
  'CREATE TABLE pending_uploads (id TEXT NOT NULL PRIMARY KEY, '
      'kind TEXT NOT NULL, owner_id TEXT NOT NULL, '
      'local_path TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0)',
  "INSERT INTO pending_uploads (id, kind, owner_id, local_path, attempts) "
      "SELECT punch_id, 'punch', punch_id, local_path, attempts FROM pending_photos",
  'DROP TABLE pending_photos',
];

@DriftDatabase(tables: [PendingUploads])
class OutboxDb extends _$OutboxDb {
  OutboxDb(super.e);
  factory OutboxDb.memory() => OutboxDb(NativeDatabase.memory());

  factory OutboxDb.open() {
    return OutboxDb(LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase(File(p.join(dir.path, 'outbox.sqlite')));
    }));
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from == 1) {
            for (final stmt in migrationV1toV2Sql) {
              await customStatement(stmt);
            }
          }
        },
      );

  String _uuid() => '${DateTime.now().microsecondsSinceEpoch}-${pendingUploads.hashCode}';

  /// Une photo de pointage : id stable = punchId (ré-enfiler écrase).
  Future<void> enqueuePunch(String punchId, String localPath) =>
      into(pendingUploads).insertOnConflictUpdate(PendingUpload(
          id: punchId, kind: 'punch', ownerId: punchId,
          localPath: localPath, attempts: 0));

  /// Une photo de rapport : id unique (plusieurs photos par tâche).
  Future<void> enqueueReport(String taskId, String localPath) =>
      into(pendingUploads).insert(PendingUpload(
          id: _uuid(), kind: 'report', ownerId: taskId,
          localPath: localPath, attempts: 0));

  Future<List<PendingUpload>> pending() => select(pendingUploads).get();

  Future<void> removeById(String id) =>
      (delete(pendingUploads)..where((t) => t.id.equals(id))).go();

  Future<void> bumpAttemptsById(String id) async {
    final row = await (select(pendingUploads)..where((t) => t.id.equals(id))).getSingle();
    await (update(pendingUploads)..where((t) => t.id.equals(id)))
        .write(PendingUploadsCompanion(attempts: Value(row.attempts + 1)));
  }

  Future<int> count() async => (await select(pendingUploads).get()).length;

  Stream<int> pendingCountStream() =>
      select(pendingUploads).watch().map((rows) => rows.length);
}
```

- [ ] **Step 4 : Régénérer le code Drift**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: `outbox_db.g.dart` régénéré sans erreur, classe `PendingUpload` + `PendingUploadsCompanion` générées.

- [ ] **Step 5 : Lancer les tests outbox, vérifier le succès**

Run: `cd mobile && flutter test test/outbox_db_test.dart`
Expected: PASS — kinds, multi-report, removeById, bumpAttemptsById, migration.

- [ ] **Step 6 : Commit**

```bash
git add mobile/lib/outbox/outbox_db.dart mobile/lib/outbox/outbox_db.g.dart mobile/test/outbox_db_test.dart
git commit -m "feat(mobile): outbox generique PendingUploads (kind punch|report) + migration Drift 1->2"
```

---

## Task 6 : Routage de l'`OutboxUploader` (punch vs report)

**Files:**
- Modify: `mobile/lib/outbox/outbox_uploader.dart`
- Test: `mobile/test/outbox_uploader_test.dart`

- [ ] **Step 1 : Réécrire les tests uploader**

Remplacer le contenu de `mobile/test/outbox_uploader_test.dart` par :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/outbox/outbox_uploader.dart';

void main() {
  test('drain upload une photo de pointage et patche le punch', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending'});
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, path) async => 'https://storage/$ownerId.jpg');
    await uploader.drainOnce();

    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'uploaded');
    expect(doc.data()!['photoUrl'], 'https://storage/p1.jpg');
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('drain upload une photo de rapport et arrayUnion sur report.photoUrls', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('tasks').doc('t1').set({
      'status': 'done',
      'report': {'text': 'fait', 'photoUrls': <String>[], 'photoCount': 1},
    });
    await outbox.enqueueReport('t1', '/tmp/a.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (kind, ownerId, path) async => 'https://storage/$ownerId/a.jpg');
    await uploader.drainOnce();

    final doc = await fs.collection('tasks').doc('t1').get();
    final report = doc.data()!['report'] as Map<String, dynamic>;
    expect(report['photoUrls'], contains('https://storage/t1/a.jpg'));
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('un upload qui échoue bumpAttempts et garde l\'élément', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await outbox.enqueuePunch('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(fs, outbox,
        uploadFn: (_, __, ___) async => throw Exception('réseau'));
    await uploader.drainOnce();

    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    await outbox.close();
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/outbox_uploader_test.dart`
Expected: FAIL — signature `uploadFn` changée, méthodes outbox renommées.

- [ ] **Step 3 : Réécrire `outbox_uploader.dart`**

Remplacer le contenu de `mobile/lib/outbox/outbox_uploader.dart` par :

```dart
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
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/outbox_uploader_test.dart`
Expected: PASS — punch, report (arrayUnion), échec/bump.

- [ ] **Step 5 : Adapter l'appelant `punch_repository.dart`**

Dans `mobile/lib/pointage/punch_repository.dart`, remplacer l'appel `_outbox.enqueue(ref.id, photoPath)` par `_outbox.enqueuePunch(ref.id, photoPath)`.

- [ ] **Step 6 : Mettre à jour `punch_repository_test.dart`**

Dans `mobile/test/punch_repository_test.dart`, remplacer l'assertion outbox par :

```dart
    final pending = await outbox.pending();
    expect(pending.single.ownerId, id);
    expect(pending.single.kind, 'punch');
    expect(pending.single.localPath, '/tmp/a.jpg');
```

- [ ] **Step 7 : Lancer toute la suite mobile**

Run: `cd mobile && flutter test`
Expected: PASS — toute la suite verte (les anciens tests punch passent avec la nouvelle outbox).

- [ ] **Step 8 : Commit**

```bash
git add mobile/lib/outbox/outbox_uploader.dart mobile/lib/pointage/punch_repository.dart mobile/test/outbox_uploader_test.dart mobile/test/punch_repository_test.dart
git commit -m "feat(mobile): uploader route punch/report (Storage + arrayUnion report.photoUrls)"
```

---

## Task 7 : `TaskRepository` (créer, streams, transitions, rapport)

**Files:**
- Create: `mobile/lib/tasks/task_repository.dart`
- Test: `mobile/test/task_repository_test.dart`

- [ ] **Step 1 : Écrire les tests du repository**

Créer `mobile/test/task_repository_test.dart` :

```dart
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
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/task_repository_test.dart`
Expected: FAIL — `task_repository.dart` introuvable.

- [ ] **Step 3 : Implémenter le repository**

Créer `mobile/lib/tasks/task_repository.dart` :

```dart
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
      {'status': TaskStatus.done.wire, 'report': report.toMap(),
       'updatedAt': FieldValue.serverTimestamp()},
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
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/task_repository_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/task_repository.dart mobile/test/task_repository_test.dart
git commit -m "feat(mobile): TaskRepository (creer, start, submitReport offline, streams role)"
```

---

## Task 8 : `FcmService` (enregistrement du token)

**Files:**
- Create: `mobile/lib/notifications/fcm_service.dart`
- Test: `mobile/test/fcm_service_test.dart`

On rend la **logique d'enregistrement du token** testable indépendamment du plugin natif : `FcmService` reçoit le token (string) et écrit dans Firestore. L'obtention réelle du token (permission, `getToken`) reste un wrapper fin non testé en unitaire.

- [ ] **Step 1 : Écrire le test d'enregistrement**

Créer `mobile/test/fcm_service_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/notifications/fcm_service.dart';

void main() {
  test('registerToken ajoute le token dans users/{uid}.fcmTokens (arrayUnion)', () async {
    final fs = FakeFirebaseFirestore();
    final svc = FcmService(fs);

    await svc.registerToken('user_1', 'tok_abc');

    final doc = await fs.collection('users').doc('user_1').get();
    expect(List<String>.from(doc.data()!['fcmTokens']), contains('tok_abc'));
  });

  test('registerToken est idempotent (pas de doublon)', () async {
    final fs = FakeFirebaseFirestore();
    final svc = FcmService(fs);

    await svc.registerToken('user_1', 'tok_abc');
    await svc.registerToken('user_1', 'tok_abc');

    final doc = await fs.collection('users').doc('user_1').get();
    expect(List<String>.from(doc.data()!['fcmTokens']).length, 1);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/fcm_service_test.dart`
Expected: FAIL — `fcm_service.dart` introuvable.

- [ ] **Step 3 : Implémenter le service**

Créer `mobile/lib/notifications/fcm_service.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Enregistre/maintient le token FCM de l'utilisateur dans Firestore.
class FcmService {
  FcmService(this._fs, [FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;
  final FirebaseFirestore _fs;
  final FirebaseMessaging _messaging;

  /// Écrit le token (idempotent via arrayUnion).
  Future<void> registerToken(String userId, String token) =>
      _fs.collection('users').doc(userId).set(
        {'fcmTokens': FieldValue.arrayUnion([token])},
        SetOptions(merge: true),
      );

  /// À appeler après le pont auth Firebase : demande la permission,
  /// récupère le token et l'enregistre, puis suit les rotations de token.
  Future<void> start(String userId) async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) await registerToken(userId, token);
    _messaging.onTokenRefresh.listen((t) => registerToken(userId, t));
  }
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/fcm_service_test.dart`
Expected: PASS.

- [ ] **Step 5 : Vérifier la dépendance `firebase_messaging`**

Run: `cd mobile && flutter pub add firebase_messaging`
Expected: ajout dans `pubspec.yaml`. Puis `flutter pub get`.
*(Si déjà présent, sauter.)*

- [ ] **Step 6 : Commit**

```bash
git add mobile/lib/notifications/fcm_service.dart mobile/test/fcm_service_test.dart mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(mobile): FcmService enregistre le token FCM (arrayUnion idempotent)"
```

---

## Task 9 : Navigation role-gatée + extraction du rôle

**Files:**
- Create: `mobile/lib/tasks/home_shell.dart`
- Test: `mobile/test/home_shell_test.dart`

Le rôle est dans le custom claim Firebase (posé par `mintFirebaseToken`). On l'extrait via `user.getIdTokenResult()`. `HomeShell` reçoit le `role` (string) et choisit l'onglet/écran.

- [ ] **Step 1 : Écrire le test de gating**

Créer `mobile/test/home_shell_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/tasks/home_shell.dart';

void main() {
  testWidgets('un manager voit "Tâches créées" et le bouton Créer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        role: 'manager', userId: 'mgr',
        pointageTab: const Text('POINTAGE'),
        myTasksTab: const Text('MES_TACHES'),
        managerTasksTab: const Text('TACHES_CREEES'),
      ),
    ));
    expect(find.text('TACHES_CREEES'), findsOneWidget);
    expect(find.text('POINTAGE'), findsNothing);
  });

  testWidgets('un technicien voit Pointage + Mes tâches', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        role: 'technician', userId: 'tech_1',
        pointageTab: const Text('POINTAGE'),
        myTasksTab: const Text('MES_TACHES'),
        managerTasksTab: const Text('TACHES_CREEES'),
      ),
    ));
    expect(find.text('POINTAGE'), findsOneWidget);
    expect(find.text('TACHES_CREEES'), findsNothing);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/home_shell_test.dart`
Expected: FAIL — `home_shell.dart` introuvable.

- [ ] **Step 3 : Implémenter `HomeShell`**

Créer `mobile/lib/tasks/home_shell.dart` :

```dart
import 'package:flutter/material.dart';

/// Coquille de navigation role-gatée. Reçoit les onglets déjà construits
/// (injection = testable sans Firebase) et choisit selon le rôle.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key, required this.role, required this.userId,
    required this.pointageTab, required this.myTasksTab, required this.managerTasksTab,
  });
  final String role;
  final String userId;
  final Widget pointageTab, myTasksTab, managerTasksTab;

  bool get isManager => role == 'manager' || role == 'admin';

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = widget.isManager
        ? [widget.managerTasksTab]
        : [widget.pointageTab, widget.myTasksTab];
    final dests = widget.isManager
        ? const [NavigationDestination(icon: Icon(Icons.assignment), label: 'Tâches')]
        : const [
            NavigationDestination(icon: Icon(Icons.access_time), label: 'Pointage'),
            NavigationDestination(icon: Icon(Icons.checklist), label: 'Mes tâches'),
          ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: dests.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: dests,
            ),
    );
  }
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/home_shell_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/home_shell.dart mobile/test/home_shell_test.dart
git commit -m "feat(mobile): HomeShell navigation role-gatee (manager vs technicien)"
```

---

## Task 10 : Écran liste des tâches (`tasks_list_screen.dart`)

**Files:**
- Create: `mobile/lib/tasks/tasks_list_screen.dart`
- Test: `mobile/test/tasks_list_screen_test.dart`

- [ ] **Step 1 : Écrire le test (rendu d'une liste de tâches)**

Créer `mobile/test/tasks_list_screen_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/tasks/tasks_list_screen.dart';

Task _task(String id, String title, TaskStatus s) => Task(
      id: id, title: title, description: '', siteId: 's1',
      assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.normal,
      dueAt: null, status: s, report: null,
    );

void main() {
  testWidgets('affiche le titre et le statut de chaque tâche', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TasksListScreen(
        title: 'Mes tâches',
        tasks: Stream.value([_task('t1', 'Réparer', TaskStatus.assigned)]),
        onTapTask: (_) {},
      ),
    ));
    await tester.pump();
    expect(find.text('Réparer'), findsOneWidget);
    expect(find.textContaining('assigné'), findsOneWidget);
  });

  testWidgets('affiche le bouton Créer si onCreate fourni', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TasksListScreen(
        title: 'Tâches créées',
        tasks: Stream.value(const []),
        onTapTask: (_) {},
        onCreate: () {},
      ),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/tasks_list_screen_test.dart`
Expected: FAIL — `tasks_list_screen.dart` introuvable.

- [ ] **Step 3 : Implémenter l'écran**

Créer `mobile/lib/tasks/tasks_list_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';

String statusLabel(TaskStatus s) => switch (s) {
      TaskStatus.assigned => 'assigné',
      TaskStatus.inProgress => 'en cours',
      TaskStatus.done => 'terminé',
    };

class TasksListScreen extends StatelessWidget {
  const TasksListScreen({
    super.key, required this.title, required this.tasks, required this.onTapTask,
    this.onCreate,
  });
  final String title;
  final Stream<List<Task>> tasks;
  final void Function(Task) onTapTask;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: onCreate == null
          ? null
          : FloatingActionButton(onPressed: onCreate, child: const Icon(Icons.add)),
      body: StreamBuilder<List<Task>>(
        stream: tasks,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Aucune tâche.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return ListTile(
                title: Text(t.title),
                subtitle: Text('${statusLabel(t.status)} · ${t.priority.name}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTapTask(t),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/tasks_list_screen_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/tasks_list_screen.dart mobile/test/tasks_list_screen_test.dart
git commit -m "feat(mobile): TasksListScreen (stream, statut, bouton creer optionnel)"
```

---

## Task 11 : Écran détail + actions de statut (`task_detail_screen.dart`)

**Files:**
- Create: `mobile/lib/tasks/task_detail_screen.dart`
- Test: `mobile/test/task_detail_screen_test.dart`

- [ ] **Step 1 : Écrire le test (boutons conditionnels au statut)**

Créer `mobile/test/task_detail_screen_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/tasks/task_detail_screen.dart';

Task _task(TaskStatus s) => Task(
      id: 't1', title: 'Réparer', description: 'détail', siteId: 's1',
      assigneeId: 'tech_1', createdBy: 'mgr', priority: TaskPriority.normal,
      dueAt: null, status: s, report: null,
    );

void main() {
  testWidgets('statut assigned : bouton Démarrer visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskDetailScreen(task: _task(TaskStatus.assigned),
          onStart: () {}, onClose: () {}),
    ));
    expect(find.text('Démarrer'), findsOneWidget);
    expect(find.text('Clôturer'), findsNothing);
  });

  testWidgets('statut in_progress : bouton Clôturer visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskDetailScreen(task: _task(TaskStatus.inProgress),
          onStart: () {}, onClose: () {}),
    ));
    expect(find.text('Clôturer'), findsOneWidget);
    expect(find.text('Démarrer'), findsNothing);
  });

  testWidgets('statut done : aucune action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskDetailScreen(task: _task(TaskStatus.done),
          onStart: () {}, onClose: () {}),
    ));
    expect(find.text('Démarrer'), findsNothing);
    expect(find.text('Clôturer'), findsNothing);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/task_detail_screen_test.dart`
Expected: FAIL — `task_detail_screen.dart` introuvable.

- [ ] **Step 3 : Implémenter l'écran**

Créer `mobile/lib/tasks/task_detail_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import 'tasks_list_screen.dart' show statusLabel;

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key, required this.task, required this.onStart, required this.onClose,
  });
  final Task task;
  final VoidCallback onStart; // assigned → in_progress
  final VoidCallback onClose; // ouvre le formulaire rapport

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Statut : ${statusLabel(task.status)}'),
          const SizedBox(height: 8),
          Text('Priorité : ${task.priority.name}'),
          const SizedBox(height: 16),
          Text(task.description),
          const Spacer(),
          if (task.status == TaskStatus.assigned)
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow), label: const Text('Démarrer')),
          if (task.status == TaskStatus.inProgress)
            ElevatedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.check), label: const Text('Clôturer')),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/task_detail_screen_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/task_detail_screen.dart mobile/test/task_detail_screen_test.dart
git commit -m "feat(mobile): TaskDetailScreen avec actions conditionnees au statut"
```

---

## Task 12 : Formulaire de rapport (`task_report_screen.dart`)

**Files:**
- Create: `mobile/lib/tasks/task_report_screen.dart`
- Test: `mobile/test/task_report_screen_test.dart`

L'écran récolte texte + minutes + photos, puis appelle un callback `onSubmit(text, minutes, photoPaths)`. La prise de photo réelle est injectée (`pickPhoto`) → testable.

- [ ] **Step 1 : Écrire le test (soumission)**

Créer `mobile/test/task_report_screen_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/tasks/task_report_screen.dart';

void main() {
  testWidgets('soumet texte, minutes et photos collectées', (tester) async {
    String? gotText;
    int? gotMinutes;
    List<String>? gotPhotos;

    await tester.pumpWidget(MaterialApp(
      home: TaskReportScreen(
        pickPhoto: () async => '/tmp/photo.jpg',
        onSubmit: (text, minutes, photos) async {
          gotText = text; gotMinutes = minutes; gotPhotos = photos;
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('report_text')), 'travail fait');
    await tester.enterText(find.byKey(const Key('report_minutes')), '90');
    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_report')));
    await tester.pump();

    expect(gotText, 'travail fait');
    expect(gotMinutes, 90);
    expect(gotPhotos, ['/tmp/photo.jpg']);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/task_report_screen_test.dart`
Expected: FAIL — `task_report_screen.dart` introuvable.

- [ ] **Step 3 : Implémenter l'écran**

Créer `mobile/lib/tasks/task_report_screen.dart` :

```dart
import 'package:flutter/material.dart';

class TaskReportScreen extends StatefulWidget {
  const TaskReportScreen({super.key, required this.pickPhoto, required this.onSubmit});
  final Future<String?> Function() pickPhoto;
  final Future<void> Function(String text, int minutes, List<String> photoPaths) onSubmit;

  @override
  State<TaskReportScreen> createState() => _TaskReportScreenState();
}

class _TaskReportScreenState extends State<TaskReportScreen> {
  final _text = TextEditingController();
  final _minutes = TextEditingController();
  final List<String> _photos = [];
  bool _busy = false;

  Future<void> _addPhoto() async {
    final path = await widget.pickPhoto();
    if (path != null) setState(() => _photos.add(path));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.onSubmit(_text.text, int.tryParse(_minutes.text) ?? 0, List.of(_photos));
    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          TextField(
            key: const Key('report_text'),
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Compte-rendu'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('report_minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Temps passé (minutes)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('add_photo'),
            onPressed: _busy ? null : _addPhoto,
            icon: const Icon(Icons.photo_camera),
            label: Text('Ajouter une photo (${_photos.length})'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('submit_report'),
            onPressed: _busy ? null : _submit,
            child: const Text('Envoyer le rapport'),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/task_report_screen_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/task_report_screen.dart mobile/test/task_report_screen_test.dart
git commit -m "feat(mobile): TaskReportScreen (texte + minutes + photos, callback onSubmit)"
```

---

## Task 13 : Sélecteur de tâche active au pointage (héritage `siteId`)

**Files:**
- Modify: `mobile/lib/models/punch.dart`
- Modify: `mobile/lib/pointage/punch_repository.dart`
- Modify: `mobile/lib/pointage/pointage_screen.dart`
- Test: `mobile/test/punch_test.dart`, `mobile/test/punch_repository_test.dart`, `mobile/test/pointage_screen_test.dart`

- [ ] **Step 1 : Étendre le test du modèle Punch**

Dans `mobile/test/punch_test.dart`, ajouter un test (ou adapter l'existant) vérifiant le champ `taskId`. Ajouter dans le `main()` :

```dart
  test('toFirestore inclut taskId quand fourni', () {
    final p = Punch(
      id: 'p1', userId: 'u1', kind: PunchKind.checkIn,
      clientTimestamp: DateTime.utc(2026, 6, 7), lat: 4, lng: 9, accuracy: 5,
      siteId: 's1', photoStatus: PhotoStatus.pending, taskId: 't1',
    );
    expect(p.toFirestore()['taskId'], 't1');
    expect(p.toFirestore()['siteId'], 's1');
  });
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/punch_test.dart`
Expected: FAIL — paramètre `taskId` inconnu de `Punch`.

- [ ] **Step 3 : Ajouter `taskId` au modèle Punch**

Dans `mobile/lib/models/punch.dart` : ajouter le champ et le sérialiser.
- Dans le constructeur : ajouter `this.taskId,` (après `this.photoUrl,`).
- Dans les champs : ajouter `final String? taskId;`
- Dans `toFirestore()` : ajouter, après la ligne `'siteId': siteId,` :
```dart
        if (taskId != null) 'taskId': taskId,
```

- [ ] **Step 4 : Lancer le test modèle, vérifier le succès**

Run: `cd mobile && flutter test test/punch_test.dart`
Expected: PASS.

- [ ] **Step 5 : Étendre `createPunch` avec `taskId`**

Dans `mobile/lib/pointage/punch_repository.dart` :
- Ajouter le paramètre `String? taskId,` à la signature de `createPunch` (après `required String photoPath,`).
- Passer `taskId: taskId,` au constructeur `Punch(...)`.

- [ ] **Step 6 : Étendre le test repository**

Dans `mobile/test/punch_repository_test.dart`, ajouter un test :

```dart
  test('createPunch enregistre le taskId fourni', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    final repo = PunchRepository(fs, outbox);
    final id = await repo.createPunch(
      userId: 'u1', kind: PunchKind.checkIn,
      lat: 4, lng: 9, accuracy: 10, siteId: 's1',
      photoPath: '/tmp/a.jpg', taskId: 't1');
    final doc = await fs.collection('punches').doc(id).get();
    expect(doc.data()!['taskId'], 't1');
    expect(doc.data()!['siteId'], 's1');
    await outbox.close();
  });
```

- [ ] **Step 7 : Adapter `PointageScreen` pour la tâche active**

Dans `mobile/lib/pointage/pointage_screen.dart` :
- Ajouter au constructeur/champs une liste de tâches `in_progress` sélectionnables et le site associé :
```dart
  final List<({String taskId, String siteId, String title})> activeTasks;
```
  (paramètre `this.activeTasks = const [],` dans le constructeur).
- Ajouter un état `String? _selectedTaskId; String? _selectedSiteId;`
- Dans `initState`, pré-sélectionner si une seule tâche : 
```dart
  @override
  void initState() {
    super.initState();
    if (widget.activeTasks.length == 1) {
      _selectedTaskId = widget.activeTasks.first.taskId;
      _selectedSiteId = widget.activeTasks.first.siteId;
    }
  }
```
- Ajouter un `DropdownButton` (clé `Key('task_picker')`) au-dessus des boutons quand `activeTasks.length > 1`, mettant à jour `_selectedTaskId`/`_selectedSiteId`.
- Dans `_punch`, remplacer `siteId: null` par `siteId: _selectedSiteId,` et ajouter `taskId: _selectedTaskId,`.

- [ ] **Step 8 : Étendre le test de l'écran de pointage**

Créer/ajouter dans `mobile/test/pointage_screen_test.dart` un test du sélecteur — ajouter au `main()` existant :

```dart
  testWidgets('pré-sélectionne la tâche quand il n\'y en a qu\'une', (tester) async {
    // Smoke test : l'écran se construit avec une tâche active sans afficher de dropdown.
    await tester.pumpWidget(MaterialApp(
      home: PointageScreen(
        userId: 'u1', geo: GeoService(), photo: PhotoService(),
        repo: PunchRepository(FakeFirebaseFirestore(), OutboxDb.memory()),
        pendingCount: 0,
        activeTasks: const [(taskId: 't1', siteId: 's1', title: 'Réparer')],
      ),
    ));
    expect(find.byKey(const Key('task_picker')), findsNothing); // pas de choix si une seule
  });
```

Ajouter les imports nécessaires en tête du fichier de test :
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/models/punch.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/pointage/geo_service.dart';
import 'package:pointage/pointage/photo_service.dart';
import 'package:pointage/pointage/punch_repository.dart';
import 'package:pointage/pointage/pointage_screen.dart';
```

- [ ] **Step 9 : Lancer toute la suite mobile**

Run: `cd mobile && flutter test`
Expected: PASS — modèle, repo, écran de pointage, le reste inchangé.

- [ ] **Step 10 : Commit**

```bash
git add mobile/lib/models/punch.dart mobile/lib/pointage/punch_repository.dart mobile/lib/pointage/pointage_screen.dart mobile/test/punch_test.dart mobile/test/punch_repository_test.dart mobile/test/pointage_screen_test.dart
git commit -m "feat(mobile): pointage rattache a la tache active (herite siteId + taskId)"
```

---

## Task 14 : Câblage applicatif (rôle, FCM, écrans tâches) dans `main.dart` / `firebase_auth_gate.dart`

**Files:**
- Modify: `mobile/lib/auth/firebase_auth_gate.dart`
- Modify: `mobile/lib/main.dart`

> Câblage d'intégration (pas de nouveau test unitaire : validé par `flutter analyze` + parcours appareil). On branche : extraction du rôle, démarrage FCM, et la navigation `HomeShell` avec les écrans tâches alimentés par `TaskRepository`.

- [ ] **Step 1 : Construire les providers et l'app**

Dans `mobile/lib/main.dart` :
- Importer `tasks/task_repository.dart`, `notifications/fcm_service.dart`.
- Construire `final taskRepo = TaskRepository(fs, outbox);` et `final fcm = FcmService(fs);` dans `main()`.
- Passer `taskRepo` et `fcm` à `PointageApp` (nouveaux champs `final TaskRepository taskRepo;` / `final FcmService fcm;`), puis à `FirebaseAuthGate`.

- [ ] **Step 2 : Extraire le rôle et démarrer FCM dans la passerelle**

Dans `mobile/lib/auth/firebase_auth_gate.dart` :
- Ajouter les champs `final TaskRepository taskRepo;` et `final FcmService fcm;` (+ au constructeur).
- Après obtention du `user` (dans le `StreamBuilder<User?>`), récupérer le rôle de façon asynchrone :
```dart
  Future<String> _role(User user) async {
    final res = await user.getIdTokenResult();
    return (res.claims?['role'] as String?) ?? 'technician';
  }
```
- Envelopper le rendu dans un `FutureBuilder<String>(future: _role(user), ...)`. Au premier build avec le rôle connu, démarrer FCM une seule fois : `widget.fcm.start(user.uid);` (garder un booléen `_fcmStarted`).
- Construire `HomeShell` :
```dart
  HomeShell(
    role: role, userId: user.uid,
    pointageTab: PointageScreen(
      userId: user.uid, geo: GeoService(), photo: PhotoService(),
      repo: widget.repo, pendingCount: pendingSnap.data ?? 0,
      onPunchCreated: widget.onSyncNow, onSignOut: _signOut,
      activeTasks: const [], // alimenté plus tard via un stream des tâches in_progress
    ),
    myTasksTab: TasksListScreen(
      title: 'Mes tâches',
      tasks: widget.taskRepo.tasksForAssignee(user.uid),
      onTapTask: (t) => _openTask(context, t),
    ),
    managerTasksTab: TasksListScreen(
      title: 'Tâches créées',
      tasks: widget.taskRepo.tasksCreatedBy(user.uid),
      onTapTask: (t) => _openTask(context, t),
      onCreate: () => _openCreate(context, user.uid),
    ),
  )
```
- Ajouter les méthodes de navigation `_openTask` (push `TaskDetailScreen` avec `onStart: () => widget.taskRepo.startTask(t.id)` et `onClose:` → push `TaskReportScreen` avec `onSubmit:` → `widget.taskRepo.submitReport(...)` puis `widget.onSyncNow()`), et `_openCreate` (push `TaskCreateScreen`, créé en Task 15).

  > À ce stade, `TaskCreateScreen` n'existe pas encore : commenter le bouton créer (`onCreate`) ou laisser un `TODO`-libre **non** — préférer faire la Task 15 avant de compiler ce câblage. Ordre conseillé : implémenter Task 15, puis revenir compiler Task 14. (Les deux peuvent être commitées ensemble.)

- [ ] **Step 3 : Vérifier l'analyse statique (après Task 15)**

Run: `cd mobile && flutter analyze`
Expected: pas d'erreur (warnings de style tolérés s'ils suivent le code existant).

- [ ] **Step 4 : Commit (conjoint avec Task 15)**

```bash
git add mobile/lib/main.dart mobile/lib/auth/firebase_auth_gate.dart
git commit -m "feat(mobile): cablage role + FCM + navigation taches dans la passerelle auth"
```

---

## Task 15 : Écran de création de tâche (manager, en ligne)

**Files:**
- Create: `mobile/lib/tasks/task_create_screen.dart`
- Test: `mobile/test/task_create_screen_test.dart`

L'écran reçoit la liste des sites et des techniciens (injectés), valide les champs, et appelle `onCreate(...)`. Le manager doit être en ligne : si `online == false`, on bloque avec un message (online injecté pour le test).

- [ ] **Step 1 : Écrire le test (validation + soumission + garde en ligne)**

Créer `mobile/test/task_create_screen_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/tasks/task_create_screen.dart';

void main() {
  final sites = const [(id: 's1', name: 'Site A')];
  final techs = const [(id: 'tech_1', name: 'Awono')];

  testWidgets('soumet une tâche valide', (tester) async {
    Map<String, dynamic>? sent;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: true,
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt) async {
          sent = {
            'title': title, 'siteId': siteId, 'assigneeId': assigneeId,
            'priority': priority,
          };
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('task_title')), 'Réparer');
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();

    expect(sent!['title'], 'Réparer');
    expect(sent!['siteId'], 's1');         // 1er site pré-sélectionné
    expect(sent!['assigneeId'], 'tech_1'); // 1er technicien pré-sélectionné
    expect(sent!['priority'], TaskPriority.normal);
  });

  testWidgets('hors-ligne : soumission bloquée avec message', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: false,
        onCreate: (a, b, c, d, e, f) async { called = true; },
      ),
    ));
    await tester.enterText(find.byKey(const Key('task_title')), 'X');
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();
    expect(called, false);
    expect(find.textContaining('en ligne'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd mobile && flutter test test/task_create_screen_test.dart`
Expected: FAIL — `task_create_screen.dart` introuvable.

- [ ] **Step 3 : Implémenter l'écran**

Créer `mobile/lib/tasks/task_create_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';

typedef SiteOption = ({String id, String name});
typedef TechOption = ({String id, String name});

class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({
    super.key, required this.sites, required this.technicians,
    required this.onCreate, this.isOnline = true,
  });
  final List<SiteOption> sites;
  final List<TechOption> technicians;
  final bool isOnline;
  final Future<void> Function(
    String title, String description, String siteId, String assigneeId,
    TaskPriority priority, DateTime? dueAt) onCreate;

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _siteId, _assigneeId;
  TaskPriority _priority = TaskPriority.normal;
  DateTime? _dueAt;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.sites.isNotEmpty) _siteId = widget.sites.first.id;
    if (widget.technicians.isNotEmpty) _assigneeId = widget.technicians.first.id;
  }

  Future<void> _submit() async {
    if (!widget.isOnline) {
      setState(() => _error = 'Vous devez être en ligne pour créer une tâche.');
      return;
    }
    if (_title.text.trim().isEmpty || _siteId == null || _assigneeId == null) {
      setState(() => _error = 'Titre, site et technicien sont requis.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    await widget.onCreate(
      _title.text.trim(), _desc.text.trim(), _siteId!, _assigneeId!, _priority, _dueAt);
    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle tâche')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          TextField(
            key: const Key('task_title'), controller: _title,
            decoration: const InputDecoration(labelText: 'Titre')),
          const SizedBox(height: 12),
          TextField(
            controller: _desc, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _siteId,
            decoration: const InputDecoration(labelText: 'Site'),
            items: widget.sites
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _siteId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _assigneeId,
            decoration: const InputDecoration(labelText: 'Technicien'),
            items: widget.technicians
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _assigneeId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: TaskPriority.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? TaskPriority.normal)),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ElevatedButton(
            key: const Key('create_submit'),
            onPressed: _busy ? null : _submit,
            child: const Text('Créer et assigner')),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd mobile && flutter test test/task_create_screen_test.dart`
Expected: PASS.

- [ ] **Step 5 : Compiler le câblage Task 14 + analyse**

Run: `cd mobile && flutter analyze`
Expected: pas d'erreur (le câblage de Task 14 référence désormais un `TaskCreateScreen` existant).

- [ ] **Step 6 : Lancer toute la suite**

Run: `cd mobile && flutter test`
Expected: PASS — suite complète verte.

- [ ] **Step 7 : Commit**

```bash
git add mobile/lib/tasks/task_create_screen.dart mobile/test/task_create_screen_test.dart
git commit -m "feat(mobile): TaskCreateScreen (manager, garde en ligne, sites/techs injectes)"
```

> Note d'alimentation des listes (sites, techniciens, tâches actives) : brancher dans `firebase_auth_gate.dart` des streams Firestore (`sites`, `users` filtré `role==technician`, et `tasks` `assigneeId==me && status==in_progress` pour le pointage). Ces lectures suivent les règles existantes (manager lit `users`/`sites`). Le faire au moment du câblage Task 14, puis re-`flutter analyze`.

---

## Task 16 : Page web lecture seule — liste des tâches

**Files:**
- Create: `web/src/lib/tasks.ts`
- Create: `web/src/app/(dashboard)/tasks/page.tsx`
- Test: `web/__tests__/tasks.test.ts` (adapter au dossier de tests jest existant)

- [ ] **Step 1 : Repérer le pattern de test et d'accès Admin existant**

Lire `web/src/app/(dashboard)/presence/page.tsx` et `web/src/lib/firebaseAdmin.ts` pour réutiliser exactement le même accès Firestore Admin (init, `getFirestore()`), et repérer où vivent les tests jest (`web/src/**/*.test.ts` ou `web/__tests__`).

- [ ] **Step 2 : Écrire le test du mapping**

Créer le test (au bon emplacement jest) `tasks.test.ts` :

```ts
import { mapTaskDoc } from "../src/lib/tasks"; // ajuster le chemin selon l'emplacement

describe("mapTaskDoc", () => {
  it("projette les champs affichés et la présence du rapport", () => {
    const row = mapTaskDoc("t1", {
      title: "Réparer", siteId: "s1", assigneeId: "tech_1",
      status: "done", dueAt: null,
      report: { text: "ok", minutesSpent: 30, photoUrls: [], photoCount: 0 },
    });
    expect(row.id).toBe("t1");
    expect(row.title).toBe("Réparer");
    expect(row.status).toBe("done");
    expect(row.hasReport).toBe(true);
  });

  it("hasReport=false quand report absent", () => {
    const row = mapTaskDoc("t2", {
      title: "X", siteId: "s1", assigneeId: "tech_1", status: "assigned",
      dueAt: null, report: null,
    });
    expect(row.hasReport).toBe(false);
  });
});
```

- [ ] **Step 3 : Lancer, vérifier l'échec**

Run: `cd web && npx jest tasks`
Expected: FAIL — module `src/lib/tasks` introuvable.

- [ ] **Step 4 : Implémenter le mapping**

Créer `web/src/lib/tasks.ts` :

```ts
export interface TaskRow {
  id: string;
  title: string;
  siteId: string;
  assigneeId: string;
  status: string;
  dueAt: string | null;
  hasReport: boolean;
}

interface TaskDoc {
  title?: string;
  siteId?: string;
  assigneeId?: string;
  status?: string;
  dueAt?: { toDate(): Date } | null;
  report?: unknown | null;
}

export function mapTaskDoc(id: string, data: TaskDoc): TaskRow {
  return {
    id,
    title: data.title ?? "",
    siteId: data.siteId ?? "",
    assigneeId: data.assigneeId ?? "",
    status: data.status ?? "assigned",
    dueAt: data.dueAt ? data.dueAt.toDate().toISOString() : null,
    hasReport: data.report != null,
  };
}
```

- [ ] **Step 5 : Lancer, vérifier le succès**

Run: `cd web && npx jest tasks`
Expected: PASS.

- [ ] **Step 6 : Créer la page serveur (lecture seule)**

Créer `web/src/app/(dashboard)/tasks/page.tsx`, en miroir de `presence/page.tsx` (même init Admin) :

```tsx
import { getFirestore } from "firebase-admin/firestore";
import "@/lib/firebaseAdmin"; // initialise l'app Admin (suivre l'import exact de presence/page.tsx)
import { mapTaskDoc, TaskRow } from "@/lib/tasks";

export const dynamic = "force-dynamic";

export default async function TasksPage() {
  const snap = await getFirestore().collection("tasks").orderBy("createdAt", "desc").get();
  const rows: TaskRow[] = snap.docs.map((d) => mapTaskDoc(d.id, d.data()));

  return (
    <main style={{ padding: 24 }}>
      <h1>Tâches</h1>
      <table>
        <thead>
          <tr><th>Titre</th><th>Site</th><th>Assigné</th><th>Statut</th><th>Échéance</th><th>Rapport</th></tr>
        </thead>
        <tbody>
          {rows.map((t) => (
            <tr key={t.id}>
              <td>{t.title}</td>
              <td>{t.siteId}</td>
              <td>{t.assigneeId}</td>
              <td>{t.status}</td>
              <td>{t.dueAt ?? "—"}</td>
              <td>{t.hasReport ? "✓" : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </main>
  );
}
```

> Adapter l'import d'init Admin et l'éventuel garde de rôle (admin) **exactement** comme `presence/page.tsx` (vérifier `currentRole.ts`/`roles.ts`). Aucune écriture.

- [ ] **Step 7 : Vérifier le build web**

Run: `cd web && npx next build`
Expected: build réussi (page `/tasks` générée en dynamique).

- [ ] **Step 8 : Commit**

```bash
git add web/src/lib/tasks.ts web/src/app/(dashboard)/tasks/page.tsx web/__tests__/tasks.test.ts
git commit -m "feat(web): page Taches en lecture seule (table serveur Firebase Admin)"
```

---

## Task 17 : Permissions Android + déclaration FCM + dépendances natives

**Files:**
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/pubspec.yaml` (déjà fait Task 8 si `firebase_messaging` ajouté)

> Câblage natif : pas de test unitaire — validé au build/appareil par l'utilisateur.

- [ ] **Step 1 : Déclarer la permission notifications (Android 13+)**

Dans `mobile/android/app/src/main/AndroidManifest.xml`, ajouter sous `<manifest>` (avant `<application>`) :

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Step 2 : Vérifier l'analyse statique**

Run: `cd mobile && flutter analyze`
Expected: pas d'erreur.

- [ ] **Step 3 : Commit**

```bash
git add mobile/android/app/src/main/AndroidManifest.xml
git commit -m "chore(mobile): permission POST_NOTIFICATIONS pour FCM (Android 13+)"
```

---

## Task 18 : Déploiement Firebase (règles + Function) et validation finale

**Files:** aucun (opérations de déploiement + validation)

> À exécuter par l'utilisateur (le build/déploiement appareil ne passe pas par le contexte Claude).

- [ ] **Step 1 : Déployer règles + Function FCM**

```bash
cd firebase && firebase deploy --only firestore:rules,storage,functions
```
Expected: déploiement OK ; `onTaskAssigned` listée dans les fonctions.

- [ ] **Step 2 : Suite de tests complète (gate avant validation terrain)**

```bash
cd mobile && flutter test && flutter analyze
cd firebase/functions && npx jest
cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"
cd web && npx jest && npx next build
```
Expected: tout vert.

- [ ] **Step 3 : Validation appareil (parcours bout-en-bout)**

Build/lancer depuis le terminal utilisateur :
```bash
cd "D:\App pointage\mobile"
flutter run -d <device> --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...
```
Vérifier : compte manager crée une tâche (en ligne) → le technicien reçoit le push → ouvre, *Démarrer* → pointe en sélectionnant la tâche (siteId hérité) → *Clôturer* avec rapport + photos → photos montées au retour réseau (`report.photoUrls`) → la tâche et le rapport apparaissent au backoffice web.

- [ ] **Step 4 : Mettre à jour le statut projet**

Modifier `CLAUDE.md` (section Statut) et `docs/HANDOFF.md` : Phase 2 ✅, noter les éléments reportés en Phase 3/4. Commit :
```bash
git add CLAUDE.md docs/HANDOFF.md
git commit -m "docs: Phase 2 livree (taches + rapports + push FCM)"
```

---

## Notes de cohérence (self-review)

- **Couverture spec** : modèle `tasks` (T4) ; `report` sous-objet + photos outbox (T5/T6/T7) ; `taskId`/`siteId` au pointage (T13) ; push assignation + purge tokens (T3) ; règles Firestore (T1) et Storage (T2) ; FCM token (T8) ; navigation role-gatée (T9) ; écrans liste/détail/création/rapport (T10/T11/T12/T15) ; web lecture seule (T16). Tous les points de la spec sont couverts.
- **Migration Drift 1→2** : étapes SQL exposées (`migrationV1toV2Sql`) et testées (T5) — adresse le risque clé de la spec.
- **Cohérence des noms** : outbox expose `enqueuePunch`/`enqueueReport`/`pending()`/`removeById`/`bumpAttemptsById` ; `PendingUpload(id, kind, ownerId, localPath, attempts)`. L'uploader utilise `item.kind`/`item.ownerId`/`item.id`. Le repo appelle `enqueueReport`. Cohérent T5↔T6↔T7.
- **Prérequis hors-code** : jeton de session Clerk personnalisé (`public_metadata`) pour que le rôle remonte (cf. HANDOFF) — sans lui, la navigation role-gatée tombe sur `technician` par défaut.
- **Ordre T14/T15** : le câblage (T14) référence `TaskCreateScreen` (T15) ; implémenter T15 avant de compiler T14, commit conjoint.
