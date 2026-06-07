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
