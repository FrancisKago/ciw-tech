# Phase 3 — Backoffice de suivi : Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Doter le backoffice `web/` d'une navigation, d'un board des tâches lecture seule (statuts + retards), de statistiques sur période glissante, et de la résolution des noms — sans aucune écriture Firestore.

**Architecture:** Toute la logique métier est isolée dans des helpers purs (`lib/board.ts`, `lib/stats.ts`, `lib/directory.ts`) couverts par jest. Les pages sont des Server Components Next.js 16 qui chargent les données via Firebase Admin, appellent ces helpers, et résolvent les IDs en noms. Le contrôle d'accès est centralisé dans le layout du groupe de routes `(dashboard)`. Filtres et période passent par `searchParams` (aucun JavaScript client hormis le surlignage du lien actif de la sidebar).

**Tech Stack:** Next.js 16 (App Router, Server Components), React 19, Firebase Admin SDK, Tailwind CSS v4, jest + ts-jest.

**Spec :** `docs/superpowers/specs/2026-06-07-phase-3-suivi-backoffice-design.md`

---

## Conventions (rappel)

- **TDD strict** sur la logique pure : test rouge → vert → commit. Les Server Components (pages, layout, sidebar) ne sont pas testés unitairement (pas de harnais React ici, jest est en env `node`) ; ils sont validés par `npx next build` + `npx eslint`.
- Tests dans `web/__tests__/<nom>.test.ts`. Lancer depuis `web/` : `npx jest`.
- Commits atomiques, messages français : `feat(web):` / `refactor(web):` / `docs(web):`.
- Identité git : `Cameroon Innovation <camerooninnovation58@gmail.com>` (déjà configurée).
- ⚠️ **Next.js 16** : `searchParams` est un `Promise` à `await` dans la page. Voir `node_modules/next/dist/docs/01-app/01-getting-started/03-layouts-and-pages.md`.
- Toutes les commandes s'exécutent depuis `D:\App pointage\web`.

## Structure des fichiers

**Créés :**
- `web/src/lib/directory.ts` — type `Directory` + `displayUser` / `displaySite` (purs) + `loadDirectory` (charge users + sites).
- `web/src/lib/board.ts` — types `BoardTask` / `BoardColumns` + `isLate` + `groupByStatus` (purs).
- `web/src/lib/stats.ts` — types `StatsPunch` / `StatsTask` / `Period` + `parsePeriod` / `hoursPerTechnician` / `completionByKey` / `lateCountByKey` / `hoursPerSite` (purs ; importe `isLate`).
- `web/src/components/Sidebar.tsx` — navigation latérale (Client Component, lien actif surligné).
- `web/src/app/(dashboard)/layout.tsx` — coquille sidebar + role gate centralisé.
- `web/src/app/(dashboard)/board/page.tsx` — board lecture seule.
- `web/src/app/(dashboard)/stats/page.tsx` — statistiques.
- Tests : `web/__tests__/directory.test.ts`, `board.test.ts`, `stats.test.ts`.

**Modifiés :**
- `web/src/app/(dashboard)/presence/page.tsx` — noms résolus, suppression du role gate dupliqué.
- `web/src/app/(dashboard)/tasks/page.tsx` — noms résolus, suppression du role gate dupliqué.
- `docs/HANDOFF.md` — état Phase 3.

---

## Task 1 : `lib/directory.ts` — résolution des noms

**Files:**
- Create: `web/src/lib/directory.ts`
- Test: `web/__tests__/directory.test.ts`

- [ ] **Step 1 : Écrire le test rouge**

`web/__tests__/directory.test.ts` :

```ts
import { displayUser, displaySite, Directory } from "@/lib/directory";

const dir: Directory = {
  users: new Map([["u1", { name: "Paul Mbarga" }]]),
  sites: new Map([["s1", { name: "Douala-Nord" }]]),
};

describe("displayUser", () => {
  it("renvoie le nom quand l'utilisateur est connu", () => {
    expect(displayUser("u1", dir)).toBe("Paul Mbarga");
  });
  it("renvoie l'ID en repli quand l'utilisateur est inconnu", () => {
    expect(displayUser("u404", dir)).toBe("u404");
  });
});

describe("displaySite", () => {
  it("renvoie le nom quand le site est connu", () => {
    expect(displaySite("s1", dir)).toBe("Douala-Nord");
  });
  it("renvoie l'ID en repli quand le site est inconnu", () => {
    expect(displaySite("s404", dir)).toBe("s404");
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest directory`
Expected: FAIL — `Cannot find module '@/lib/directory'`.

- [ ] **Step 3 : Implémenter `lib/directory.ts`**

