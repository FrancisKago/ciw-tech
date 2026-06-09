# Cycle #5 — Managers = aussi techniciens — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à un manager de pointer (onglet Pointage) et de s'auto-assigner des tâches (entrée « Moi » au sélecteur), sans recevoir de notifications pour ses propres tâches.

**Architecture:** Approche chirurgicale (A). Réutilisation des widgets existants : `HomeShell` affiche l'union des onglets pour un manager ; `TaskCreateScreen` reçoit une option optionnelle « soi » ; garde-fou anti-push-perso dans deux Cloud Functions. **Aucun changement de règles ni de modèle de données.**

**Tech Stack:** Flutter (Riverpod, widgets injectables/testables), Cloud Functions TS (firebase-functions v2, jest), règles Firestore (émulateur).

Spec : `docs/superpowers/specs/2026-06-09-cycle-5-managers-aussi-techniciens-design.md`.

---

## Task 1 : `HomeShell` — un manager voit les 3 onglets

**Files:**
- Modify: `mobile/lib/tasks/home_shell.dart:24-44`
- Test: `mobile/test/home_shell_test.dart` (remplacer le test manager existant)

- [ ] **Step 1 : Réécrire le test manager (rouge)**

Remplacer le premier `testWidgets` (« un manager voit "Tâches créées"… ») dans
`mobile/test/home_shell_test.dart` par :

```dart
  testWidgets('un manager voit les 3 onglets (Pointage, Mes tâches, Tâches créées)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        role: 'manager', userId: 'mgr',
        pointageTab: const Text('POINTAGE'),
        myTasksTab: const Text('MES_TACHES'),
        managerTasksTab: const Text('TACHES_CREEES'),
      ),
    ));
    // Libellés de la barre de navigation (toujours rendus, même hors écran)
    expect(find.text('Pointage'), findsOneWidget);
    expect(find.text('Mes tâches'), findsOneWidget);
    expect(find.text('Tâches créées'), findsOneWidget);
    // Onglet par défaut = Pointage (contenu visible)
    expect(find.text('POINTAGE'), findsOneWidget);
    // Bascule vers "Tâches créées"
    await tester.tap(find.text('Tâches créées'));
    await tester.pumpAndSettle();
    expect(find.text('TACHES_CREEES'), findsOneWidget);
  });
```

