import { db } from "@/lib/firebaseAdmin";
import { mapTaskDoc, TaskRow } from "@/lib/tasks";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";

export const dynamic = "force-dynamic";

export default async function TasksPage() {
  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("tasks").orderBy("createdAt", "desc").get(),
    loadDirectory(database),
  ]);
  const rows: TaskRow[] = snap.docs.map((d) => mapTaskDoc(d.id, d.data()));

  return (
    <main className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Tâches</h1>
      <table className="w-full max-w-4xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Titre</th><th>Site</th><th>Assigné</th><th>Statut</th><th>Échéance</th><th>Rapport</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((t) => (
            <tr key={t.id} className="border-b">
              <td className="py-2">{t.title}</td>
              <td>{displaySite(t.siteId, dir)}</td>
              <td>{displayUser(t.assigneeId, dir)}</td>
              <td>{t.status}</td>
              <td>{t.dueAt ? new Date(t.dueAt).toLocaleDateString("fr-FR") : "—"}</td>
              <td>{t.hasReport ? "✓" : "—"}</td>
            </tr>
          ))}
          {rows.length === 0 && <tr><td colSpan={6} className="py-2 text-gray-400">Aucune tâche.</td></tr>}
        </tbody>
      </table>
    </main>
  );
}
