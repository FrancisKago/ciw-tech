import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite, Directory } from "@/lib/directory";
import { groupByStatus, isLate, BoardTask, BoardColumns } from "@/lib/board";

export const dynamic = "force-dynamic";

const COLS: { key: keyof BoardColumns; label: string }[] = [
  { key: "assigned", label: "À faire" },
  { key: "in_progress", label: "En cours" },
  { key: "done", label: "Terminé" },
];

export default async function BoardPage({
  searchParams,
}: {
  searchParams: Promise<{ site?: string; tech?: string }>;
}) {
  const sp = await searchParams;
  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("tasks").orderBy("createdAt", "desc").get(),
    loadDirectory(database),
  ]);

  const tasks: BoardTask[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      title: data.title ?? "",
      siteId: data.siteId ?? "",
      assigneeId: data.assigneeId ?? "",
      status: data.status ?? "assigned",
      dueAt: data.dueAt ? data.dueAt.toDate() : null,
      hasReport: data.report != null,
    };
  });

  const filtered = tasks.filter(
    (t) => (!sp.site || t.siteId === sp.site) && (!sp.tech || t.assigneeId === sp.tech),
  );
  const columns = groupByStatus(filtered);
  const now = new Date();

  return (
    <main className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Board des tâches</h1>

      <form method="get" className="mb-6 flex gap-3 text-sm">
        <select name="site" defaultValue={sp.site ?? ""} className="rounded border px-2 py-1">
          <option value="">Tous les sites</option>
          {[...dir.sites.entries()].map(([id, s]) => (
            <option key={id} value={id}>{s.name}</option>
          ))}
        </select>
        <select name="tech" defaultValue={sp.tech ?? ""} className="rounded border px-2 py-1">
          <option value="">Tous les techniciens</option>
          {[...dir.users.entries()].map(([id, u]) => (
            <option key={id} value={id}>{u.name}</option>
          ))}
        </select>
        <button type="submit" className="rounded bg-gray-900 px-3 py-1 text-white">Filtrer</button>
      </form>

      <div className="flex gap-4">
        {COLS.map((col) => (
          <section key={col.key} className="flex-1">
            <div className="mb-2 text-xs font-semibold uppercase text-gray-500">
              {col.label} · {columns[col.key].length}
            </div>
            <div className="space-y-2">
              {columns[col.key].map((t) => (
                <Card key={t.id} task={t} dir={dir} late={isLate(t, now)} />
              ))}
              {columns[col.key].length === 0 && (
                <p className="text-sm text-gray-400">—</p>
              )}
            </div>
          </section>
        ))}
      </div>
    </main>
  );
}

function Card({ task, dir, late }: { task: BoardTask; dir: Directory; late: boolean }) {
  return (
    <div
      className={
        "rounded-lg border bg-white p-3 shadow-sm " +
        (late ? "border-l-4 border-l-red-600" : "border-gray-200")
      }
    >
      <div className="font-medium">{task.title}</div>
      <div className="mt-1 text-sm text-gray-600">
        👤 {displayUser(task.assigneeId, dir)} · 📍 {displaySite(task.siteId, dir)}
      </div>
      {late ? (
        <div className="mt-1 text-xs font-semibold text-red-600">
          ⚠ En retard · échéance {fmt(task.dueAt)}
        </div>
      ) : (
        <div className="mt-1 text-xs text-gray-500">
          Échéance : {fmt(task.dueAt)}
          {task.hasReport && <span className="ml-2 text-green-700">✓ rapport</span>}
        </div>
      )}
    </div>
  );
}

function fmt(d: Date | null): string {
  return d ? d.toLocaleDateString("fr-FR", { day: "numeric", month: "short" }) : "—";
}
