import { buildTokenResponse, buildUserProfile } from "../src/auth/mintFirebaseToken";

describe("buildTokenResponse", () => {
  it("crée un custom token avec uid = userId et le rôle en claim", async () => {
    const fakeAuth = {
      createCustomToken: (uid: string, claims: object) =>
        Promise.resolve(`token:${uid}:${JSON.stringify(claims)}`),
    };
    const res = await buildTokenResponse(fakeAuth as never, { userId: "user_123", role: "manager" });
    expect(res.firebaseToken).toBe('token:user_123:{"role":"manager"}');
  });
});

describe("buildUserProfile", () => {
  it("compose le nom complet et le téléphone", () => {
    const p = buildUserProfile("technician", {
      firstName: "Awono", lastName: "Paul",
      phoneNumbers: [{ phoneNumber: "+237699000000" }],
    });
    expect(p).toEqual({ role: "technician", name: "Awono Paul", phone: "+237699000000" });
  });

  it("omet name et phone quand le profil est absent", () => {
    expect(buildUserProfile("manager", null)).toEqual({ role: "manager" });
  });

  it("gère un prénom seul (pas de nom de famille)", () => {
    expect(buildUserProfile("technician", { firstName: "Awono", lastName: null }))
      .toEqual({ role: "technician", name: "Awono" });
  });
});