Le second test (« un technicien voit Pointage + Mes tâches ») reste inchangé.

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run: `cd mobile && flutter test test/home_shell_test.dart`
Expected: FAIL (le manager n'a aujourd'hui qu'un onglet « Tâches » ; `find.text('Pointage')` → findsNothing).

- [ ] **Step 3 : Implémenter — union des onglets pour le manager**

Dans `mobile/lib/tasks/home_shell.dart`, remplacer le corps de `build` (lignes 24-44,
les déclarations `tabs` et `dests`) par :

```dart
    final tabs = widget.isManager
        ? [widget.pointageTab, widget.myTasksTab, widget.managerTasksTab]
        : [widget.pointageTab, widget.myTasksTab];
    final dests = widget.isManager
        ? const [
            NavigationDestination(icon: Icon(Icons.access_time), label: 'Pointage'),
            NavigationDestination(icon: Icon(Icons.checklist), label: 'Mes tâches'),
            NavigationDestination(icon: Icon(Icons.assignment), label: 'Tâches créées'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.access_time), label: 'Pointage'),
            NavigationDestination(icon: Icon(Icons.checklist), label: 'Mes tâches'),
          ];
```

Le reste de `build` (le `Scaffold` avec `IndexedStack` + `NavigationBar`) est inchangé.
`dests.length` vaut désormais toujours ≥ 2, donc la barre de navigation est toujours affichée.

- [ ] **Step 4 : Lancer les tests, vérifier le vert**

Run: `cd mobile && flutter test test/home_shell_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/home_shell.dart mobile/test/home_shell_test.dart
git commit -m "feat(mobile): HomeShell cumule Pointage + Mes tâches + Tâches créées pour un manager"
```

---

## Task 2 : `TaskCreateScreen` — entrée « Moi » au sélecteur d'assigné

**Files:**
- Modify: `mobile/lib/tasks/task_create_screen.dart`
- Test: `mobile/test/task_create_screen_test.dart`

- [ ] **Step 1 : Écrire les tests d'auto-assignation (rouge)**

Ajouter ces deux `testWidgets` dans `mobile/test/task_create_screen_test.dart` (dans le
`main`, après le test « soumet une tâche valide ») :

```dart
  testWidgets('avec self : l\'option "Moi (vous)" apparaît et produit assigneeId==self',
      (tester) async {
    String? assignee;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: techs, isOnline: true,
        self: const (id: 'mgr', name: 'Moi (vous)'),
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt) async {
          assignee = assigneeId;
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('task_title')), 'Tâche perso');
    // Ouvrir le sélecteur d'assigné et choisir "Moi (vous)"
    await tester.tap(find.text('Awono')); // valeur par défaut (1er technicien) affichée
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moi (vous)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();

    expect(assignee, 'mgr');
  });

  testWidgets('self seul (aucun technicien) : soumission possible', (tester) async {
    String? assignee;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: sites, technicians: const [], isOnline: true,
        self: const (id: 'mgr', name: 'Moi (vous)'),
        onCreate: (title, desc, siteId, assigneeId, priority, dueAt) async {
          assignee = assigneeId;
        },
      ),
    ));
    await tester.enterText(find.byKey(const Key('task_title')), 'Solo');
    final btn = tester.widget<ElevatedButton>(find.byKey(const Key('create_submit')));
    expect(btn.onPressed, isNotNull); // bouton actif : self suffit
    await tester.tap(find.byKey(const Key('create_submit')));
    await tester.pump();
    expect(assignee, 'mgr'); // self pré-sélectionné faute de technicien
  });
```

- [ ] **Step 2 : Lancer les tests, vérifier l'échec**

Run: `cd mobile && flutter test test/task_create_screen_test.dart`
Expected: FAIL (le paramètre `self` n'existe pas → erreur de compilation).

- [ ] **Step 3 : Implémenter le paramètre `self` et les options d'assigné**

Dans `mobile/lib/tasks/task_create_screen.dart` :

a) Ajouter le champ et le paramètre au constructeur. Remplacer le constructeur (lignes 7-21) par :

```dart
class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({
    super.key, required this.sites, required this.technicians,
    required this.onCreate, this.isOnline = true, this.self,
  });
  final List<SiteOption> sites;
  final List<TechOption> technicians;
  /// Option « soi » (manager qui s'auto-assigne). Si non nul, préfixe la liste.
  final TechOption? self;
  final bool isOnline;
  final Future<void> Function(
    String title, String description, String siteId, String assigneeId,
    TaskPriority priority, DateTime? dueAt) onCreate;

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}
```

b) Dans `_TaskCreateScreenState`, ajouter un getter des options et corriger `_canSubmit`.
Remplacer le getter `_canSubmit` (lignes 32-33) par :

```dart
  List<TechOption> get _assigneeOptions =>
      [if (widget.self != null) widget.self!, ...widget.technicians];

  bool get _canSubmit =>
      !_busy && widget.sites.isNotEmpty && _assigneeOptions.isNotEmpty;
```

c) Corriger le défaut d'assigné dans `initState`. Remplacer la ligne 39 :

```dart
    if (widget.technicians.isNotEmpty) _assigneeId = widget.technicians.first.id;
```

par :

```dart
    _assigneeId = widget.technicians.isNotEmpty
        ? widget.technicians.first.id
        : widget.self?.id;
```

d) Dans `build`, brancher le sélecteur d'assigné sur `_assigneeOptions`. Remplacer le bloc
de l'assigné (lignes 90-103, le `if (widget.technicians.isEmpty) … else DropdownButtonFormField`)
par :

