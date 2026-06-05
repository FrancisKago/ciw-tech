import { computeWorkedMinutes, PunchLite } from "@/lib/hours";

const t = (h: number, m = 0) => new Date(Date.UTC(2026, 5, 5, h, m));

describe("computeWorkedMinutes", () => {
  it("apparie in/out et somme les durées", () => {
    const punches: PunchLite[] = [
      { kind: "in", at: t(8) }, { kind: "out", at: t(12) },
      { kind: "in", at: t(13) }, { kind: "out", at: t(17) },
    ];
    expect(computeWorkedMinutes(punches).minutes).toBe(8 * 60);
    expect(computeWorkedMinutes(punches).anomalies).toHaveLength(0);
  });

  it("signale un 'in' sans 'out'", () => {
    const punches: PunchLite[] = [{ kind: "in", at: t(8) }];
    const r = computeWorkedMinutes(punches);
    expect(r.minutes).toBe(0);
    expect(r.anomalies).toContain("in sans out");
  });

  it("signale un 'out' sans 'in' préalable", () => {
    const punches: PunchLite[] = [{ kind: "out", at: t(17) }];
    const r = computeWorkedMinutes(punches);
    expect(r.anomalies).toContain("out sans in");
  });
});
