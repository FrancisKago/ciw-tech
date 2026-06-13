# Détection d'anomalies de pointage — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner à la direction une page backoffice « Alertes » listant les pointages suspects (hors-rayon, GPS imprécis, photo manquante, sans site, doublon, horloge), calculés au rendu.

**Architecture:** Librairie de détection **pure et testée** (`web/src/lib/anomalies.ts`) consommée par une page Server Component (`/alertes`) qui charge les pointages de la période + l'annuaire (sites avec geo), calcule les anomalies, et n'affiche que les pointages signalés. **Aucun changement** de règles Firestore, de Cloud Function, ni du mobile. Lecture seule, dans la lignée de la Phase 3.

**Tech Stack:** Next.js 16 (App Router, Server Components), TypeScript, Firebase Admin SDK (lecture), Clerk (annuaire), Jest. Spec : `docs/superpowers/specs/2026-06-13-phase-4-detection-anomalies-design.md`.

**Branche :** travailler sur `phase-4-detection-anomalies` (déjà créée, contient la spec). Tous les chemins sont relatifs à la racine du repo `D:\App pointage`. Les commandes web se lancent depuis `web/` (`cd web`).

---

## Structure des fichiers

| Fichier | Rôle | Action |
|---|---|---|
| `web/src/lib/anomalies.ts` | Détection pure : types, seuils, `haversineMeters`, `detectAnomalies` | Créer |
| `web/__tests__/anomalies.test.ts` | Tests unitaires de toutes les règles | Créer |
| `web/src/lib/directory.ts` | Annuaire : étendre `sites` pour porter `geo` + `radiusMeters` | Modifier |
| `web/src/app/(dashboard)/alertes/page.tsx` | Page Alertes (Server Component) | Créer |
| `web/src/components/Sidebar.tsx` | Ajout de l'entrée de navigation « Alertes » | Modifier |

---

## Task 1: Helper `haversineMeters`

**Files:**
- Create: `web/src/lib/anomalies.ts`
- Test: `web/__tests__/anomalies.test.ts`

- [ ] **Step 1: Write the failing test**

Créer `web/__tests__/anomalies.test.ts` :

```ts
import { haversineMeters } from "@/lib/anomalies";

describe("haversineMeters", () => {
  it("renvoie ~0 pour deux points identiques", () => {
    expect(haversineMeters({ lat: 4.05, lng: 9.7 }, { lat: 4.05, lng: 9.7 })).toBeCloseTo(0, 5);
  });
  it("mesure ~111 m pour 0,001° de latitude", () => {
    // 0,001° de latitude ≈ 111,2 m partout sur le globe.
    const d = haversineMeters({ lat: 4.0, lng: 9.7 }, { lat: 4.001, lng: 9.7 });
    expect(d).toBeGreaterThan(105);
    expect(d).toBeLessThan(117);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web && npx jest anomalies`
Expected: FAIL — `Cannot find module '@/lib/anomalies'`.

- [ ] **Step 3: Write minimal implementation**

Créer `web/src/lib/anomalies.ts` :

```ts
const EARTH_RADIUS_M = 6371000;

/** Distance grand-cercle (mètres) entre deux points lat/lng. */
export function haversineMeters(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web && npx jest anomalies`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/anomalies.ts web/__tests__/anomalies.test.ts
git commit -m "feat(anomalies): helper haversineMeters (distance grand-cercle)"
```

---

## Task 2: `detectAnomalies` — toutes les règles (TDD règle par règle)

**Files:**
- Modify: `web/src/lib/anomalies.ts`
- Test: `web/__tests__/anomalies.test.ts`

D'abord ajouter les types et fabriques en tête de `anomalies.ts` (sous l'`EARTH_RADIUS_M`/`haversineMeters` existants), puis construire `detectAnomalies` règle par règle. Le **listing complet final** de la fonction est donné en fin de tâche (Step 15) pour référence.

- [ ] **Step 1: Ajouter types, seuils et fabriques**

Ajouter dans `web/src/lib/anomalies.ts` (au-dessus de `haversineMeters`) :

```ts
export type AnomalyType =
  | "hors-rayon"
  | "gps-imprecis"
  | "photo-manquante"
  | "sans-site"
  | "doublon"
  | "horloge";
export type AnomalySeverity = "alerte" | "info";
export interface Anomaly {
  type: AnomalyType;
  severity: AnomalySeverity;
  label: string;
}

