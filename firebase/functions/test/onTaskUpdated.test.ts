import {
  routeStatusChange,
  buildReportSubmittedMessage,
  buildApprovedMessage,
} from "../src/tasks/onTaskUpdated";

describe("routeStatusChange", () => {
  const base = { status: "assigned", createdBy: "mgr", assigneeId: "tech_1" };

  it("in_progress → done : notifie le créateur (manager)", () => {
    const out = routeStatusChange({ ...base, status: "in_progress" }, { ...base, status: "done" });
    expect(out).toEqual([{ kind: "report_submitted", recipientId: "mgr" }]);
  });

  it("done → approved : notifie l'assigné (technicien)", () => {
    const out = routeStatusChange({ ...base, status: "done" }, { ...base, status: "approved" });
    expect(out).toEqual([{ kind: "approved", recipientId: "tech_1" }]);
  });

  it("aucune transition pertinente : rien", () => {
    const out = routeStatusChange({ ...base, status: "assigned" }, { ...base, status: "in_progress" });
    expect(out).toEqual([]);
  });

  it("done inchangé (patch de rapport) : rien", () => {
    const out = routeStatusChange({ ...base, status: "done" }, { ...base, status: "done" });
    expect(out).toEqual([]);
  });
});

describe("builders de message", () => {
  it("buildReportSubmittedMessage porte le taskId et le titre", () => {
    const m = buildReportSubmittedMessage("t1", "Réparer clim");
    expect(m.notification.title).toContain("Réparer clim");
    expect(m.data).toEqual({ taskId: "t1", kind: "report_submitted" });
  });

  it("buildApprovedMessage porte le taskId et le titre", () => {
    const m = buildApprovedMessage("t1", "Réparer clim");
    expect(m.notification.title).toContain("Réparer clim");
    expect(m.data).toEqual({ taskId: "t1", kind: "approved" });
  });
});