```dart
          if (_assigneeOptions.isEmpty)
            const ListTile(
              leading: Icon(Icons.person_off, color: Colors.orange),
              title: Text('Aucun technicien disponible'),
              subtitle: Text('Un technicien doit s\'être connecté au moins une fois.'),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Technicien'),
              items: _assigneeOptions
                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _assigneeId = v)),
```

- [ ] **Step 4 : Lancer les tests, vérifier le vert**

Run: `cd mobile && flutter test test/task_create_screen_test.dart`
Expected: PASS (tous les tests, dont les 3 existants — l'absence de `self` laisse le
comportement actuel intact : 1er technicien pré-sélectionné, état vide si ni site ni assigné).

- [ ] **Step 5 : Commit**

```bash
git add mobile/lib/tasks/task_create_screen.dart mobile/test/task_create_screen_test.dart
git commit -m "feat(mobile): TaskCreateScreen propose l'auto-assignation (option « Moi »)"
```

---

## Task 3 : Câblage — passer « soi » à l'écran de création

**Files:**
- Modify: `mobile/lib/auth/firebase_auth_gate.dart:155-168`

> Pas de test unitaire : `_openCreate` dépend de Firebase (Firestore/Connectivity) et n'est
> pas isolable en widget test. Couvert par `flutter analyze` + la validation sur appareil.
> Les comportements logiques (option « Moi », défaut, garde-fou) sont testés en Task 2/4/5.

- [ ] **Step 1 : Ajouter `self` à l'appel `TaskCreateScreen`**

Dans `mobile/lib/auth/firebase_auth_gate.dart`, dans `_openCreate`, l'appel
`return TaskCreateScreen(` (vers la ligne 155) reçoit un nouvel argument `self`.
`uid` est déjà le paramètre de `_openCreate` (l'uid du manager connecté). Remplacer :

```dart
                  return TaskCreateScreen(
                    sites: sites,
                    technicians: techs,
                    isOnline: online,
                    onCreate: (title, desc, siteId, assigneeId, priority, dueAt) =>
```

par :

```dart
                  return TaskCreateScreen(
                    sites: sites,
                    technicians: techs,
                    isOnline: online,
                    self: (id: uid, name: 'Moi (vous)'),
                    onCreate: (title, desc, siteId, assigneeId, priority, dueAt) =>
```

(Le reste de l'appel — le corps de `onCreate` qui appelle `widget.taskRepo.createTask(...)` —
est inchangé. `_openCreate` n'est déclenché que depuis l'onglet manager « Tâches créées »,
donc aucun check de rôle supplémentaire n'est nécessaire.)

- [ ] **Step 2 : Vérifier l'analyse statique**

Run: `cd mobile && flutter analyze`
Expected: « No issues found! »

- [ ] **Step 3 : Lancer toute la suite mobile (non-régression)**

Run: `cd mobile && flutter test`
Expected: PASS (tous les tests).

- [ ] **Step 4 : Commit**

```bash
git add mobile/lib/auth/firebase_auth_gate.dart
git commit -m "feat(mobile): l'écran de création propose le manager comme assigné (« Moi »)"
```

---

## Task 4 : `onTaskAssigned` — pas de push « Nouvelle tâche » vers soi

**Files:**
- Modify: `firebase/functions/src/tasks/onTaskAssigned.ts`
- Test: `firebase/functions/test/onTaskAssigned.test.ts`

- [ ] **Step 1 : Écrire le test du prédicat (rouge)**

Ajouter dans `firebase/functions/test/onTaskAssigned.test.ts` :

a) Étendre l'import en tête de fichier :

```ts
import {
  buildAssignmentMessage,
  splitInvalidTokens,
  shouldNotifyAssignment,
} from "../src/tasks/onTaskAssigned";
```

b) Ajouter ce `describe` :