export interface PunchForAnomaly {
  id: string;
  userId: string;
  kind: "in" | "out";
  clientTimestamp: Date;
  serverTimestamp: Date | null;
  geo: { lat: number; lng: number; accuracy: number } | null;
  siteId: string | null;
  photoStatus: "pending" | "uploaded";
}
export interface SiteGeo {
  geo: { lat: number; lng: number } | null;
  radiusMeters: number | null;
}

export interface AnomalyThresholds {
  gpsAccuracyMaxMeters: number;
  photoGraceHours: number;
  duplicateWindowMinutes: number;
  clockAheadMinutes: number;
}
export const DEFAULT_THRESHOLDS: AnomalyThresholds = {
  gpsAccuracyMaxMeters: 100,
  photoGraceHours: 24,
  duplicateWindowMinutes: 5,
  clockAheadMinutes: 10,
};

const SEVERITY: Record<AnomalyType, AnomalySeverity> = {
  "hors-rayon": "alerte",
  "sans-site": "alerte",
  horloge: "alerte",
  "gps-imprecis": "info",
  "photo-manquante": "info",
  doublon: "info",
};
const LABEL: Record<AnomalyType, string> = {
  "hors-rayon": "Hors rayon",
  "gps-imprecis": "GPS imprécis",
  "photo-manquante": "Photo manquante",
  "sans-site": "Sans site",
  doublon: "Doublon",
  horloge: "Horloge",
};
function anomaly(type: AnomalyType): Anomaly {
  return { type, severity: SEVERITY[type], label: LABEL[type] };
}
```

- [ ] **Step 2: Test « sans-site » (rouge)**

Ajouter à `web/__tests__/anomalies.test.ts` (en haut, après l'import, étendre l'import) :

```ts
import {
  haversineMeters,
  detectAnomalies,
  PunchForAnomaly,
  SiteGeo,
} from "@/lib/anomalies";

const NOW = new Date(Date.UTC(2026, 5, 13, 12, 0));
const base: PunchForAnomaly = {
  id: "p1",
  userId: "u1",
  kind: "in",
  clientTimestamp: new Date(Date.UTC(2026, 5, 13, 11, 0)),
  serverTimestamp: new Date(Date.UTC(2026, 5, 13, 11, 0)),
  geo: { lat: 4.05, lng: 9.7, accuracy: 20 },
  siteId: "s1",
  photoStatus: "uploaded",
};
const mk = (over: Partial<PunchForAnomaly>): PunchForAnomaly => ({ ...base, ...over });
// Site s1 centré sur la position du pointage de base, rayon 100 m.
const sites = new Map<string, SiteGeo>([
  ["s1", { geo: { lat: 4.05, lng: 9.7 }, radiusMeters: 100 }],
]);
const typesFor = (m: Map<string, import("@/lib/anomalies").Anomaly[]>, id: string) =>
  (m.get(id) ?? []).map((a) => a.type).sort();