```ts
import type { Firestore } from "firebase-admin/firestore";

export interface Directory {
  users: Map<string, { name: string }>;
  sites: Map<string, { name: string }>;
}

/** Nom du technicien, ou son ID en repli si inconnu. */
export function displayUser(uid: string, dir: Directory): string {
  return dir.users.get(uid)?.name ?? uid;
}

/** Nom du site, ou son ID en repli si inconnu. */
export function displaySite(siteId: string, dir: Directory): string {
  return dir.sites.get(siteId)?.name ?? siteId;
}

/** Charge les collections users + sites dans des Map indexées par ID. */
export async function loadDirectory(db: Firestore): Promise<Directory> {
  const [usersSnap, sitesSnap] = await Promise.all([
    db.collection("users").get(),
    db.collection("sites").get(),
  ]);
  const users = new Map<string, { name: string }>();
  for (const d of usersSnap.docs) {
    users.set(d.id, { name: (d.data().name as string) ?? d.id });
  }
  const sites = new Map<string, { name: string }>();
  for (const d of sitesSnap.docs) {
    sites.set(d.id, { name: (d.data().name as string) ?? d.id });
  }
  return { users, sites };
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest directory`
Expected: PASS (4 tests).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/directory.ts web/__tests__/directory.test.ts
git commit -m "feat(web): resolution des noms users/sites (lib/directory)"
```

---

## Task 2 : `lib/board.ts` — colonnes & détection des retards

**Files:**
- Create: `web/src/lib/board.ts`
- Test: `web/__tests__/board.test.ts`

- [ ] **Step 1 : Écrire le test rouge**

`web/__tests__/board.test.ts` :

```ts
import { isLate, groupByStatus, BoardTask } from "@/lib/board";

const now = new Date(Date.UTC(2026, 5, 7, 12, 0)); // 7 juin 2026 12:00 UTC
const task = (over: Partial<BoardTask>): BoardTask => ({
  id: "t", title: "T", siteId: "s1", assigneeId: "u1",
  status: "assigned", dueAt: null, hasReport: false, ...over,
});

describe("isLate", () => {
  it("vrai si échéance passée et statut non terminé", () => {
    expect(isLate(task({ dueAt: new Date(Date.UTC(2026, 5, 5)), status: "assigned" }), now)).toBe(true);
  });
  it("faux si échéance future", () => {
    expect(isLate(task({ dueAt: new Date(Date.UTC(2026, 5, 9)), status: "assigned" }), now)).toBe(false);
  });
  it("faux si la tâche est terminée même en retard", () => {
    expect(isLate(task({ dueAt: new Date(Date.UTC(2026, 5, 5)), status: "done" }), now)).toBe(false);
  });
  it("faux si pas d'échéance", () => {
    expect(isLate(task({ dueAt: null }), now)).toBe(false);
  });
});

