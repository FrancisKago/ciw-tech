import { initializeTestEnvironment, RulesTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { setDoc, doc, getDoc } from "firebase/firestore";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "cameroon-innovation",
    firestore: { rules: readFileSync("../firestore.rules", "utf8"), host: "localhost", port: 8080 },
  });
});
afterAll(() => env.cleanup());
beforeEach(() => env.clearFirestore());

function ctx(uid: string, role: string) {
  return env.authenticatedContext(uid, { role }).firestore();
}

describe("règles punches", () => {
  it("un technicien peut créer SON propre pointage", async () => {
    const db = ctx("user_1", "technician");
    await assertSucceeds(setDoc(doc(db, "punches/p1"), { userId: "user_1", kind: "in" }));
  });
  it("un technicien ne peut PAS créer un pointage pour un autre", async () => {
    const db = ctx("user_1", "technician");
    await assertFails(setDoc(doc(db, "punches/p2"), { userId: "user_2", kind: "in" }));
  });
  it("un technicien ne peut PAS lire le pointage d'un autre", async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), "punches/p3"), { userId: "user_2", kind: "in" }));
    const db = ctx("user_1", "technician");
    await assertFails(getDoc(doc(db, "punches/p3")));
  });
  it("un manager peut lire le pointage d'un autre", async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), "punches/p4"), { userId: "user_2", kind: "in" }));
    const db = ctx("mgr", "manager");
    await assertSucceeds(getDoc(doc(db, "punches/p4")));
  });
});
