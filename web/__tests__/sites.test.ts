import { parseSiteForm } from "../src/lib/sites";

describe("parseSiteForm", () => {
  it("accepte une entrée valide", () => {
    expect(parseSiteForm({ name: "Siège", lat: "4.05", lng: "9.76", radiusMeters: "150" }))
      .toEqual({ ok: true, value: { name: "Siège", lat: 4.05, lng: 9.76, radiusMeters: 150 } });
  });
  it("refuse un nom vide", () => {
    expect(parseSiteForm({ name: "  ", lat: "4", lng: "9", radiusMeters: "100" }).ok).toBe(false);
  });
  it("refuse une latitude non numérique", () => {
    expect(parseSiteForm({ name: "X", lat: "abc", lng: "9", radiusMeters: "100" }).ok).toBe(false);
  });
  it("refuse un rayon nul ou négatif", () => {
    expect(parseSiteForm({ name: "X", lat: "4", lng: "9", radiusMeters: "0" }).ok).toBe(false);
  });
  it("refuse un champ numérique vide", () => {
    expect(parseSiteForm({ name: "X", lat: "", lng: "9", radiusMeters: "100" }).ok).toBe(false);
  });
});