```ts
describe("shouldNotifyAssignment", () => {
  it("notifie quand l'assigné diffère du créateur", () => {
    expect(shouldNotifyAssignment({ assigneeId: "tech_1", createdBy: "mgr" })).toBe(true);
  });
  it("ne notifie PAS une auto-assignation (assigneeId == createdBy)", () => {
    expect(shouldNotifyAssignment({ assigneeId: "mgr", createdBy: "mgr" })).toBe(false);
  });
  it("ne notifie PAS sans assigné", () => {
    expect(shouldNotifyAssignment({ createdBy: "mgr" })).toBe(false);
  });
});
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run: `cd firebase/functions && npx jest onTaskAssigned`
Expected: FAIL (`shouldNotifyAssignment` n'est pas exporté).

- [ ] **Step 3 : Implémenter le prédicat et brancher le garde-fou**

Dans `firebase/functions/src/tasks/onTaskAssigned.ts` :

a) Ajouter le prédicat pur (après `splitInvalidTokens`, avant `export const onTaskAssigned`) :

```ts
/** Vrai si l'assignation mérite un push : assigné présent ET différent du créateur
 *  (une auto-assignation ne se notifie pas elle-même). */
export function shouldNotifyAssignment(
  task: { assigneeId?: string; createdBy?: string },
): boolean {
  return !!task.assigneeId && task.assigneeId !== task.createdBy;
}
```

b) Dans le handler `onTaskAssigned`, remplacer la lecture et la garde. Remplacer :

```ts
  const task = snap.data() as TaskLite & { assigneeId?: string };
  const taskId = event.params.taskId;
  if (!task.assigneeId) return; // tâche sans assigné : rien à notifier
```

par :

```ts
  const task = snap.data() as TaskLite & { assigneeId?: string; createdBy?: string };
  const taskId = event.params.taskId;
  if (!shouldNotifyAssignment(task)) return; // pas d'assigné, ou auto-assignation
```

- [ ] **Step 4 : Lancer les tests, vérifier le vert**

Run: `cd firebase/functions && npx jest onTaskAssigned`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add firebase/functions/src/tasks/onTaskAssigned.ts firebase/functions/test/onTaskAssigned.test.ts
git commit -m "fix(functions): pas de push d'assignation lors d'une auto-assignation manager"
```

---

## Task 5 : `routeStatusChange` — pas de push « à valider » vers soi

**Files:**
- Modify: `firebase/functions/src/tasks/onTaskUpdated.ts:12-21`
- Test: `firebase/functions/test/onTaskUpdated.test.ts`

- [ ] **Step 1 : Écrire les tests d'auto-assignation (rouge)**

Ajouter dans le `describe("routeStatusChange", …)` de
`firebase/functions/test/onTaskUpdated.test.ts` :

