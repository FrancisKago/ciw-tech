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
});
