import { mapTaskDoc } from "@/lib/tasks";

describe("mapTaskDoc", () => {
  it("projette les champs affichés et la présence du rapport", () => {
    const row = mapTaskDoc("t1", {
      title: "Réparer", siteId: "s1", assigneeId: "tech_1",
      status: "done", dueAt: null,
      report: { text: "ok", minutesSpent: 30, photoUrls: [], photoCount: 0 },
    });
    expect(row.id).toBe("t1");
    expect(row.title).toBe("Réparer");
    expect(row.status).toBe("done");
    expect(row.hasReport).toBe(true);
  });

  it("hasReport=false quand report absent", () => {
    const row = mapTaskDoc("t2", {
      title: "X", siteId: "s1", assigneeId: "tech_1", status: "assigned",
      dueAt: null, report: null,
    });
    expect(row.hasReport).toBe(false);
  });

  it("projette le détail du rapport et les champs de validation", () => {
    const row = mapTaskDoc("t3", {
      title: "Réparer", siteId: "s1", assigneeId: "tech_1", createdBy: "mgr",
      status: "approved", dueAt: null,
      report: {
        text: "RAS", minutesSpent: 45, photoUrls: ["https://x/a.jpg"], photoCount: 1,
        submittedAt: { toDate: () => new Date("2026-06-07T10:00:00Z") },
      },
      approvedBy: "mgr",
      approvedAt: { toDate: () => new Date("2026-06-07T12:00:00Z") },
    });
    expect(row.createdBy).toBe("mgr");
    expect(row.report?.text).toBe("RAS");
    expect(row.report?.minutesSpent).toBe(45);
    expect(row.report?.photoUrls).toEqual(["https://x/a.jpg"]);
    expect(row.report?.submittedAt).toBe("2026-06-07T10:00:00.000Z");
    expect(row.approvedBy).toBe("mgr");
    expect(row.approvedAt).toBe("2026-06-07T12:00:00.000Z");
  });

  it("report=null quand absent (détail null, hasReport false)", () => {
    const row = mapTaskDoc("t4", {
      title: "X", siteId: "s1", assigneeId: "tech_1", status: "assigned",
      dueAt: null, report: null,
    });
    expect(row.report).toBeNull();
    expect(row.hasReport).toBe(false);
    expect(row.approvedBy).toBeNull();
  });

  it("préserve domaine quand présent", () => {
    const row = mapTaskDoc("t5", {
      title: "Y", siteId: "s1", assigneeId: "tech_1", status: "assigned",
      dueAt: null, report: null, domaine: "electricite",
    });
    expect(row.domaine).toBe("electricite");
  });

  it("domaine undefined quand absent", () => {
    const row = mapTaskDoc("t6", {
      title: "Z", siteId: "s1", assigneeId: "tech_1", status: "assigned",
      dueAt: null, report: null,
    });
    expect(row.domaine).toBeUndefined();
  });
});
