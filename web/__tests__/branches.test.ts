import { branchMeta, DOMAINES } from "@/lib/branches";

describe("branchMeta", () => {
  it("mappe chaque branche", () => {
    expect(branchMeta("electricite").label).toBe("Électricité");
    expect(branchMeta("informatique").icon).toBe("device-cctv");
    expect(branchMeta("plomberie").bg).toBe("#E1F5EE");
    expect(branchMeta("autre").label).toBe("Autre");
  });
  it("fallback pour valeur absente/inconnue", () => {
    expect(branchMeta(undefined).label).toBe("Non précisé");
    expect(branchMeta("bidon").label).toBe("Non précisé");
  });
  it("DOMAINES liste les 4 branches", () => {
    expect(DOMAINES).toEqual(["electricite", "informatique", "plomberie", "autre"]);
  });
});