describe("detectAnomalies — sans-site", () => {
  it("signale un pointage sans siteId", () => {
    const m = detectAnomalies([mk({ id: "p1", siteId: null })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("sans-site");
  });
  it("ne signale rien pour un pointage nominal", () => {
    const m = detectAnomalies([mk({ id: "p1" })], sites, NOW);
    expect(m.has("p1")).toBe(false);
  });
});
```

Run: `cd web && npx jest anomalies` → FAIL (`detectAnomalies` n'existe pas).

- [ ] **Step 3: Implémenter `detectAnomalies` avec la règle sans-site (vert)**

Ajouter au bas de `web/src/lib/anomalies.ts` :

```ts
export function detectAnomalies(
  punches: PunchForAnomaly[],
  sites: Map<string, SiteGeo>,
  now: Date,
  opts: Partial<AnomalyThresholds> = {},
): Map<string, Anomaly[]> {
  const t = { ...DEFAULT_THRESHOLDS, ...opts };
  const out = new Map<string, Anomaly[]>();

  for (const p of punches) {
    const list: Anomaly[] = [];

    if (p.siteId == null) list.push(anomaly("sans-site"));

    if (list.length) out.set(p.id, list);
  }

  return out;
}
```

Run: `cd web && npx jest anomalies` → PASS.

- [ ] **Step 4: Test « gps-imprécis » (rouge)**

Ajouter à `web/__tests__/anomalies.test.ts` :

```ts
describe("detectAnomalies — gps-imprecis", () => {
  it("signale accuracy > 100 m", () => {
    const m = detectAnomalies([mk({ id: "p1", geo: { lat: 4.05, lng: 9.7, accuracy: 150 } })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("gps-imprecis");
  });
  it("ne signale pas accuracy = 100 m (borne)", () => {
    const m = detectAnomalies([mk({ id: "p1", geo: { lat: 4.05, lng: 9.7, accuracy: 100 } })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("gps-imprecis");
  });
});
```

Run: `cd web && npx jest anomalies` → FAIL.

- [ ] **Step 5: Implémenter gps-imprécis (vert)**

Dans `detectAnomalies`, après le bloc `sans-site` et avant le `if (list.length)`, insérer :

```ts
    const imprecise = p.geo != null && p.geo.accuracy > t.gpsAccuracyMaxMeters;
    if (imprecise) list.push(anomaly("gps-imprecis"));
```

Run: `cd web && npx jest anomalies` → PASS.

- [ ] **Step 6: Test « hors-rayon » + interaction (rouge)**

Ajouter à `web/__tests__/anomalies.test.ts` :

```ts
describe("detectAnomalies — hors-rayon (tolérant)", () => {
  // ~333 m au nord du centre du site s1 (rayon 100 m, accuracy 20 m) → dehors même avec marge.
  const dehors = { lat: 4.053, lng: 9.7, accuracy: 20 };
  // ~111 m du centre, accuracy 30 m → 111 - 30 = 81 < 100 → dedans (toléré).
  const limite = { lat: 4.051, lng: 9.7, accuracy: 30 };

  it("signale un pointage nettement hors du rayon", () => {
    const m = detectAnomalies([mk({ id: "p1", geo: dehors })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("hors-rayon");
  });
  it("ne signale pas si la marge d'erreur GPS le ramène dans le rayon", () => {
    const m = detectAnomalies([mk({ id: "p1", geo: limite })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("hors-rayon");
  });
  it("ne signale pas hors-rayon si le GPS est imprécis (mais signale gps-imprecis)", () => {
    const m = detectAnomalies([mk({ id: "p1", geo: { lat: 4.053, lng: 9.7, accuracy: 150 } })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("gps-imprecis");
    expect(typesFor(m, "p1")).not.toContain("hors-rayon");
  });
  it("ne signale pas hors-rayon si le site est inconnu", () => {
    const m = detectAnomalies([mk({ id: "p1", siteId: "inconnu", geo: dehors })], new Map(), NOW);
    expect(typesFor(m, "p1")).not.toContain("hors-rayon");
  });
});
```

Run: `cd web && npx jest anomalies` → FAIL.

- [ ] **Step 7: Implémenter hors-rayon (vert)**

Dans `detectAnomalies`, juste après le bloc `gps-imprecis`, insérer :

```ts
    if (p.siteId != null && p.geo != null && !imprecise) {
      const site = sites.get(p.siteId);
      if (site?.geo != null && site.radiusMeters != null) {
        const dist = haversineMeters(p.geo, site.geo);
        if (dist - p.geo.accuracy > site.radiusMeters) list.push(anomaly("hors-rayon"));
      }
    }
```

Run: `cd web && npx jest anomalies` → PASS.

- [ ] **Step 8: Test « photo-manquante » (rouge)**

Ajouter à `web/__tests__/anomalies.test.ts` :

```ts
describe("detectAnomalies — photo-manquante", () => {
  const hAgo = (h: number) => new Date(NOW.getTime() - h * 3600000);
  it("signale une photo pending depuis > 24 h", () => {
    const m = detectAnomalies([mk({ id: "p1", photoStatus: "pending", clientTimestamp: hAgo(25) })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("photo-manquante");
  });
  it("ne signale pas une photo pending depuis < 24 h", () => {
    const m = detectAnomalies([mk({ id: "p1", photoStatus: "pending", clientTimestamp: hAgo(23) })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("photo-manquante");
  });
  it("ne signale jamais une photo uploaded", () => {
    const m = detectAnomalies([mk({ id: "p1", photoStatus: "uploaded", clientTimestamp: hAgo(48) })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("photo-manquante");
  });
});
```

Run: `cd web && npx jest anomalies` → FAIL.

- [ ] **Step 9: Implémenter photo-manquante (vert)**

Dans `detectAnomalies`, après le bloc `hors-rayon`, insérer :

```ts
    if (p.photoStatus !== "uploaded") {
      const ageMs = now.getTime() - p.clientTimestamp.getTime();
      if (ageMs > t.photoGraceHours * 3600000) list.push(anomaly("photo-manquante"));
    }
```

Run: `cd web && npx jest anomalies` → PASS.

- [ ] **Step 10: Test « horloge » asymétrique (rouge)**

Ajouter à `web/__tests__/anomalies.test.ts` :

```ts
describe("detectAnomalies — horloge", () => {
  const t11 = new Date(Date.UTC(2026, 5, 13, 11, 0));
  it("signale clientTimestamp en avance > 10 min sur serverTimestamp", () => {
    const client = new Date(t11.getTime() + 15 * 60000);
    const m = detectAnomalies([mk({ id: "p1", clientTimestamp: client, serverTimestamp: t11 })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("horloge");
  });
  it("ne signale pas un retard de synchro offline (client antérieur au server)", () => {
    const server = new Date(t11.getTime() + 5 * 3600000); // synchro 5 h plus tard
    const m = detectAnomalies([mk({ id: "p1", clientTimestamp: t11, serverTimestamp: server })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("horloge");
  });
  it("ne signale pas si serverTimestamp est null", () => {
    const client = new Date(t11.getTime() + 60 * 60000);
    const m = detectAnomalies([mk({ id: "p1", clientTimestamp: client, serverTimestamp: null })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("horloge");
  });
});
```

Run: `cd web && npx jest anomalies` → FAIL.

- [ ] **Step 11: Implémenter horloge (vert)**

Dans `detectAnomalies`, après le bloc `photo-manquante`, insérer :

```ts
    if (p.serverTimestamp != null) {
      const aheadMs = p.clientTimestamp.getTime() - p.serverTimestamp.getTime();
      if (aheadMs > t.clockAheadMinutes * 60000) list.push(anomaly("horloge"));
    }
```

Run: `cd web && npx jest anomalies` → PASS.

- [ ] **Step 12: Test « doublon » inter-pointages (rouge)**

Ajouter à `web/__tests__/anomalies.test.ts` :

```ts
describe("detectAnomalies — doublon", () => {
  const t10 = new Date(Date.UTC(2026, 5, 13, 10, 0));
  const plus = (min: number) => new Date(t10.getTime() + min * 60000);
  it("signale deux 'in' du même technicien à < 5 min (les deux)", () => {
    const m = detectAnomalies(
      [mk({ id: "a", kind: "in", clientTimestamp: t10 }), mk({ id: "b", kind: "in", clientTimestamp: plus(4) })],
      sites, NOW,
    );
    expect(typesFor(m, "a")).toContain("doublon");
    expect(typesFor(m, "b")).toContain("doublon");
  });
  it("ne signale pas deux 'in' espacés de 6 min", () => {
    const m = detectAnomalies(
      [mk({ id: "a", kind: "in", clientTimestamp: t10 }), mk({ id: "b", kind: "in", clientTimestamp: plus(6) })],
      sites, NOW,
    );
    expect(typesFor(m, "a")).not.toContain("doublon");
  });
  it("ne signale pas un 'in' et un 'out' rapprochés", () => {
    const m = detectAnomalies(
      [mk({ id: "a", kind: "in", clientTimestamp: t10 }), mk({ id: "b", kind: "out", clientTimestamp: plus(2) })],
      sites, NOW,
    );
    expect(typesFor(m, "a")).not.toContain("doublon");
  });
});
```

Run: `cd web && npx jest anomalies` → FAIL.

- [ ] **Step 13: Implémenter doublon (vert)**

Dans `detectAnomalies`, **après** la boucle `for (const p of punches)` et **avant** le `return out;`, insérer la passe inter-pointages :

```ts
  const windowMs = t.duplicateWindowMinutes * 60000;
  for (let i = 0; i < punches.length; i++) {
    for (let j = i + 1; j < punches.length; j++) {
      const a = punches[i];
      const b = punches[j];
      if (a.userId !== b.userId || a.kind !== b.kind) continue;
      if (Math.abs(a.clientTimestamp.getTime() - b.clientTimestamp.getTime()) < windowMs) {
        for (const p of [a, b]) {
          const l = out.get(p.id) ?? [];
          if (!l.some((x) => x.type === "doublon")) l.push(anomaly("doublon"));
          out.set(p.id, l);
        }
      }
    }
  }
```

Run: `cd web && npx jest anomalies` → PASS.

- [ ] **Step 14: Vérifier le fichier de tests complet passe**

Run: `cd web && npx jest anomalies`
Expected: PASS (tous les `describe` verts).

- [ ] **Step 15: Vérifier le listing final de `detectAnomalies`**

À ce stade, la fonction (hors types/fabriques de Step 1) doit être **exactement** :

```ts
export function detectAnomalies(
  punches: PunchForAnomaly[],
  sites: Map<string, SiteGeo>,
  now: Date,
  opts: Partial<AnomalyThresholds> = {},
): Map<string, Anomaly[]> {
  const t = { ...DEFAULT_THRESHOLDS, ...opts };
  const out = new Map<string, Anomaly[]>();

  for (const p of punches) {
    const list: Anomaly[] = [];

    if (p.siteId == null) list.push(anomaly("sans-site"));

    const imprecise = p.geo != null && p.geo.accuracy > t.gpsAccuracyMaxMeters;
    if (imprecise) list.push(anomaly("gps-imprecis"));

    if (p.siteId != null && p.geo != null && !imprecise) {
      const site = sites.get(p.siteId);
      if (site?.geo != null && site.radiusMeters != null) {
        const dist = haversineMeters(p.geo, site.geo);
        if (dist - p.geo.accuracy > site.radiusMeters) list.push(anomaly("hors-rayon"));
      }
    }

    if (p.photoStatus !== "uploaded") {
      const ageMs = now.getTime() - p.clientTimestamp.getTime();
      if (ageMs > t.photoGraceHours * 3600000) list.push(anomaly("photo-manquante"));
    }

    if (p.serverTimestamp != null) {
      const aheadMs = p.clientTimestamp.getTime() - p.serverTimestamp.getTime();
      if (aheadMs > t.clockAheadMinutes * 60000) list.push(anomaly("horloge"));
    }

    if (list.length) out.set(p.id, list);
  }

  const windowMs = t.duplicateWindowMinutes * 60000;
  for (let i = 0; i < punches.length; i++) {
    for (let j = i + 1; j < punches.length; j++) {
      const a = punches[i];
      const b = punches[j];
      if (a.userId !== b.userId || a.kind !== b.kind) continue;
      if (Math.abs(a.clientTimestamp.getTime() - b.clientTimestamp.getTime()) < windowMs) {
        for (const p of [a, b]) {
          const l = out.get(p.id) ?? [];
          if (!l.some((x) => x.type === "doublon")) l.push(anomaly("doublon"));
          out.set(p.id, l);
        }
      }
    }
  }

  return out;
}
```

- [ ] **Step 16: Lint + typecheck**

Run: `cd web && npx tsc --noEmit && npx eslint src/lib/anomalies.ts __tests__/anomalies.test.ts`
Expected: aucune erreur.

- [ ] **Step 17: Commit**

```bash
git add web/src/lib/anomalies.ts web/__tests__/anomalies.test.ts
git commit -m "feat(anomalies): detectAnomalies (hors-rayon, gps, photo, sans-site, doublon, horloge)"
```

---

## Task 3: Étendre l'annuaire — sites avec geo + radiusMeters

**Files:**
- Modify: `web/src/lib/directory.ts`

Changement structurel (type + mapping). Les consommateurs actuels (`presence`, `stats`, `board`, `tasks`) ne lisent que `.name` → pas d'impact. Validé par `tsc`.

- [ ] **Step 1: Étendre l'interface `Directory`**

Dans `web/src/lib/directory.ts`, remplacer :

```ts
export interface Directory {
  users: Map<string, { name: string }>;
  sites: Map<string, { name: string }>;
}
```

par :

```ts
export interface Directory {
  users: Map<string, { name: string }>;
  sites: Map<string, { name: string; geo: { lat: number; lng: number } | null; radiusMeters: number | null }>;
}
```

- [ ] **Step 2: Lire geo + radiusMeters dans `loadDirectory`**

Dans `web/src/lib/directory.ts`, remplacer le bloc de construction des sites :

```ts
  const sites = new Map<string, { name: string }>();
  for (const d of sitesSnap.docs) {
    sites.set(d.id, { name: (d.data().name as string) ?? d.id });
  }
```

par :

```ts
  const sites = new Map<
    string,
    { name: string; geo: { lat: number; lng: number } | null; radiusMeters: number | null }
  >();
  for (const d of sitesSnap.docs) {
    const data = d.data();
    const geo =
      data.geo != null ? { lat: data.geo.lat as number, lng: data.geo.lng as number } : null;
    sites.set(d.id, {
      name: (data.name as string) ?? d.id,
      geo,
      radiusMeters: (data.radiusMeters as number) ?? null,
    });
  }
```

- [ ] **Step 3: Typecheck (le « test » de cette tâche)**

Run: `cd web && npx tsc --noEmit`
Expected: aucune erreur (les consommateurs existants ne lisent que `.name`).

- [ ] **Step 4: Lancer toute la suite Jest (non-régression annuaire)**

Run: `cd web && npx jest`
Expected: PASS (suite existante + `anomalies`).

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/directory.ts
git commit -m "feat(directory): exposer geo + radiusMeters des sites (géofence anomalies)"
```

---

## Task 4: Page Alertes (Server Component)

**Files:**
- Create: `web/src/app/(dashboard)/alertes/page.tsx`

Pas d'infra de test composant dans le repo (cohérent Phase 3) → validation par `tsc` + `next build`. La page hérite du role gate du layout `(dashboard)`.

- [ ] **Step 1: Créer la page**

Créer `web/src/app/(dashboard)/alertes/page.tsx` :

```tsx
import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";
import { parsePeriod, PeriodKey } from "@/lib/stats";
import { detectAnomalies, PunchForAnomaly, SiteGeo, Anomaly } from "@/lib/anomalies";

export const dynamic = "force-dynamic";

const PERIODS: { key: PeriodKey; label: string }[] = [
  { key: "today", label: "Aujourd'hui" },
  { key: "7d", label: "7 jours" },
  { key: "30d", label: "30 jours" },
];

export default async function AlertesPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string; site?: string; tech?: string }>;
}) {
  const sp = await searchParams;
  const now = new Date();
  const { period, start } = parsePeriod(sp.period ?? "7d", now);

  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("punches").where("clientTimestamp", ">=", start).get(),
    loadDirectory(database),
  ]);

  const punches: PunchForAnomaly[] = snap.docs.map((d) => {
    const data = d.data();
    const geo =
      data.geo != null
        ? { lat: data.geo.lat as number, lng: data.geo.lng as number, accuracy: data.geo.accuracy as number }
        : null;
    return {
      id: d.id,
      userId: data.userId as string,
      kind: data.kind as "in" | "out",
      clientTimestamp: data.clientTimestamp.toDate(),
      serverTimestamp: data.serverTimestamp != null ? data.serverTimestamp.toDate() : null,
      geo,
      siteId: (data.siteId as string | null) ?? null,
      photoStatus: data.photoStatus as "pending" | "uploaded",
    };
  });

  const sites = new Map<string, SiteGeo>();
  for (const [id, s] of dir.sites) sites.set(id, { geo: s.geo, radiusMeters: s.radiusMeters });

  const byPunch = detectAnomalies(punches, sites, now);

  let rows = punches
    .filter((p) => byPunch.has(p.id))
    .map((p) => ({ punch: p, anomalies: byPunch.get(p.id)! }));

  if (sp.site) rows = rows.filter((r) => r.punch.siteId === sp.site);
  if (sp.tech) rows = rows.filter((r) => r.punch.userId === sp.tech);

  const hasAlerte = (a: Anomaly[]) => a.some((x) => x.severity === "alerte");
  rows.sort((x, y) => {
    const ax = hasAlerte(x.anomalies) ? 0 : 1;
    const ay = hasAlerte(y.anomalies) ? 0 : 1;
    if (ax !== ay) return ax - ay;
    return y.punch.clientTimestamp.getTime() - x.punch.clientTimestamp.getTime();
  });

  return (
    <div className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Alertes</h1>

      <div className="mb-6 flex gap-2 text-sm">
        {PERIODS.map((p) => (
          <a
            key={p.key}
            href={`/alertes?period=${p.key}`}
            className={
              "rounded px-3 py-1 " +
              (period === p.key ? "bg-gray-900 text-white" : "border text-gray-700 hover:bg-gray-100")
            }
          >
            {p.label}
          </a>
        ))}
      </div>

      <table className="w-full max-w-4xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Technicien</th>
            <th>Site</th>
            <th>Type</th>
            <th>Heure</th>
            <th>Anomalies</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.punch.id} className="border-b">
              <td className="py-2">{displayUser(r.punch.userId, dir)}</td>
              <td>{displaySite(r.punch.siteId ?? "", dir)}</td>
              <td>{r.punch.kind === "in" ? "Entrée" : "Sortie"}</td>
              <td>{r.punch.clientTimestamp.toLocaleString("fr-FR")}</td>
              <td>
                <div className="flex flex-wrap gap-1">
                  {r.anomalies.map((a) => (
                    <span
                      key={a.type}
                      className={
                        "rounded px-2 py-0.5 text-xs " +
                        (a.severity === "alerte"
                          ? "bg-red-100 text-red-700"
                          : "bg-amber-100 text-amber-700")
                      }
                    >
                      {a.label}
                    </span>
                  ))}
                </div>
              </td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td colSpan={5} className="py-2 text-gray-400">
                Aucune anomalie sur la période.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Typecheck + lint**

Run: `cd web && npx tsc --noEmit && npx eslint "src/app/(dashboard)/alertes/page.tsx"`
Expected: aucune erreur.

- [ ] **Step 3: Build (vérifie le rendu serveur de la route /alertes)**

Run: `cd web && npx next build`
Expected: build OK, la route `/alertes` apparaît dans la liste des routes.

- [ ] **Step 4: Commit**

```bash
git add "web/src/app/(dashboard)/alertes/page.tsx"
git commit -m "feat(alertes): page backoffice listant les pointages signalés"
```

---

## Task 5: Entrée de navigation « Alertes »

**Files:**
- Modify: `web/src/components/Sidebar.tsx`

- [ ] **Step 1: Ajouter le lien**

Dans `web/src/components/Sidebar.tsx`, remplacer le tableau `LINKS` :

```tsx
const LINKS = [
  { href: "/presence", label: "Présence" },
  { href: "/tasks", label: "Tâches" },
  { href: "/board", label: "Board" },
  { href: "/stats", label: "Stats" },
  { href: "/sites", label: "Sites" },
];
```

par (ajout de « Alertes » après « Stats ») :

```tsx
const LINKS = [
  { href: "/presence", label: "Présence" },
  { href: "/tasks", label: "Tâches" },
  { href: "/board", label: "Board" },
  { href: "/stats", label: "Stats" },
  { href: "/alertes", label: "Alertes" },
  { href: "/sites", label: "Sites" },
];
```

- [ ] **Step 2: Typecheck**

Run: `cd web && npx tsc --noEmit`
Expected: aucune erreur.

- [ ] **Step 3: Commit**

```bash
git add web/src/components/Sidebar.tsx
git commit -m "feat(nav): entrée sidebar Alertes"
```

---

## Task 6: Garde-fous finaux

**Files:** aucun (vérification globale).

- [ ] **Step 1: Suite de tests complète**

Run: `cd web && npx jest`
Expected: PASS (suite existante + `anomalies`).

- [ ] **Step 2: Typecheck global**

Run: `cd web && npx tsc --noEmit`
Expected: aucune erreur.

- [ ] **Step 3: Lint global**

Run: `cd web && npx eslint .`
Expected: aucune erreur.

- [ ] **Step 4: Build de production**

Run: `cd web && npx next build`
Expected: build OK, route `/alertes` présente.

- [ ] **Step 5: Finalisation de branche**

La branche `phase-4-detection-anomalies` est prête. Utiliser la sous-compétence **superpowers:finishing-a-development-branch** pour décider du merge (`--no-ff` vers `main` comme Cycle #4/#5) puis du déploiement (push `main` → auto-deploy Vercel ; lecture seule, aucun `firebase deploy` requis). Mettre à jour `CLAUDE.md` (statut Phase 4) et `docs/HANDOFF.md`.

---

## Notes de validation / déploiement
- **Aucun changement** de règles Firestore, Storage, Cloud Functions ni mobile → pas de `firebase deploy`, pas de test d'émulateur.
- Déploiement = simple push sur `main` (auto-deploy Vercel). Vérifier la page `/alertes` **sur Vercel** (rappel : `next dev`/Turbopack peut crasher en local sur certaines routes ; `next build` + prod font foi).
- Données réelles : des `punches` peuvent avoir `siteId = null` (« sans-site ») et/ou `serverTimestamp` brièvement non résolu — gérés défensivement par la lib.
