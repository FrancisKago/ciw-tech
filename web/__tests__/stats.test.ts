import { parsePeriod, hoursPerTechnician, completionByKey, StatsPunch, StatsTask } from "@/lib/stats";

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
