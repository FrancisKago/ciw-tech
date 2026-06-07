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

describe("règles tasks", () => {
  const baseTask = {
    title: "Réparer", description: "", siteId: "s1",
    assigneeId: "tech_1", createdBy: "mgr", priority: "normal",
    dueAt: null, status: "assigned",
  };

  it("un manager peut créer une tâche dont il est createdBy", async () => {
    const db = ctx("mgr", "manager");
    await assertSucceeds(setDoc(doc(db, "tasks/t1"), baseTask));
  });

  it("un technicien ne peut PAS créer de tâche", async () => {
    const db = ctx("tech_1", "technician");
    await assertFails(setDoc(doc(db, "tasks/t2"), baseTask));
  });

  it("un manager ne peut PAS créer une tâche au nom d'un autre createdBy", async () => {
    const db = ctx("mgr", "manager");
    await assertFails(setDoc(doc(db, "tasks/t3"), { ...baseTask, createdBy: "autre" }));
  });

  it("l'assigné peut lire sa tâche", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t4"), baseTask));
    const db = ctx("tech_1", "technician");
    await assertSucceeds(getDoc(doc(db, "tasks/t4")));
  });

  it("un technicien non assigné ne peut PAS lire la tâche", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t5"), baseTask));
    const db = ctx("tech_2", "technician");
    await assertFails(getDoc(doc(db, "tasks/t5")));
  });

  it("l'assigné peut passer status à in_progress", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t6"), baseTask));
    const db = ctx("tech_1", "technician");
    await assertSucceeds(setDoc(doc(db, "tasks/t6"),
      { ...baseTask, status: "in_progress" }));
  });

  it("l'assigné ne peut PAS se réassigner la tâche", async () => {
    await env.withSecurityRulesDisabled((c) =>
      setDoc(doc(c.firestore(), "tasks/t7"), baseTask));
    const db = ctx("tech_1", "technician");
    await assertFails(setDoc(doc(db, "tasks/t7"),
      { ...baseTask, assigneeId: "tech_1_autre" }));
  });
});
