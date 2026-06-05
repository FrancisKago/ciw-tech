import { distanceMeters, isOutsideSite } from "@/lib/geo";

describe("geo", () => {
  it("distance ~0 pour le même point", () => {
    expect(distanceMeters(4.05, 9.70, 4.05, 9.70)).toBeLessThan(1);
  });
  it("détecte un pointage hors rayon", () => {
    // ~1.1 km au nord => hors d'un rayon de 200 m
    expect(isOutsideSite({ lat: 4.06, lng: 9.70 }, { lat: 4.05, lng: 9.70, radiusMeters: 200 })).toBe(true);
  });
  it("accepte un pointage dans le rayon", () => {
    expect(isOutsideSite({ lat: 4.0501, lng: 9.7001 }, { lat: 4.05, lng: 9.70, radiusMeters: 200 })).toBe(false);
  });
});
