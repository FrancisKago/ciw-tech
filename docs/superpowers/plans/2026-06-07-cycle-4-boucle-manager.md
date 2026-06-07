# Cycle #4 — Boucle manager (validation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à un manager de valider une tâche terminée depuis le backoffice (`done → approved`) après revue du rapport, avec deux push FCM (technicien→manager à la soumission, manager→technicien à la validation) et un durcissement des règles Firestore.

**Architecture:** Le backoffice écrit via Firebase Admin SDK (contourne les règles) ; un Server Action `approveTask` re-vérifie le rôle côté serveur et approuve en transaction (garde « statut courant = done »). Un unique trigger Cloud Function `onTaskUpdated` route les deux push selon la transition de statut, en réutilisant les helpers d'`onTaskAssigned`. Les règles sont durcies pour qu'un client assigné ne puisse jamais poser `approved`.

**Tech Stack:** Next.js 16 (App Router, Server Actions, Server Components), Firebase Admin SDK, Cloud Functions v2 (Node 22), Firestore rules, Flutter (mobile, lecture seule). Tests : jest (web + functions), `@firebase/rules-unit-testing` (émulateur), `flutter test`.

**Spec de référence :** `docs/superpowers/specs/2026-06-07-cycle-4-boucle-manager-design.md`

---

## File Structure

