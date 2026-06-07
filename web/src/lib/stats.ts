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
