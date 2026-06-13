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
