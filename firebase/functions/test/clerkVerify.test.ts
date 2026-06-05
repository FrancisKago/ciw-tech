import { extractClaims } from "../src/auth/clerkVerify";

describe("extractClaims", () => {
  it("retourne userId et role depuis un payload Clerk vérifié", () => {
    const payload = { sub: "user_123", public_metadata: { role: "technician" } };
    expect(extractClaims(payload)).toEqual({ userId: "user_123", role: "technician" });
  });

  it("utilise le rôle 'technician' par défaut si absent", () => {
    const payload = { sub: "user_456", public_metadata: {} };
    expect(extractClaims(payload)).toEqual({ userId: "user_456", role: "technician" });
  });

  it("rejette un payload sans sub", () => {
    expect(() => extractClaims({ public_metadata: {} } as never)).toThrow("invalid token: missing sub");
  });
});
