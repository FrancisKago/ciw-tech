import { buildTokenResponse } from "../src/auth/mintFirebaseToken";

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