describe("groupByStatus", () => {
  it("répartit les tâches dans les 3 colonnes", () => {
    const cols = groupByStatus([
      task({ id: "a", status: "assigned" }),
      task({ id: "b", status: "in_progress" }),
      task({ id: "c", status: "done" }),
      task({ id: "d", status: "approved" }),
    ]);
    expect(cols.assigned.map((t) => t.id)).toEqual(["a"]);
    expect(cols.in_progress.map((t) => t.id)).toEqual(["b"]);
    expect(cols.done.map((t) => t.id)).toEqual(["c", "d"]); // approved compté comme terminé
  });
  it("range un statut inconnu dans 'À faire' pour ne perdre aucune tâche", () => {
    const cols = groupByStatus([task({ id: "x", status: "weird" })]);
    expect(cols.assigned.map((t) => t.id)).toEqual(["x"]);
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest board`
Expected: FAIL — `Cannot find module '@/lib/board'`.

- [ ] **Step 3 : Implémenter `lib/board.ts`**

```ts
export interface BoardTask {
  id: string;
  title: string;
  siteId: string;
  assigneeId: string;
  status: string;
  dueAt: Date | null;
  hasReport: boolean;
}

export interface BoardColumns {
  assigned: BoardTask[];
  in_progress: BoardTask[];
  done: BoardTask[];
}

/** Une tâche est en retard si son échéance est passée et qu'elle n'est pas terminée. */
export function isLate(task: { dueAt: Date | null; status: string }, now: Date): boolean {
  if (!task.dueAt) return false;
  if (task.status === "done" || task.status === "approved") return false;
  return task.dueAt.getTime() < now.getTime();
}

/** Range les tâches par colonne. done/approved → 'done' ; tout autre statut → 'assigned'. */
export function groupByStatus(tasks: BoardTask[]): BoardColumns {
  const cols: BoardColumns = { assigned: [], in_progress: [], done: [] };
  for (const t of tasks) {
    if (t.status === "in_progress") cols.in_progress.push(t);
    else if (t.status === "done" || t.status === "approved") cols.done.push(t);
    else cols.assigned.push(t);
  }
  return cols;
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest board`
Expected: PASS (6 tests).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/board.ts web/__tests__/board.test.ts
git commit -m "feat(web): logique board (colonnes par statut + detection retard)"
```

---

## Task 3 : `lib/stats.ts` — analyse de la période

**Files:**
- Create: `web/src/lib/stats.ts`
- Test: `web/__tests__/stats.test.ts`

- [ ] **Step 1 : Écrire le test rouge**

`web/__tests__/stats.test.ts` :

```ts
import { parsePeriod } from "@/lib/stats";

const now = new Date(Date.UTC(2026, 5, 7, 15, 30)); // 7 juin 2026 15:30 UTC

describe("parsePeriod", () => {
  it("défaut = 7 derniers jours quand non précisé", () => {
    const p = parsePeriod(undefined, now);
    expect(p.period).toBe("7d");
    expect(p.start).toEqual(new Date(now.getTime() - 7 * 86400000));
    expect(p.end).toEqual(now);
  });
  it("'today' démarre à minuit UTC", () => {
    const p = parsePeriod("today", now);
    expect(p.period).toBe("today");
    expect(p.start).toEqual(new Date(Date.UTC(2026, 5, 7, 0, 0, 0, 0)));
  });
  it("'30d' remonte 30 jours", () => {
    const p = parsePeriod("30d", now);
    expect(p.start).toEqual(new Date(now.getTime() - 30 * 86400000));
  });
  it("valeur inconnue retombe sur 7d", () => {
    expect(parsePeriod("bogus", now).period).toBe("7d");
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest stats`
Expected: FAIL — `Cannot find module '@/lib/stats'`.

- [ ] **Step 3 : Implémenter le squelette de `lib/stats.ts`**

```ts
import { computeWorkedMinutes, PunchLite } from "@/lib/hours";
import { isLate } from "@/lib/board";

export interface StatsPunch { userId: string; kind: "in" | "out"; at: Date; siteId: string; }
export interface StatsTask { assigneeId: string; siteId: string; status: string; dueAt: Date | null; }

export type PeriodKey = "today" | "7d" | "30d";
export interface Period { period: PeriodKey; start: Date; end: Date; }

const DAY = 86400000;

/** Traduit le paramètre d'URL en plage de dates. Défaut et repli : 7 derniers jours. */
export function parsePeriod(raw: string | undefined, now: Date): Period {
  if (raw === "today") {
    const start = new Date(now);
    start.setUTCHours(0, 0, 0, 0);
    return { period: "today", start, end: now };
  }
  if (raw === "30d") return { period: "30d", start: new Date(now.getTime() - 30 * DAY), end: now };
  return { period: "7d", start: new Date(now.getTime() - 7 * DAY), end: now };
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest stats`
Expected: PASS (4 tests).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/stats.ts web/__tests__/stats.test.ts
git commit -m "feat(web): stats - parsing de la periode glissante"
```

---

## Task 4 : `lib/stats.ts` — heures par technicien

**Files:**
- Modify: `web/src/lib/stats.ts`
- Test: `web/__tests__/stats.test.ts`

- [ ] **Step 1 : Ajouter le test rouge**

Ajouter à `web/__tests__/stats.test.ts` :

```ts
import { hoursPerTechnician, StatsPunch } from "@/lib/stats";

const at = (h: number) => new Date(Date.UTC(2026, 5, 6, h));
const punch = (userId: string, kind: "in" | "out", h: number): StatsPunch =>
  ({ userId, kind, at: at(h), siteId: "s1" });

describe("hoursPerTechnician", () => {
  it("somme les minutes travaillées par technicien", () => {
    const map = hoursPerTechnician([
      punch("u1", "in", 8), punch("u1", "out", 12),
      punch("u2", "in", 9), punch("u2", "out", 10),
    ]);
    expect(map.get("u1")?.minutes).toBe(4 * 60);
    expect(map.get("u2")?.minutes).toBe(60);
  });
  it("remonte les anomalies par technicien", () => {
    const map = hoursPerTechnician([punch("u1", "in", 8)]);
    expect(map.get("u1")?.anomalies).toContain("in sans out");
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest stats`
Expected: FAIL — `hoursPerTechnician is not a function`.

- [ ] **Step 3 : Ajouter `hoursPerTechnician` à `lib/stats.ts`**

```ts
/** Regroupe les pointages par technicien et calcule minutes + anomalies pour chacun. */
export function hoursPerTechnician(
  punches: StatsPunch[],
): Map<string, { minutes: number; anomalies: string[] }> {
  const byUser = new Map<string, PunchLite[]>();
  for (const p of punches) {
    const list = byUser.get(p.userId) ?? [];
    list.push({ kind: p.kind, at: p.at });
    byUser.set(p.userId, list);
  }
  const out = new Map<string, { minutes: number; anomalies: string[] }>();
  for (const [uid, list] of byUser) out.set(uid, computeWorkedMinutes(list));
  return out;
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest stats`
Expected: PASS (6 tests).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/stats.ts web/__tests__/stats.test.ts
git commit -m "feat(web): stats - heures pointees par technicien"
```

---

## Task 5 : `lib/stats.ts` — taux de complétion par clé

**Files:**
- Modify: `web/src/lib/stats.ts`
- Test: `web/__tests__/stats.test.ts`

- [ ] **Step 1 : Ajouter le test rouge**

Ajouter à `web/__tests__/stats.test.ts` :

```ts
import { completionByKey, StatsTask } from "@/lib/stats";

const range = { start: new Date(Date.UTC(2026, 5, 1)), end: new Date(Date.UTC(2026, 5, 30)) };
const sTask = (over: Partial<StatsTask>): StatsTask =>
  ({ assigneeId: "u1", siteId: "s1", status: "assigned", dueAt: new Date(Date.UTC(2026, 5, 10)), ...over });

describe("completionByKey", () => {
  it("compte done/total par technicien sur les tâches dont l'échéance tombe dans la période", () => {
    const map = completionByKey([
      sTask({ assigneeId: "u1", status: "done" }),
      sTask({ assigneeId: "u1", status: "assigned" }),
      sTask({ assigneeId: "u2", status: "done" }),
    ], range, "assigneeId");
    expect(map.get("u1")).toEqual({ done: 1, total: 2 });
    expect(map.get("u2")).toEqual({ done: 1, total: 1 });
  });
  it("ignore les tâches sans échéance ou hors période", () => {
    const map = completionByKey([
      sTask({ dueAt: null }),
      sTask({ dueAt: new Date(Date.UTC(2026, 0, 1)) }),
    ], range, "assigneeId");
    expect(map.size).toBe(0);
  });
  it("peut agréger par site", () => {
    const map = completionByKey([sTask({ siteId: "s9", status: "done" })], range, "siteId");
    expect(map.get("s9")).toEqual({ done: 1, total: 1 });
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest stats`
Expected: FAIL — `completionByKey is not a function`.

- [ ] **Step 3 : Ajouter `completionByKey` à `lib/stats.ts`**

```ts
function inRange(d: Date | null, start: Date, end: Date): boolean {
  return d != null && d.getTime() >= start.getTime() && d.getTime() <= end.getTime();
}

/**
 * Taux de complétion par clé ('assigneeId' ou 'siteId').
 * Périmètre = tâches dont l'échéance tombe dans la période. done/approved comptent comme terminées.
 */
export function completionByKey(
  tasks: StatsTask[],
  range: { start: Date; end: Date },
  key: "assigneeId" | "siteId",
): Map<string, { done: number; total: number }> {
  const out = new Map<string, { done: number; total: number }>();
  for (const t of tasks) {
    if (!inRange(t.dueAt, range.start, range.end)) continue;
    const k = t[key];
    const cur = out.get(k) ?? { done: 0, total: 0 };
    cur.total += 1;
    if (t.status === "done" || t.status === "approved") cur.done += 1;
    out.set(k, cur);
  }
  return out;
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest stats`
Expected: PASS (9 tests).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/stats.ts web/__tests__/stats.test.ts
git commit -m "feat(web): stats - taux de completion par technicien/site"
```

---

## Task 6 : `lib/stats.ts` — comptage des retards par clé

**Files:**
- Modify: `web/src/lib/stats.ts`
- Test: `web/__tests__/stats.test.ts`

- [ ] **Step 1 : Ajouter le test rouge**

Ajouter à `web/__tests__/stats.test.ts` :

```ts
import { lateCountByKey } from "@/lib/stats";

describe("lateCountByKey", () => {
  const now = new Date(Date.UTC(2026, 5, 7));
  it("compte les tâches en retard par technicien", () => {
    const map = lateCountByKey([
      sTask({ assigneeId: "u1", dueAt: new Date(Date.UTC(2026, 5, 5)), status: "assigned" }), // retard
      sTask({ assigneeId: "u1", dueAt: new Date(Date.UTC(2026, 5, 9)), status: "assigned" }), // futur
      sTask({ assigneeId: "u1", dueAt: new Date(Date.UTC(2026, 5, 5)), status: "done" }),      // terminé
    ], now, "assigneeId");
    expect(map.get("u1")).toBe(1);
  });
  it("n'ajoute pas de clé sans retard", () => {
    const map = lateCountByKey([sTask({ dueAt: new Date(Date.UTC(2026, 5, 9)) })], now, "assigneeId");
    expect(map.size).toBe(0);
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest stats`
Expected: FAIL — `lateCountByKey is not a function`.

- [ ] **Step 3 : Ajouter `lateCountByKey` à `lib/stats.ts`** (réutilise `isLate` déjà importé)

```ts
/** Nombre de tâches en retard par clé ('assigneeId' ou 'siteId'). */
export function lateCountByKey(
  tasks: StatsTask[],
  now: Date,
  key: "assigneeId" | "siteId",
): Map<string, number> {
  const out = new Map<string, number>();
  for (const t of tasks) {
    if (!isLate(t, now)) continue;
    out.set(t[key], (out.get(t[key]) ?? 0) + 1);
  }
  return out;
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest stats`
Expected: PASS (11 tests).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/stats.ts web/__tests__/stats.test.ts
git commit -m "feat(web): stats - comptage des taches en retard par technicien/site"
```

---

## Task 7 : `lib/stats.ts` — heures par site (bonus)

**Files:**
- Modify: `web/src/lib/stats.ts`
- Test: `web/__tests__/stats.test.ts`

- [ ] **Step 1 : Ajouter le test rouge**

Ajouter à `web/__tests__/stats.test.ts` :

```ts
import { hoursPerSite } from "@/lib/stats";

describe("hoursPerSite", () => {
  it("somme les minutes par site (apparie in/out par technicien dans chaque site)", () => {
    const map = hoursPerSite([
      { userId: "u1", kind: "in", at: at(8), siteId: "sA" },
      { userId: "u1", kind: "out", at: at(12), siteId: "sA" },
      { userId: "u2", kind: "in", at: at(9), siteId: "sB" },
      { userId: "u2", kind: "out", at: at(10), siteId: "sB" },
    ]);
    expect(map.get("sA")).toBe(4 * 60);
    expect(map.get("sB")).toBe(60);
  });
});
```

- [ ] **Step 2 : Vérifier l'échec**

Run: `npx jest stats`
Expected: FAIL — `hoursPerSite is not a function`.

- [ ] **Step 3 : Ajouter `hoursPerSite` à `lib/stats.ts`**

```ts
/** Minutes pointées par site (pairage in/out par technicien à l'intérieur de chaque site). */
export function hoursPerSite(punches: StatsPunch[]): Map<string, number> {
  const bySite = new Map<string, StatsPunch[]>();
  for (const p of punches) {
    const list = bySite.get(p.siteId) ?? [];
    list.push(p);
    bySite.set(p.siteId, list);
  }
  const out = new Map<string, number>();
  for (const [siteId, list] of bySite) {
    let minutes = 0;
    const byUser = new Map<string, PunchLite[]>();
    for (const p of list) {
      const u = byUser.get(p.userId) ?? [];
      u.push({ kind: p.kind, at: p.at });
      byUser.set(p.userId, u);
    }
    for (const u of byUser.values()) minutes += computeWorkedMinutes(u).minutes;
    out.set(siteId, minutes);
  }
  return out;
}
```

- [ ] **Step 4 : Vérifier le vert**

Run: `npx jest stats`
Expected: PASS (12 tests). Lancer aussi `npx jest` pour confirmer **toute** la suite verte (existants + nouveaux).

- [ ] **Step 5 : Commit**

```bash
git add web/src/lib/stats.ts web/__tests__/stats.test.ts
git commit -m "feat(web): stats - heures pointees par site (bonus)"
```

---

## Task 8 : `components/Sidebar.tsx` — navigation latérale

**Files:**
- Create: `web/src/components/Sidebar.tsx`

Pas de test unitaire (Client Component) — validé par `next build` + `eslint` en Task 14. Utilise `usePathname` pour surligner le lien actif (d'où `"use client"`).

- [ ] **Step 1 : Créer `web/src/components/Sidebar.tsx`**

```tsx
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/presence", label: "Présence" },
  { href: "/tasks", label: "Tâches" },
  { href: "/board", label: "Board" },
  { href: "/stats", label: "Stats" },
  { href: "/sites", label: "Sites" },
];

export default function Sidebar() {
  const pathname = usePathname();
  return (
    <nav className="w-48 shrink-0 border-r border-gray-200 bg-gray-50 p-4 min-h-screen">
      <div className="mb-6 text-sm font-semibold text-gray-700">Cameroon Innovation</div>
      <ul className="space-y-1">
        {LINKS.map((l) => {
          const active = pathname === l.href || pathname.startsWith(l.href + "/");
          return (
            <li key={l.href}>
              <Link
                href={l.href}
                className={
                  "block rounded px-3 py-2 text-sm " +
                  (active ? "bg-gray-900 text-white" : "text-gray-700 hover:bg-gray-200")
                }
              >
                {l.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
```

- [ ] **Step 2 : Commit**

```bash
git add web/src/components/Sidebar.tsx
git commit -m "feat(web): composant Sidebar de navigation du backoffice"
```

---

## Task 9 : `(dashboard)/layout.tsx` — coquille + role gate centralisé

**Files:**
- Create: `web/src/app/(dashboard)/layout.tsx`

Centralise le contrôle d'accès aujourd'hui dupliqué dans chaque page. Validé par `next build` en Task 14.

- [ ] **Step 1 : Créer `web/src/app/(dashboard)/layout.tsx`**

```tsx
import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { getUserRole } from "@/lib/currentRole";
import { canAccessBackoffice } from "@/lib/roles";
import Sidebar from "@/components/Sidebar";

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { userId } = await auth();
  if (!userId) redirect("/");

  const role = await getUserRole(userId);
  if (!canAccessBackoffice(role)) {
    return (
      <div style={{ padding: 48, maxWidth: 560, margin: "0 auto", textAlign: "center" }}>
        <h1 style={{ fontSize: 24, fontWeight: 600 }}>Accès refusé</h1>
        <p style={{ marginTop: 12, color: "#555" }}>
          Le backoffice est réservé à la direction (rôle <code>admin</code> ou{" "}
          <code>manager</code>). Votre rôle actuel : <strong>{role ?? "non défini"}</strong>.
        </p>
      </div>
    );
  }

  return (
    <div style={{ display: "flex" }}>
      <Sidebar />
      <div style={{ flex: 1 }}>{children}</div>
    </div>
  );
}
```

- [ ] **Step 2 : Commit**

```bash
git add "web/src/app/(dashboard)/layout.tsx"
git commit -m "feat(web): layout dashboard avec sidebar et role gate centralise"
```

---

## Task 10 : `(dashboard)/board/page.tsx` — board lecture seule

**Files:**
- Create: `web/src/app/(dashboard)/board/page.tsx`

Charge tâches + directory, filtre via `searchParams`, groupe par statut, rend 3 colonnes. Lecture seule. Validé par `next build`.

- [ ] **Step 1 : Créer `web/src/app/(dashboard)/board/page.tsx`**

```tsx
import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite, Directory } from "@/lib/directory";
import { groupByStatus, isLate, BoardTask, BoardColumns } from "@/lib/board";

export const dynamic = "force-dynamic";

const COLS: { key: keyof BoardColumns; label: string }[] = [
  { key: "assigned", label: "À faire" },
  { key: "in_progress", label: "En cours" },
  { key: "done", label: "Terminé" },
];

export default async function BoardPage({
  searchParams,
}: {
  searchParams: Promise<{ site?: string; tech?: string }>;
}) {
  const sp = await searchParams;
  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("tasks").orderBy("createdAt", "desc").get(),
    loadDirectory(database),
  ]);

  const tasks: BoardTask[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      title: data.title ?? "",
      siteId: data.siteId ?? "",
      assigneeId: data.assigneeId ?? "",
      status: data.status ?? "assigned",
      dueAt: data.dueAt ? data.dueAt.toDate() : null,
      hasReport: data.report != null,
    };
  });

  const filtered = tasks.filter(
    (t) => (!sp.site || t.siteId === sp.site) && (!sp.tech || t.assigneeId === sp.tech),
  );
  const columns = groupByStatus(filtered);
  const now = new Date();

  return (
    <main className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Board des tâches</h1>

      <form method="get" className="mb-6 flex gap-3 text-sm">
        <select name="site" defaultValue={sp.site ?? ""} className="rounded border px-2 py-1">
          <option value="">Tous les sites</option>
          {[...dir.sites.entries()].map(([id, s]) => (
            <option key={id} value={id}>{s.name}</option>
          ))}
        </select>
        <select name="tech" defaultValue={sp.tech ?? ""} className="rounded border px-2 py-1">
          <option value="">Tous les techniciens</option>
          {[...dir.users.entries()].map(([id, u]) => (
            <option key={id} value={id}>{u.name}</option>
          ))}
        </select>
        <button type="submit" className="rounded bg-gray-900 px-3 py-1 text-white">Filtrer</button>
      </form>

      <div className="flex gap-4">
        {COLS.map((col) => (
          <section key={col.key} className="flex-1">
            <div className="mb-2 text-xs font-semibold uppercase text-gray-500">
              {col.label} · {columns[col.key].length}
            </div>
            <div className="space-y-2">
              {columns[col.key].map((t) => (
                <Card key={t.id} task={t} dir={dir} late={isLate(t, now)} />
              ))}
              {columns[col.key].length === 0 && (
                <p className="text-sm text-gray-400">—</p>
              )}
            </div>
          </section>
        ))}
      </div>
    </main>
  );
}

function Card({ task, dir, late }: { task: BoardTask; dir: Directory; late: boolean }) {
  return (
    <div
      className={
        "rounded-lg border bg-white p-3 shadow-sm " +
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
          {task.hasReport && <span className="ml-2 text-green-700">✓ rapport</span>}
        </div>
      )}
    </div>
  );
}

function fmt(d: Date | null): string {
  return d ? d.toLocaleDateString("fr-FR", { day: "numeric", month: "short" }) : "—";
}
```

- [ ] **Step 2 : Commit**

```bash
git add "web/src/app/(dashboard)/board/page.tsx"
git commit -m "feat(web): page board des taches (lecture seule, filtres, retards)"
```

---

## Task 11 : `(dashboard)/stats/page.tsx` — statistiques

**Files:**
- Create: `web/src/app/(dashboard)/stats/page.tsx`

Période via `searchParams`, charge tasks + punches, assemble les lignes par technicien et par site via les helpers de `lib/stats`. Validé par `next build`.

- [ ] **Step 1 : Créer `web/src/app/(dashboard)/stats/page.tsx`**

```tsx
import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";
import {
  parsePeriod, hoursPerTechnician, completionByKey, lateCountByKey, hoursPerSite,
  StatsPunch, StatsTask, PeriodKey,
} from "@/lib/stats";

export const dynamic = "force-dynamic";

const PERIODS: { key: PeriodKey; label: string }[] = [
  { key: "today", label: "Aujourd'hui" },
  { key: "7d", label: "7 jours" },
  { key: "30d", label: "30 jours" },
];

export default async function StatsPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string }>;
}) {
  const sp = await searchParams;
  const now = new Date();
  const { period, start, end } = parsePeriod(sp.period, now);

  const database = db();
  const [tasksSnap, punchesSnap, dir] = await Promise.all([
    database.collection("tasks").get(),
    database.collection("punches").where("clientTimestamp", ">=", start).get(),
    loadDirectory(database),
  ]);

  const punches: StatsPunch[] = punchesSnap.docs.map((d) => {
    const data = d.data();
    return { userId: data.userId, kind: data.kind, at: data.clientTimestamp.toDate(), siteId: data.siteId ?? "" };
  });
  const tasks: StatsTask[] = tasksSnap.docs.map((d) => {
    const data = d.data();
    return {
      assigneeId: data.assigneeId ?? "",
      siteId: data.siteId ?? "",
      status: data.status ?? "assigned",
      dueAt: data.dueAt ? data.dueAt.toDate() : null,
    };
  });

  const range = { start, end };
  const hoursT = hoursPerTechnician(punches);
  const compT = completionByKey(tasks, range, "assigneeId");
  const lateT = lateCountByKey(tasks, now, "assigneeId");
  const techKeys = new Set<string>([...hoursT.keys(), ...compT.keys(), ...lateT.keys()]);

  const hoursS = hoursPerSite(punches);
  const compS = completionByKey(tasks, range, "siteId");
  const lateS = lateCountByKey(tasks, now, "siteId");
  const siteKeys = new Set<string>([...hoursS.keys(), ...compS.keys(), ...lateS.keys()]);

  return (
    <main className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Statistiques</h1>

      <div className="mb-6 flex gap-2 text-sm">
        {PERIODS.map((p) => (
          <a
            key={p.key}
            href={`/stats?period=${p.key}`}
            className={
              "rounded px-3 py-1 " +
              (period === p.key ? "bg-gray-900 text-white" : "border text-gray-700 hover:bg-gray-100")
            }
          >
            {p.label}
          </a>
        ))}
      </div>

      <h2 className="mb-2 text-lg font-semibold">Par technicien</h2>
      <table className="mb-8 w-full max-w-3xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Technicien</th><th>Heures</th><th>Complétion</th><th>Retards</th><th>Anomalies</th>
          </tr>
        </thead>
        <tbody>
          {[...techKeys].map((uid) => {
            const h = hoursT.get(uid);
            const c = compT.get(uid);
            return (
              <tr key={uid} className="border-b">
                <td className="py-2">{displayUser(uid, dir)}</td>
                <td>{((h?.minutes ?? 0) / 60).toFixed(2)}</td>
                <td>{c ? `${c.done}/${c.total}` : "—"}</td>
                <td className={lateT.get(uid) ? "font-semibold text-red-600" : ""}>{lateT.get(uid) ?? 0}</td>
                <td className={h?.anomalies.length ? "text-red-600" : "text-gray-400"}>
                  {h?.anomalies.length ? h.anomalies.join(", ") : "—"}
                </td>
              </tr>
            );
          })}
          {techKeys.size === 0 && <tr><td colSpan={5} className="py-2 text-gray-400">Aucune donnée sur la période.</td></tr>}
        </tbody>
      </table>

      <h2 className="mb-2 text-lg font-semibold">Par site</h2>
      <table className="w-full max-w-3xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Site</th><th>Heures</th><th>Complétion</th><th>Retards</th>
          </tr>
        </thead>
        <tbody>
          {[...siteKeys].map((sid) => {
            const c = compS.get(sid);
            return (
              <tr key={sid} className="border-b">
                <td className="py-2">{displaySite(sid, dir)}</td>
                <td>{((hoursS.get(sid) ?? 0) / 60).toFixed(2)}</td>
                <td>{c ? `${c.done}/${c.total}` : "—"}</td>
                <td className={lateS.get(sid) ? "font-semibold text-red-600" : ""}>{lateS.get(sid) ?? 0}</td>
              </tr>
            );
          })}
          {siteKeys.size === 0 && <tr><td colSpan={4} className="py-2 text-gray-400">Aucune donnée sur la période.</td></tr>}
        </tbody>
      </table>
    </main>
  );
}
```

- [ ] **Step 2 : Commit**

```bash
git add "web/src/app/(dashboard)/stats/page.tsx"
git commit -m "feat(web): page stats (heures, completion, retards par technicien/site)"
```

---

## Task 12 : Refactor `presence/page.tsx` — noms + gate centralisé

**Files:**
- Modify: `web/src/app/(dashboard)/presence/page.tsx`

Supprime le bloc role gate (désormais dans le layout) et affiche le **nom** du technicien au lieu de l'`uid`.

- [ ] **Step 1 : Remplacer le contenu de `web/src/app/(dashboard)/presence/page.tsx`**

```tsx
import { db } from "@/lib/firebaseAdmin";
import { computeWorkedMinutes, PunchLite } from "@/lib/hours";
import { loadDirectory, displayUser } from "@/lib/directory";

export const dynamic = "force-dynamic";

export default async function PresencePage() {
  const start = new Date(); start.setUTCHours(0, 0, 0, 0);
  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("punches").where("clientTimestamp", ">=", start).get(),
    loadDirectory(database),
  ]);

  const byUser = new Map<string, PunchLite[]>();
  for (const d of snap.docs) {
    const data = d.data();
    const list = byUser.get(data.userId) ?? [];
    list.push({ kind: data.kind, at: data.clientTimestamp.toDate() });
    byUser.set(data.userId, list);
  }

  const rows = [...byUser.entries()].map(([uid, punches]) => {
    const { minutes, anomalies } = computeWorkedMinutes(punches);
    return { uid, hours: (minutes / 60).toFixed(2), anomalies };
  });

  return (
    <div className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Présence du jour</h1>
      <table className="w-full max-w-2xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Technicien</th><th>Heures</th><th>Anomalies</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.uid} className="border-b">
              <td className="py-2">{displayUser(r.uid, dir)}</td>
              <td>{r.hours}</td>
              <td className={r.anomalies.length ? "text-red-600" : "text-green-700"}>
                {r.anomalies.length ? r.anomalies.join(", ") : "—"}
              </td>
            </tr>
          ))}
          {rows.length === 0 && <tr><td colSpan={3} className="py-2 text-gray-400">Aucun pointage aujourd'hui.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2 : Commit**

```bash
git add "web/src/app/(dashboard)/presence/page.tsx"
git commit -m "refactor(web): presence - noms resolus, gate delegue au layout"
```

---

## Task 13 : Refactor `tasks/page.tsx` — noms + gate centralisé

**Files:**
- Modify: `web/src/app/(dashboard)/tasks/page.tsx`

Supprime le bloc role gate et affiche les **noms** (site + assigné). Conserve `mapTaskDoc` mais résout les IDs à l'affichage.

- [ ] **Step 1 : Remplacer le contenu de `web/src/app/(dashboard)/tasks/page.tsx`**

```tsx
import { db } from "@/lib/firebaseAdmin";
import { mapTaskDoc, TaskRow } from "@/lib/tasks";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";

export const dynamic = "force-dynamic";

export default async function TasksPage() {
  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("tasks").orderBy("createdAt", "desc").get(),
    loadDirectory(database),
  ]);
  const rows: TaskRow[] = snap.docs.map((d) => mapTaskDoc(d.id, d.data()));

  return (
    <main className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Tâches</h1>
      <table className="w-full max-w-4xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Titre</th><th>Site</th><th>Assigné</th><th>Statut</th><th>Échéance</th><th>Rapport</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((t) => (
            <tr key={t.id} className="border-b">
              <td className="py-2">{t.title}</td>
              <td>{displaySite(t.siteId, dir)}</td>
              <td>{displayUser(t.assigneeId, dir)}</td>
              <td>{t.status}</td>
              <td>{t.dueAt ? new Date(t.dueAt).toLocaleDateString("fr-FR") : "—"}</td>
              <td>{t.hasReport ? "✓" : "—"}</td>
            </tr>
          ))}
          {rows.length === 0 && <tr><td colSpan={6} className="py-2 text-gray-400">Aucune tâche.</td></tr>}
        </tbody>
      </table>
    </main>
  );
}
```

- [ ] **Step 2 : Commit**

```bash
git add "web/src/app/(dashboard)/tasks/page.tsx"
git commit -m "refactor(web): tasks - noms resolus, gate delegue au layout"
```

---

## Task 14 : Vérification finale + handoff

**Files:**
- Modify: `docs/HANDOFF.md`

- [ ] **Step 1 : Suite de tests complète**

Run: `cd "D:/App pointage/web" && npx jest`
Expected: PASS — les 12 tests existants + les nouveaux (directory 4, board 6, stats 12) tous verts.

- [ ] **Step 2 : Lint**

Run: `npx eslint`
Expected: aucune erreur (warnings acceptables s'ils préexistaient).

- [ ] **Step 3 : Build de production (vérifie pages, layout, sidebar, routes `/board` et `/stats`)**

Run: `npx next build`
Expected: build réussi, routes `/board` et `/stats` listées, aucune erreur de type.

> Si `next build` échoue sur un type `searchParams`, vérifier la signature `searchParams: Promise<...>` (convention Next 16) contre `node_modules/next/dist/docs/01-app/01-getting-started/03-layouts-and-pages.md`.

- [ ] **Step 4 : Mettre à jour `docs/HANDOFF.md`**

Mettre l'état Phase 3 à « livré (code) — board + stats + navigation + noms résolus, lecture seule », rappeler que la boucle manager (#4) et la dette mobile « managers = techniciens » (#5) restent à faire, et que le déploiement Vercel reste côté utilisateur.

- [ ] **Step 5 : Commit**

```bash
git add docs/HANDOFF.md
git commit -m "docs(web): handoff Phase 3 backoffice de suivi livre (code)"
```

---

## Auto-revue (couverture de la spec)

- Sidebar / navigation → Task 8, 9 ✅
- Résolution des noms (#6) → Task 1 ; appliquée dans Tasks 10, 11, 12, 13 ✅
- Board lecture seule, 3 colonnes, retards, filtres site/technicien → Task 2 (logique) + Task 10 (UI) ✅
- Stats période glissante → Task 3 ✅
- Heures pointées par technicien → Task 4 ✅
- Taux de complétion (échéance dans la période) par technicien/site → Task 5 ✅
- Tâches en retard par technicien/site → Task 6 ✅
- Anomalies (bonus) → exposées via Task 4 + affichées Task 11 ✅
- Activité par site / heures par site (bonus) → Task 7 + affichées Task 11 ✅
- Role gate centralisé → Task 9 ; retiré des pages Tasks 12, 13 ✅
- Tailwind nouvelles pages + alignement existant → Tasks 8–13 ✅
- Aucune écriture / aucun changement de règles → respecté (aucune server action ajoutée, aucune modif `firestore.rules`) ✅
- Tests verts + build OK → Task 14 ✅

**Cohérence des types vérifiée** : `Directory`, `BoardTask`/`BoardColumns`, `StatsPunch`/`StatsTask`/`Period`/`PeriodKey` et les signatures (`isLate`, `groupByStatus`, `parsePeriod`, `hoursPerTechnician`, `completionByKey`, `lateCountByKey`, `hoursPerSite`, `displayUser`, `displaySite`, `loadDirectory`) sont définies en Tasks 1–7 et réutilisées à l'identique en Tasks 10–13.
