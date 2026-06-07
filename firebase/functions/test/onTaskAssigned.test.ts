import { buildAssignmentMessage, splitInvalidTokens } from "../src/tasks/onTaskAssigned";

describe("buildAssignmentMessage", () => {
  it("construit titre, corps et data avec le taskId", () => {
    const msg = buildAssignmentMessage("task_1", {
      title: "Changer disjoncteur", siteId: "s1", priority: "high",
    });
    expect(msg.notification.title).toBe("Nouvelle tâche : Changer disjoncteur");
    expect(msg.notification.body).toContain("s1");
    expect(msg.notification.body).toContain("high");
    expect(msg.data).toEqual({ taskId: "task_1" });
  });
});

describe("splitInvalidTokens", () => {
  it("sépare les tokens à supprimer selon les réponses d'envoi", () => {
    const tokens = ["tA", "tB", "tC"];
    const responses = [
      { success: true },
      { success: false, error: { code: "messaging/registration-token-not-registered" } },
      { success: false, error: { code: "messaging/internal-error" } },
    ];
    const { invalid } = splitInvalidTokens(tokens, responses as never);
    expect(invalid).toEqual(["tB"]); // pas tC (erreur transitoire, on garde)
  });
});
