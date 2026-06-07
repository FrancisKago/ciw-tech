import { computeWorkedMinutes, PunchLite } from "@/lib/hours";
import { isLate } from "@/lib/board";

export interface StatsPunch { userId: string; kind: "in" | "out"; at: Date; siteId: string; }
export interface StatsTask { assigneeId: string; siteId: string; status: string; dueAt: Date | null; createdAt: Date | null; }

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

function inRange(d: Date | null, start: Date, end: Date): boolean {
  return d != null && d.getTime() >= start.getTime() && d.getTime() <= end.getTime();
}

/**
 * Une tâche appartient à la période par son échéance si elle en a une, sinon par sa date
 * de création. (Sans cela, une tâche sans `dueAt` serait invisible dans les stats.)
 */
function taskInPeriod(t: StatsTask, start: Date, end: Date): boolean {
  return t.dueAt != null ? inRange(t.dueAt, start, end) : inRange(t.createdAt, start, end);
}

/**
 * Taux de complétion par clé ('assigneeId' ou 'siteId').
 * Périmètre = tâches rattachées à la période (échéance, ou création à défaut d'échéance).
 * done/approved comptent comme terminées.
 */
export function completionByKey(
  tasks: StatsTask[],
  range: { start: Date; end: Date },
  key: "assigneeId" | "siteId",
): Map<string, { done: number; total: number }> {
  const out = new Map<string, { done: number; total: number }>();
  for (const t of tasks) {
    if (!taskInPeriod(t, range.start, range.end)) continue;
    const k = t[key];
    const cur = out.get(k) ?? { done: 0, total: 0 };
    cur.total += 1;
    if (t.status === "done" || t.status === "approved") cur.done += 1;
    out.set(k, cur);
  }
  return out;
}

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