```ts
  it("auto-assignation : done n'envoie PAS report_submitted vers soi", () => {
    const self = { status: "in_progress", createdBy: "mgr", assigneeId: "mgr" };
    const out = routeStatusChange(self, { ...self, status: "done" });
    expect(out).toEqual([]);
  });

  it("auto-assignation : approved est tout de même émis", () => {
    const self = { status: "done", createdBy: "mgr", assigneeId: "mgr" };
    const out = routeStatusChange(self, { ...self, status: "approved" });
    expect(out).toEqual([{ kind: "approved", recipientId: "mgr" }]);
  });
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run: `cd firebase/functions && npx jest onTaskUpdated`
Expected: FAIL (le 1er nouveau test : `report_submitted` est encore émis vers « mgr »).

- [ ] **Step 3 : Implémenter le garde-fou dans `routeStatusChange`**

Dans `firebase/functions/src/tasks/onTaskUpdated.ts`, remplacer le corps de
`routeStatusChange` (lignes 12-21) par :

```ts
export function routeStatusChange(before: TaskState, after: TaskState): StatusNotice[] {
  const notices: StatusNotice[] = [];
  // Auto-assignation : le push « à valider » irait au manager lui-même → on l'omet.
  if (before.status !== "done" && after.status === "done"
      && after.assigneeId !== after.createdBy) {
    notices.push({ kind: "report_submitted", recipientId: after.createdBy });
  }
  // Le push « validée » est conservé même en auto-assignation (informe l'exécutant).
  if (before.status !== "approved" && after.status === "approved") {
    notices.push({ kind: "approved", recipientId: after.assigneeId });
  }
  return notices;
}
```

- [ ] **Step 4 : Lancer les tests, vérifier le vert**

Run: `cd firebase/functions && npx jest onTaskUpdated`
Expected: PASS (anciens + nouveaux tests).

- [ ] **Step 5 : Commit**

```bash
git add firebase/functions/src/tasks/onTaskUpdated.ts firebase/functions/test/onTaskUpdated.test.ts
git commit -m "fix(functions): pas de push « à valider » lors d'une auto-assignation manager"
```

---

## Task 6 : Règles — test documentaire d'auto-assignation

**Files:**
- Modify: `firebase/functions/test/rules.test.ts` (dans `describe("règles tasks", …)`)

> Aucun changement de `firestore.rules`. Ce test **documente** que les règles existantes
> autorisent déjà l'auto-assignation et le démarrage par un manager-assigné. L'émulateur
> Firestore ne démarre pas sur ce poste (dette socket Java 17, cf. `docs/SETUP.md`) :
> ce test est **exécuté par l'utilisateur** dans son terminal (commande au Step 2).

- [ ] **Step 1 : Ajouter les tests documentaires**

Ajouter à la fin du `describe("règles tasks", …)` de `firebase/functions/test/rules.test.ts`,
juste avant sa `});` fermante :

```ts
  it("un manager peut s'auto-assigner une tâche (assigneeId == createdBy)", async () => {
    const db = ctx("mgr", "manager");
    await assertSucceeds(setDoc(doc(db, "tasks/t12"),
      { ...baseTask, assigneeId: "mgr", createdBy: "mgr" }));
  });

  it("un manager-assigné peut démarrer sa propre tâche (in_progress)", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t13"),
        { ...baseTask, assigneeId: "mgr", createdBy: "mgr" }));
    const db = ctx("mgr", "manager");
    await assertSucceeds(setDoc(doc(db, "tasks/t13"),
      { ...baseTask, assigneeId: "mgr", createdBy: "mgr", status: "in_progress" }));
  });
```

- [ ] **Step 2 : Lancer les tests de règles (terminal utilisateur, émulateur)**

Run: `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected: PASS (17/17 — les 15 existants + 2 nouveaux).

- [ ] **Step 3 : Commit**

```bash
git add firebase/functions/test/rules.test.ts
git commit -m "test(rules): documente l'auto-assignation et le démarrage par un manager-assigné"
```

---

## Validation finale (avant merge)

À exécuter par l'utilisateur (le build APK et l'émulateur ne tournent pas dans le contexte Claude) :

- [ ] `cd mobile && flutter analyze` → « No issues found! »
- [ ] `cd mobile && flutter test` → tout vert
- [ ] `cd firebase/functions && npx jest` → tout vert (unitaires)
- [ ] `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"` → 17/17
- [ ] **Validation sur tablette SM X115** (`flutter run -d R83Y60PXH0P --dart-define=CLERK_PUBLISHABLE_KEY=pk_...`) :
  un compte **manager** voit 3 onglets ; pointe depuis l'onglet Pointage ; crée une tâche en
  se choisissant comme assigné (« Moi (vous) ») ; la retrouve dans « Mes tâches » ; la démarre
  et la clôture avec rapport — **sans recevoir de push pour lui-même** (ni « Nouvelle tâche »,
  ni « à valider »).
- [ ] **Déploiement Functions** : `cd firebase && firebase deploy --only functions`
  (les règles sont inchangées ; pas de `firestore:rules` à redéployer).
- [ ] Mettre à jour `CLAUDE.md` et `docs/HANDOFF.md` (Cycle #5 livré).
