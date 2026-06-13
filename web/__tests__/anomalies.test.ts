import {
  detectAnomalies,
  PunchForAnomaly,
  SiteRef,
  Anomaly,
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
const sites = new Map<string, SiteRef>([
  ["s1", { geo: { lat: 4.05, lng: 9.7 }, radiusMeters: 100 }],
]);
const typesFor = (m: Map<string, Anomaly[]>, id: string) =>
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

describe("detectAnomalies — hors-rayon (tolérant)", () => {
  const dehors = { lat: 4.053, lng: 9.7, accuracy: 20 };
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

describe("detectAnomalies — horloge", () => {
  const t11 = new Date(Date.UTC(2026, 5, 13, 11, 0));
  it("signale clientTimestamp en avance > 10 min sur serverTimestamp", () => {
    const client = new Date(t11.getTime() + 15 * 60000);
    const m = detectAnomalies([mk({ id: "p1", clientTimestamp: client, serverTimestamp: t11 })], sites, NOW);
    expect(typesFor(m, "p1")).toContain("horloge");
  });
  it("ne signale pas un retard de synchro offline (client antérieur au server)", () => {
    const server = new Date(t11.getTime() + 5 * 3600000);
    const m = detectAnomalies([mk({ id: "p1", clientTimestamp: t11, serverTimestamp: server })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("horloge");
  });
  it("ne signale pas si serverTimestamp est null", () => {
    const client = new Date(t11.getTime() + 60 * 60000);
    const m = detectAnomalies([mk({ id: "p1", clientTimestamp: client, serverTimestamp: null })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("horloge");
  });
});

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
  it("ne signale pas deux 'in' espacés d'exactement 5 min (borne stricte)", () => {
    const m = detectAnomalies(
      [mk({ id: "a", kind: "in", clientTimestamp: t10 }), mk({ id: "b", kind: "in", clientTimestamp: plus(5) })],
      sites, NOW,
    );
    expect(typesFor(m, "a")).not.toContain("doublon");
  });
});

describe("detectAnomalies — geo absent (défensif)", () => {
  it("ne plante pas et ne signale ni gps-imprecis ni hors-rayon quand geo est null", () => {
    const m = detectAnomalies([mk({ id: "p1", geo: null })], sites, NOW);
    expect(typesFor(m, "p1")).not.toContain("gps-imprecis");
    expect(typesFor(m, "p1")).not.toContain("hors-rayon");
    expect(m.has("p1")).toBe(false); // pointage par ailleurs nominal → aucune anomalie
  });
});