| Fichier | Responsabilité | Action |
|---------|----------------|--------|
| `firebase/functions/src/tasks/onTaskUpdated.ts` | Trigger + routeur pur + builders des 2 messages | Créer |
| `firebase/functions/test/onTaskUpdated.test.ts` | Tests purs (routage + builders) | Créer |
| `firebase/functions/src/index.ts` | Export du nouveau trigger | Modifier |
| `firebase/firestore.rules` | Durcissement update assigné (`approved` interdit) | Modifier |
| `firebase/functions/test/rules.test.ts` | Tests de règles (émulateur) | Modifier |
| `web/src/lib/tasks.ts` | `mapTaskDoc` étendu (détail rapport + champs validation) | Modifier |
| `web/__tests__/tasks.test.ts` | Test du mapping détaillé | Modifier |
| `web/src/lib/approval.ts` | Garde pure `canApprove` (rôle + statut) | Créer |
| `web/__tests__/approval.test.ts` | Tests de la garde | Créer |
| `web/src/lib/actions/approveTask.ts` | Server Action de validation (Clerk + transaction Admin) | Créer |
| `web/src/app/(dashboard)/board/[taskId]/page.tsx` | Vue détail + rapport + bouton Valider | Créer |
| `web/src/app/(dashboard)/board/page.tsx` | Cartes cliquables + badges approved/à valider | Modifier |
| `mobile/lib/models/task.dart` | `TaskStatus.approved` (lecture seule) | Modifier |
| `mobile/lib/tasks/tasks_list_screen.dart` | Libellé statut `approved` | Modifier |
| `mobile/lib/tasks/task_detail_screen.dart` | Cas `approved` (pas d'action) | Modifier |
| `mobile/test/task_test.dart` | Test `fromWire('approved')` | Modifier |
| `CLAUDE.md` | Schéma `tasks` (champs + statut) | Modifier |
| `docs/HANDOFF.md` | État Cycle #4 | Modifier |

---

## Task 1: Cloud Function `onTaskUpdated` — routeur pur + builders

**Files:**
- Create: `firebase/functions/src/tasks/onTaskUpdated.ts`
- Test: `firebase/functions/test/onTaskUpdated.test.ts`

- [ ] **Step 1: Write the failing test**

Créer `firebase/functions/test/onTaskUpdated.test.ts` :

```ts
import {
  routeStatusChange,
  buildReportSubmittedMessage,
  buildApprovedMessage,
} from "../src/tasks/onTaskUpdated";

describe("routeStatusChange", () => {
  const base = { status: "assigned", createdBy: "mgr", assigneeId: "tech_1" };

  it("in_progress → done : notifie le créateur (manager)", () => {
    const out = routeStatusChange({ ...base, status: "in_progress" }, { ...base, status: "done" });
    expect(out).toEqual([{ kind: "report_submitted", recipientId: "mgr" }]);
  });

  it("done → approved : notifie l'assigné (technicien)", () => {
    const out = routeStatusChange({ ...base, status: "done" }, { ...base, status: "approved" });
    expect(out).toEqual([{ kind: "approved", recipientId: "tech_1" }]);
  });

  it("aucune transition pertinente : rien", () => {
    const out = routeStatusChange({ ...base, status: "assigned" }, { ...base, status: "in_progress" });
    expect(out).toEqual([]);
  });

  it("done inchangé (patch de rapport) : rien", () => {
    const out = routeStatusChange({ ...base, status: "done" }, { ...base, status: "done" });
    expect(out).toEqual([]);
  });
});

describe("builders de message", () => {
  it("buildReportSubmittedMessage porte le taskId et le titre", () => {
    const m = buildReportSubmittedMessage("t1", "Réparer clim");
    expect(m.notification.title).toContain("Réparer clim");
    expect(m.data).toEqual({ taskId: "t1", kind: "report_submitted" });
  });

  it("buildApprovedMessage porte le taskId et le titre", () => {
    const m = buildApprovedMessage("t1", "Réparer clim");
    expect(m.notification.title).toContain("Réparer clim");
    expect(m.data).toEqual({ taskId: "t1", kind: "approved" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd firebase/functions && npx jest onTaskUpdated`
Expected: FAIL — `Cannot find module '../src/tasks/onTaskUpdated'`.

- [ ] **Step 3: Write minimal implementation (pure parts + trigger)**

Créer `firebase/functions/src/tasks/onTaskUpdated.ts`. Réutilise `splitInvalidTokens` d'`onTaskAssigned` (DRY) :

```ts
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { splitInvalidTokens } from "./onTaskAssigned";

interface TaskState { status: string; createdBy: string; assigneeId: string; }

export type StatusNotice =
  | { kind: "report_submitted"; recipientId: string }
  | { kind: "approved"; recipientId: string };

/** Décide quels push émettre selon la transition de statut. Pur, testable. */
export function routeStatusChange(before: TaskState, after: TaskState): StatusNotice[] {
  const notices: StatusNotice[] = [];
  if (before.status !== "done" && after.status === "done") {
    notices.push({ kind: "report_submitted", recipientId: after.createdBy });
  }
  if (before.status !== "approved" && after.status === "approved") {
    notices.push({ kind: "approved", recipientId: after.assigneeId });
  }
  return notices;
}

export function buildReportSubmittedMessage(taskId: string, title: string) {
  return {
    notification: { title: `Tâche terminée : ${title}`, body: "À valider au backoffice." },
    data: { taskId, kind: "report_submitted" },
  };
}

export function buildApprovedMessage(taskId: string, title: string) {
  return {
    notification: { title: `Tâche validée : ${title}`, body: "Ton rapport a été approuvé ✓" },
    data: { taskId, kind: "approved" },
  };
}

interface FcmMessage {
  notification: { title: string; body: string };
  data: { taskId: string; kind: string };
}

/** Envoie un multicast au destinataire et purge ses tokens morts. */
async function notify(recipientId: string, message: FcmMessage) {
  if (!recipientId) return;
  const userSnap = await admin.firestore().doc(`users/${recipientId}`).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];
  if (tokens.length === 0) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens, notification: message.notification, data: message.data,
  });
  const { invalid } = splitInvalidTokens(tokens, res.responses as never);
  if (invalid.length > 0) {
    await admin.firestore().doc(`users/${recipientId}`).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
    });
  }
}

export const onTaskUpdated = onDocumentUpdated("tasks/{taskId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const taskId = event.params.taskId;
  const title = (after.title as string) ?? "";

  const notices = routeStatusChange(before as TaskState, after as TaskState);
  for (const n of notices) {
    const message =
      n.kind === "report_submitted"
        ? buildReportSubmittedMessage(taskId, title)
        : buildApprovedMessage(taskId, title);
    await notify(n.recipientId, message);
  }
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd firebase/functions && npx jest onTaskUpdated`
Expected: PASS (6 tests).

- [ ] **Step 5: Export the trigger**

Modifier `firebase/functions/src/index.ts` — ajouter après la ligne `onTaskAssigned` :

```ts
export { onTaskUpdated } from "./tasks/onTaskUpdated";
```

- [ ] **Step 6: Typecheck + full functions tests**

Run: `cd firebase/functions && npx tsc --noEmit && npx jest`
Expected: tsc propre ; jest tout vert (anciens + nouveaux).

- [ ] **Step 7: Commit**

```bash
git add firebase/functions/src/tasks/onTaskUpdated.ts firebase/functions/test/onTaskUpdated.test.ts firebase/functions/src/index.ts
git commit -m "feat(functions): onTaskUpdated route les push retour (done->manager, approved->technicien)"
```

---

## Task 2: Durcissement des règles Firestore

**Files:**
- Modify: `firebase/firestore.rules:26-40`
- Test: `firebase/functions/test/rules.test.ts` (ajouts dans `describe("règles tasks")`)

- [ ] **Step 1: Write the failing tests**

Dans `firebase/functions/test/rules.test.ts`, ajouter ces trois `it(...)` à l'intérieur du `describe("règles tasks", ...)` (après le test « ne peut PAS se réassigner ») :

```ts
  it("l'assigné peut passer status à done", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t8"), { ...baseTask, status: "in_progress" }));
    const db = ctx("tech_1", "technician");
    await assertSucceeds(setDoc(doc(db, "tasks/t8"), { ...baseTask, status: "done" }));
  });

  it("l'assigné ne peut PAS s'auto-valider (approved)", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t9"), { ...baseTask, status: "done" }));
    const db = ctx("tech_1", "technician");
    await assertFails(setDoc(doc(db, "tasks/t9"), { ...baseTask, status: "approved" }));
  });

  it("un manager peut valider (approved)", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t10"), { ...baseTask, status: "done" }));
    const db = ctx("mgr", "manager");
    await assertSucceeds(setDoc(doc(db, "tasks/t10"), { ...baseTask, status: "approved" }));
  });
```

- [ ] **Step 2: Run tests to verify the "approved" deny fails (rule not yet hardened)**

> ⚠ L'émulateur Firestore ne démarre pas dans le contexte Claude (dette socket, cf. `docs/SETUP.md`) — **cette étape est lancée par l'utilisateur dans son terminal**. Le planificateur/exécuteur note l'attendu et continue.

Run (utilisateur) : `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected AVANT durcissement : le test « ne peut PAS s'auto-valider (approved) » **échoue** (la règle actuelle laisse l'assigné poser n'importe quel status).

- [ ] **Step 3: Harden the rule**

Modifier `firebase/firestore.rules`, bloc `match /tasks/{taskId}`. Ajouter le helper `assigneeStatusAllowed()` à côté d'`assigneeOnlyChangesAllowed()`, et l'ajouter à la branche assigné de `allow update` :

```
    match /tasks/{taskId} {
      // Champs que l'assigné a le droit de modifier (les autres doivent rester inchangés).
      function assigneeOnlyChangesAllowed() {
        return request.resource.data.diff(resource.data).affectedKeys()
                 .hasOnly(['status', 'report', 'updatedAt']);
      }

      // L'assigné ne peut amener le statut que vers in_progress ou done.
      // 'approved' (validation) reste réservé au manager (Admin SDK backoffice).
      function assigneeStatusAllowed() {
        return request.resource.data.status in ['in_progress', 'done'];
      }

      allow create: if isManager()
                    && request.resource.data.createdBy == request.auth.uid;
      allow read:   if isManager() || resource.data.assigneeId == request.auth.uid;
      allow update: if isManager()
                    || (resource.data.assigneeId == request.auth.uid
                        && assigneeOnlyChangesAllowed()
                        && assigneeStatusAllowed());
      allow delete: if false;
    }
```

- [ ] **Step 4: Re-run rules tests (utilisateur)**

Run (utilisateur) : `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected APRÈS durcissement : **tout vert** — l'assigné peut `done` (allow), ne peut pas `approved` (deny), le manager peut `approved` (allow).

- [ ] **Step 5: Validate rules syntax sans émulateur (contexte Claude)**

Run: `cd firebase && firebase deploy --only firestore:rules --dry-run`
Expected: « compiled successfully » (validation de syntaxe, sans déploiement).

- [ ] **Step 6: Commit**

```bash
git add firebase/firestore.rules firebase/functions/test/rules.test.ts
git commit -m "feat(rules): l'assigne ne peut plus poser status=approved (reserve au manager)"
```

---

## Task 3: `mapTaskDoc` étendu (détail rapport + champs validation)

**Files:**
- Modify: `web/src/lib/tasks.ts`
- Test: `web/__tests__/tasks.test.ts`

- [ ] **Step 1: Write the failing test**

Ajouter dans `web/__tests__/tasks.test.ts` :

```ts
  it("projette le détail du rapport et les champs de validation", () => {
    const row = mapTaskDoc("t3", {
      title: "Réparer", siteId: "s1", assigneeId: "tech_1", createdBy: "mgr",
      status: "approved", dueAt: null,
      report: {
        text: "RAS", minutesSpent: 45, photoUrls: ["https://x/a.jpg"], photoCount: 1,
        submittedAt: { toDate: () => new Date("2026-06-07T10:00:00Z") },
      },
      approvedBy: "mgr",
      approvedAt: { toDate: () => new Date("2026-06-07T12:00:00Z") },
    });
    expect(row.createdBy).toBe("mgr");
    expect(row.report?.text).toBe("RAS");
    expect(row.report?.minutesSpent).toBe(45);
    expect(row.report?.photoUrls).toEqual(["https://x/a.jpg"]);
    expect(row.report?.submittedAt).toBe("2026-06-07T10:00:00.000Z");
    expect(row.approvedBy).toBe("mgr");
    expect(row.approvedAt).toBe("2026-06-07T12:00:00.000Z");
  });

  it("report=null quand absent (détail null, hasReport false)", () => {
    const row = mapTaskDoc("t4", {
      title: "X", siteId: "s1", assigneeId: "tech_1", status: "assigned",
      dueAt: null, report: null,
    });
    expect(row.report).toBeNull();
    expect(row.hasReport).toBe(false);
    expect(row.approvedBy).toBeNull();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web && npx jest tasks`
Expected: FAIL — `row.createdBy` / `row.report` indéfinis (champs pas encore mappés).

- [ ] **Step 3: Extend the mapper**

Remplacer intégralement `web/src/lib/tasks.ts` par :

```ts
export interface ReportDetail {
  text: string;
  minutesSpent: number;
  photoUrls: string[];
  photoCount: number;
  submittedAt: string | null;
}

export interface TaskRow {
  id: string;
  title: string;
  siteId: string;
  assigneeId: string;
  createdBy: string;
  status: string;
  dueAt: string | null;
  hasReport: boolean;
  report: ReportDetail | null;
  approvedBy: string | null;
  approvedAt: string | null;
}

interface TimestampLike { toDate(): Date; }

interface ReportDoc {
  text?: string;
  minutesSpent?: number;
  photoUrls?: string[];
  photoCount?: number;
  submittedAt?: TimestampLike | null;
}

interface TaskDoc {
  title?: string;
  siteId?: string;
  assigneeId?: string;
  createdBy?: string;
  status?: string;
  dueAt?: TimestampLike | null;
  report?: ReportDoc | null;
  approvedBy?: string | null;
  approvedAt?: TimestampLike | null;
}

export function mapTaskDoc(id: string, data: TaskDoc): TaskRow {
  const report: ReportDetail | null = data.report
    ? {
        text: data.report.text ?? "",
        minutesSpent: data.report.minutesSpent ?? 0,
        photoUrls: data.report.photoUrls ?? [],
        photoCount: data.report.photoCount ?? 0,
        submittedAt: data.report.submittedAt
          ? data.report.submittedAt.toDate().toISOString()
          : null,
      }
    : null;

  return {
    id,
    title: data.title ?? "",
    siteId: data.siteId ?? "",
    assigneeId: data.assigneeId ?? "",
    createdBy: data.createdBy ?? "",
    status: data.status ?? "assigned",
    dueAt: data.dueAt ? data.dueAt.toDate().toISOString() : null,
    hasReport: data.report != null,
    report,
    approvedBy: data.approvedBy ?? null,
    approvedAt: data.approvedAt ? data.approvedAt.toDate().toISOString() : null,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web && npx jest tasks`
Expected: PASS (anciens + nouveaux tests).

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/tasks.ts web/__tests__/tasks.test.ts
git commit -m "feat(web): mapTaskDoc porte le detail du rapport et les champs de validation"
```

---

## Task 4: Garde pure `canApprove`

**Files:**
- Create: `web/src/lib/approval.ts`
- Test: `web/__tests__/approval.test.ts`

- [ ] **Step 1: Write the failing test**

Créer `web/__tests__/approval.test.ts` :

```ts
import { canApprove } from "@/lib/approval";

describe("canApprove", () => {
  it("manager + done → true", () => expect(canApprove("manager", "done")).toBe(true));
  it("admin + done → true", () => expect(canApprove("admin", "done")).toBe(true));
  it("technician + done → false", () => expect(canApprove("technician", "done")).toBe(false));
  it("manager + in_progress → false", () => expect(canApprove("manager", "in_progress")).toBe(false));
  it("manager + approved (déjà validé) → false", () => expect(canApprove("manager", "approved")).toBe(false));
  it("rôle absent + done → false", () => expect(canApprove(undefined, "done")).toBe(false));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web && npx jest approval`
Expected: FAIL — `Cannot find module '@/lib/approval'`.

- [ ] **Step 3: Write the pure guard**

Créer `web/src/lib/approval.ts` :

```ts
import { canAccessBackoffice } from "./roles";

/**
 * Une validation n'est permise que pour un manager/admin et sur une tâche au statut 'done'
 * (idempotence : une tâche déjà 'approved' n'est pas re-validable).
 */
export function canApprove(role: string | null | undefined, currentStatus: string): boolean {
  return canAccessBackoffice(role) && currentStatus === "done";
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web && npx jest approval`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/approval.ts web/__tests__/approval.test.ts
git commit -m "feat(web): garde pure canApprove (manager/admin + statut done)"
```

---

## Task 5: Server Action `approveTask`

**Files:**
- Create: `web/src/lib/actions/approveTask.ts`

> Pas de test unitaire direct : l'action appelle Clerk (`auth`) + Admin SDK. La logique d'autorisation est couverte par `canApprove` (Task 4) et par les règles (Task 2). Vérification d'intégration via `next build` (Task 6).

- [ ] **Step 1: Vérifier l'API Next 16 avant d'écrire**

Lire la doc locale (avertissement `web/AGENTS.md` : « This is NOT the Next.js you know ») pour confirmer la signature des Server Actions et `revalidatePath` :

Run: `ls web/node_modules/next/dist/docs/ 2>/dev/null` puis lire le guide pertinent (Server Actions / caching). Confirmer : `"use server"`, action de formulaire `(formData: FormData)`, `revalidatePath` importé de `next/cache`.

- [ ] **Step 2: Write the Server Action**

Créer `web/src/lib/actions/approveTask.ts` :

```ts
"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "@/lib/firebaseAdmin";
import { getUserRole } from "@/lib/currentRole";
import { canApprove } from "@/lib/approval";

/**
 * Valide une tâche (done → approved). Server Action : re-vérifie le rôle côté serveur
 * (on ne fait pas confiance à l'UI role-gatée) et approuve en transaction, seulement si
 * la tâche est encore au statut 'done' (garde anti-double-validation / anti-course).
 */
export async function approveTask(formData: FormData) {
  const taskId = formData.get("taskId");
  if (typeof taskId !== "string" || !taskId) throw new Error("taskId manquant");

  const { userId } = await auth();
  if (!userId) throw new Error("non authentifié");
  const role = await getUserRole(userId);

  const database = db();
  const ref = database.doc(`tasks/${taskId}`);

  await database.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("tâche introuvable");
    const currentStatus = (snap.get("status") as string) ?? "assigned";
    if (!canApprove(role, currentStatus)) {
      throw new Error("validation non autorisée");
    }
    tx.update(ref, {
      status: "approved",
      approvedBy: userId,
      approvedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  revalidatePath("/board");
  revalidatePath(`/board/${taskId}`);
}
```

- [ ] **Step 3: Typecheck**

Run: `cd web && npx tsc --noEmit`
Expected: propre.

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/actions/approveTask.ts
git commit -m "feat(web): Server Action approveTask (re-check role serveur + transaction done->approved)"
```

---

## Task 6: Vue détail de tâche + board cliquable

**Files:**
- Create: `web/src/app/(dashboard)/board/[taskId]/page.tsx`
- Modify: `web/src/app/(dashboard)/board/page.tsx`

- [ ] **Step 1: Create the detail page**

Créer `web/src/app/(dashboard)/board/[taskId]/page.tsx` :

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";
import { mapTaskDoc } from "@/lib/tasks";
import { approveTask } from "@/lib/actions/approveTask";

export const dynamic = "force-dynamic";

export default async function TaskDetailPage({
  params,
}: {
  params: Promise<{ taskId: string }>;
}) {
  const { taskId } = await params;
  const database = db();
  const [snap, dir] = await Promise.all([
    database.doc(`tasks/${taskId}`).get(),
    loadDirectory(database),
  ]);
  if (!snap.exists) notFound();
  const task = mapTaskDoc(snap.id, snap.data()!);

  return (
    <main className="p-6">
      <Link href="/board" className="text-sm text-gray-500 hover:underline">← Board</Link>
      <h1 className="mb-1 mt-2 text-2xl font-semibold">{task.title}</h1>
      <div className="mb-4 text-sm text-gray-600">
        👤 {displayUser(task.assigneeId, dir)} · 📍 {displaySite(task.siteId, dir)} · statut {task.status}
      </div>

      {task.status === "approved" && (
        <div className="mb-4 rounded border-l-4 border-l-green-600 bg-green-50 p-3 text-sm text-green-800">
          ✓ Validé par {displayUser(task.approvedBy ?? "", dir)}
          {task.approvedAt && ` le ${fmtDate(task.approvedAt)}`}
        </div>
      )}

      <section className="rounded-lg border border-gray-200 bg-white p-4">
        <h2 className="mb-2 text-lg font-medium">Rapport</h2>
        {task.report ? (
          <>
            <p className="whitespace-pre-wrap text-sm text-gray-800">{task.report.text || "—"}</p>
            <p className="mt-2 text-sm text-gray-600">
              ⏱ {task.report.minutesSpent} min · {task.report.photoCount} photo(s)
            </p>
            {task.report.submittedAt && (
              <p className="text-xs text-gray-500">Soumis le {fmtDate(task.report.submittedAt)}</p>
            )}
            {task.report.photoUrls.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {task.report.photoUrls.map((url) => (
                  <a key={url} href={url} target="_blank" rel="noreferrer">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={url} alt="photo rapport" className="h-24 w-24 rounded object-cover" />
                  </a>
                ))}
              </div>
            )}
          </>
        ) : (
          <p className="text-sm text-gray-400">Aucun rapport soumis.</p>
        )}
      </section>

      {task.status === "done" && (
        <form action={approveTask} className="mt-4">
          <input type="hidden" name="taskId" value={task.id} />
          <button type="submit" className="rounded bg-green-700 px-4 py-2 text-white">
            Valider la tâche
          </button>
        </form>
      )}
    </main>
  );
}

function fmtDate(iso: string): string {
  return new Date(iso).toLocaleDateString("fr-FR", {
    day: "numeric", month: "short", year: "numeric",
  });
}
```

- [ ] **Step 2: Make board cards clickable + add badges**

Dans `web/src/app/(dashboard)/board/page.tsx` :

(a) Ajouter l'import en tête de fichier :

```tsx
import Link from "next/link";
```

(b) Remplacer entièrement la fonction `Card` (lignes 85-109) par :

```tsx
function Card({ task, dir, late }: { task: BoardTask; dir: Directory; late: boolean }) {
  return (
    <Link
      href={`/board/${task.id}`}
      className={
        "block rounded-lg border bg-white p-3 shadow-sm hover:shadow " +
        (late ? "border-l-4 border-l-red-600" : "border-gray-200")
      }
    >
      <div className="font-medium">{task.title}</div>
      <div className="mt-1 text-sm text-gray-600">
        👤 {displayUser(task.assigneeId, dir)} · 📍 {displaySite(task.siteId, dir)}
      </div>
      {late ? (
        <div className="mt-1 text-xs font-semibold text-red-600">
          ⚠ En retard · échéance {fmt(task.dueAt)}
        </div>
      ) : (
        <div className="mt-1 text-xs text-gray-500">
          Échéance : {fmt(task.dueAt)}
          {task.status === "approved" && (
            <span className="ml-2 font-semibold text-green-700">✓ validé</span>
          )}
          {task.status === "done" && (
            <span className="ml-2 font-semibold text-amber-600">à valider</span>
          )}
          {task.status !== "approved" && task.status !== "done" && task.hasReport && (
            <span className="ml-2 text-green-700">✓ rapport</span>
          )}
        </div>
      )}
    </Link>
  );
}
```

- [ ] **Step 3: Typecheck + lint + build**

Run: `cd web && npx tsc --noEmit && npx eslint . && npx next build`
Expected: propre ; build OK avec les routes `/board` et `/board/[taskId]`.

- [ ] **Step 4: Full web jest (non-régression)**

Run: `cd web && npx jest`
Expected: tout vert.

- [ ] **Step 5: Commit**

```bash
git add "web/src/app/(dashboard)/board/[taskId]/page.tsx" "web/src/app/(dashboard)/board/page.tsx"
git commit -m "feat(web): vue detail de tache avec rapport + bouton Valider, cartes board cliquables"
```

---

## Task 7: Mobile — `TaskStatus.approved` en lecture seule

**Files:**
- Modify: `mobile/lib/models/task.dart:3-15`
- Modify: `mobile/lib/tasks/tasks_list_screen.dart:4-8`
- Modify: `mobile/lib/tasks/task_detail_screen.dart:34-42`
- Test: `mobile/test/task_test.dart`

- [ ] **Step 1: Write the failing test**

Ajouter dans `mobile/test/task_test.dart` (avant la `}` finale du `main`) :

```dart
  test('fromWire reconnaît approved (lecture seule)', () {
    expect(TaskStatusX.fromWire('approved'), TaskStatus.approved);
    expect(TaskStatus.approved.wire, 'approved');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/task_test.dart`
Expected: FAIL — `TaskStatus.approved` n'existe pas (erreur de compilation).

- [ ] **Step 3: Add the enum value**

Dans `mobile/lib/models/task.dart`, remplacer l'enum + l'extension (lignes 3-15) par :

```dart
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
```

- [ ] **Step 4: Fix the two exhaustive switches**

(a) Dans `mobile/lib/tasks/tasks_list_screen.dart`, remplacer `statusLabel` (lignes 4-8) par :

```dart
String statusLabel(TaskStatus s) => switch (s) {
      TaskStatus.assigned => 'assigné',
      TaskStatus.inProgress => 'en cours',
      TaskStatus.done => 'terminé',
      TaskStatus.approved => 'validé',
    };
```

(b) Dans `mobile/lib/tasks/task_detail_screen.dart`, remplacer le `switch` de `_actionBar` (lignes 34-42) par — `approved` n'offre aucune action, comme `done` :

```dart
    final Widget? button = switch (task.status) {
      TaskStatus.assigned => ElevatedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow), label: const Text('Démarrer')),
      TaskStatus.inProgress => ElevatedButton.icon(
          onPressed: onClose,
          icon: const Icon(Icons.check), label: const Text('Clôturer')),
      TaskStatus.done => null,
      TaskStatus.approved => null,
    };
```

- [ ] **Step 5: Run test + analyze**

Run: `cd mobile && flutter test test/task_test.dart && flutter analyze`
Expected: test PASS ; `flutter analyze` propre (plus de switch non exhaustif).

- [ ] **Step 6: Full mobile tests (non-régression)**

Run: `cd mobile && flutter test`
Expected: tout vert.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/models/task.dart mobile/lib/tasks/tasks_list_screen.dart mobile/lib/tasks/task_detail_screen.dart mobile/test/task_test.dart
git commit -m "feat(mobile): TaskStatus.approved en lecture seule (libelle valide, aucune action)"
```

---

## Task 8: Documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/HANDOFF.md`

- [ ] **Step 1: Update the tasks schema in CLAUDE.md**

Dans `CLAUDE.md`, section « Données Firestore », remplacer la ligne `tasks/{taskId}` par :

```
- `tasks/{taskId}` : title, description, siteId, assigneeId, createdBy, priority, dueAt,
  status(assigned/in_progress/done/approved), report{...}, approvedBy, approvedAt, updatedAt
```

- [ ] **Step 2: Update the Statut section in CLAUDE.md**

Dans `CLAUDE.md`, section « Statut », ajouter sous Phase 3 :

```
- **Cycle #4 (boucle manager : validation)** : ✅ livré (code). Backoffice : vue détail de
  tâche (rapport + photos) + bouton Valider (Server Action, `done → approved`). Cloud Function
  `onTaskUpdated` (push technicien→manager à la soumission, manager→technicien à la validation).
  Règles durcies (l'assigné ne peut plus poser `approved`). **Reste côté user : déployer
  `firestore:rules` + `functions`, lancer les tests de règles (émulateur), valider sur appareil.**
```

- [ ] **Step 3: Update HANDOFF.md**

Dans `docs/HANDOFF.md`, sous « Reporté aux cycles suivants », remplacer l'entrée « Cycle #4 » par un renvoi à la livraison, et ajouter une section « Cycle #4 — livré » résumant : fichiers (`onTaskUpdated.ts`, `approval.ts`, `actions/approveTask.ts`, `board/[taskId]/page.tsx`), durcissement des règles, et le **Reste à faire côté user** :

```
## Cycle #4 — boucle manager (validation) : livré (code)
Spec : `docs/superpowers/specs/2026-06-07-cycle-4-boucle-manager-design.md`.
Plan : `docs/superpowers/plans/2026-06-07-cycle-4-boucle-manager.md`.

- **Functions** : `onTaskUpdated.ts` — un trigger `onDocumentUpdated('tasks/{taskId}')` route
  deux push (→done : au createdBy/manager ; →approved : à l'assigneeId/technicien), réutilise
  `splitInvalidTokens`. Tests jest verts.
- **Règles** : l'assigné ne peut poser `status` que dans {in_progress, done} ; `approved`
  réservé au manager. Tests de règles ajoutés (à lancer via l'émulateur).
- **Web** : `mapTaskDoc` étendu (détail rapport + approvedBy/approvedAt) ; garde pure
  `canApprove` ; Server Action `approveTask` (re-check rôle serveur + transaction garde
  `status==='done'`) ; route détail `(dashboard)/board/[taskId]` (rapport + photos + Valider) ;
  cartes board cliquables + badges « à valider » / « ✓ validé ». `jest`/`tsc`/`eslint`/`next build` OK.
- **Mobile** : `TaskStatus.approved` en lecture seule (libellé « validé », aucune action).

### Reste à faire côté toi (Cycle #4)
1. `cd firebase && firebase deploy --only firestore:rules,functions` (vérifier `onTaskUpdated`).
2. Tests de règles : `firebase emulators:exec --only firestore "cd functions && npx jest rules"`.
3. Déployer le backoffice sur Vercel.
4. Valider sur appareil : technicien clôture → manager reçoit le push → ouvre le détail au
   backoffice → Valider → technicien reçoit le push de validation.
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/HANDOFF.md
git commit -m "docs(cycle-4): schema tasks (approved + approvedBy/At), statut et handoff"
```

---

## Self-Review (rempli par le rédacteur du plan)

**Couverture de la spec :**
- Modèle (`approvedBy`/`approvedAt`, statut `approved`) → Tasks 3, 5, 7, 8 ✓
- Cloud Function un seul trigger + routeur → Task 1 ✓
- Vue détail + rapport + photos + Valider → Task 6 ✓
- Server Action (re-check rôle + transaction garde done) → Tasks 4, 5 ✓
- Board : cartes cliquables + badges approved/done → Task 6 ✓
- Durcissement règles + tests → Task 2 ✓
- Mobile lecture seule → Task 7 ✓
- Tests (functions/web/règles/mobile) → présents dans chaque task ✓
- Photos affichées directement (URLs token, pas de signature) → Task 6 ✓

**Cohérence des types :** `routeStatusChange`/`StatusNotice`/`buildReportSubmittedMessage`/
`buildApprovedMessage` (Task 1) cohérents entre test et impl. `canApprove(role, status)`
(Task 4) appelé à l'identique dans `approveTask` (Task 5). `mapTaskDoc` → `TaskRow.report`
(Task 3) consommé tel quel par la vue détail (Task 6).

**Pas de placeholder :** chaque étape de code montre le code complet ; commandes + attendus
explicites. La seule étape « lancée par l'utilisateur » (émulateur de règles) est signalée
comme telle avec son attendu, conformément aux gotchas environnement du projet.
