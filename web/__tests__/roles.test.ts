import { canAccessBackoffice } from "@/lib/roles";

describe("canAccessBackoffice", () => {
  it("autorise admin", () => {
    expect(canAccessBackoffice("admin")).toBe(true);
  });
  it("autorise manager", () => {
    expect(canAccessBackoffice("manager")).toBe(true);
  });
  it("refuse technician", () => {
    expect(canAccessBackoffice("technician")).toBe(false);
  });
  it("refuse un rôle absent ou inconnu", () => {
    expect(canAccessBackoffice(undefined)).toBe(false);
    expect(canAccessBackoffice(null)).toBe(false);
    expect(canAccessBackoffice("autre")).toBe(false);
  });
});
