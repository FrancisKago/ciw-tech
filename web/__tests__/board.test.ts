import { isLate, groupByStatus, BoardTask } from "@/lib/board";

const now = new Date(Date.UTC(2026, 5, 7, 12, 0)); // 7 juin 2026 12:00 UTC
const task = (over: Partial<BoardTask>): BoardTask => ({
  id: "t", title: "T", siteId: "s1", assigneeId: "u1",
  status: "assigned", dueAt: null, hasReport: false, ...over,
});

describe("isLate", () => {
  it("vrai si échéance passée et statut non terminé", () => {
    expect(isLate(task({ dueAt: new Date(Date.UTC(2026, 5, 5)), status: "assigned" }), now)).toBe(true);
  });
  it("faux si échéance future", () => {
    expect(isLate(task({ dueAt: new Date(Date.UTC(2026, 5, 9)), status: "assigned" }), now)).toBe(false);
  });
  it("faux si la tâche est terminée même en retard", () => {
    expect(isLate(task({ dueAt: new Date(Date.UTC(2026, 5, 5)), status: "done" }), now)).toBe(false);
  });
  it("faux si pas d'échéance", () => {
    expect(isLate(task({ dueAt: null }), now)).toBe(false);
  });
});

describe("groupByStatus", () => {
  it("répartit les tâches dans les 3 colonnes", () => {
    const cols = groupByStatus([
      task({ id: "a", status: "assigned" }),
      task({ id: "b", status: "in_progress" }),
      task({ id: "c", status: "done" }),
      task({ id: "d", status: "approved" }),
    ]);
    expect(cols.assigned.map((t) => t.id)).toEqual(["a"]);
    expect(cols.in_progress.map((t) => t.id)).toEqual(["b"]);
    expect(cols.done.map((t) => t.id)).toEqual(["c", "d"]); // approved compté comme terminé
  });
  it("range un statut inconnu dans 'À faire' pour ne perdre aucune tâche", () => {
    const cols = groupByStatus([task({ id: "x", status: "weird" })]);
    expect(cols.assigned.map((t) => t.id)).toEqual(["x"]);
  });
});
