import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";
import { mapTaskDoc } from "@/lib/tasks";
import { approveTask } from "@/lib/actions/approveTask";
import BranchBadge from "@/components/BranchBadge";

export const dynamic = "force-dynamic";

export default async function TaskDetailPage({
  params,
}: {
  params: Promise<{ taskId: string }>;
}) {
  const { taskId } = await params;
  const database = db();
  const [snap, dir] = await Promise.all([
    database.doc(`tasks/${taskId}`).get(),
    loadDirectory(database),
  ]);
  if (!snap.exists) notFound();
  const task = mapTaskDoc(snap.id, snap.data()!);

  return (
    <main className="p-6">
      <Link href="/board" className="text-sm text-gray-500 hover:underline">← Board</Link>
      <h1 className="mb-1 mt-2 text-2xl font-semibold">{task.title}</h1>
      <div className="mb-2 text-sm text-gray-600">
        👤 {displayUser(task.assigneeId, dir)} · 📍 {displaySite(task.siteId, dir)} · statut {task.status}
      </div>
      <div className="mb-4">
        <BranchBadge domaine={task.domaine} />
      </div>

      {task.status === "approved" && (
        <div className="mb-4 rounded border-l-4 border-l-green-600 bg-green-50 p-3 text-sm text-green-800">
          ✓ Validé par {displayUser(task.approvedBy ?? "", dir)}
          {task.approvedAt && ` le ${fmtDate(task.approvedAt)}`}
        </div>
      )}

      <section className="rounded-lg border border-gray-200 bg-white p-4">
        <h2 className="mb-2 text-lg font-medium">Rapport</h2>
        {task.report ? (
          <>
            <p className="whitespace-pre-wrap text-sm text-gray-800">{task.report.text || "—"}</p>
            <p className="mt-2 text-sm text-gray-600">
              ⏱ {task.report.minutesSpent} min · {task.report.photoCount} photo(s)
            </p>
            {task.report.submittedAt && (
              <p className="text-xs text-gray-500">Soumis le {fmtDate(task.report.submittedAt)}</p>
            )}
            {task.report.photoUrls.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {task.report.photoUrls.map((url) => (
                  <a key={url} href={url} target="_blank" rel="noreferrer">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={url} alt="photo rapport" className="h-24 w-24 rounded object-cover" />
                  </a>
                ))}
              </div>
            )}
          </>
        ) : (
          <p className="text-sm text-gray-400">Aucun rapport soumis.</p>
        )}
      </section>

      {task.status === "done" && (
        <form action={approveTask} className="mt-4">
          <input type="hidden" name="taskId" value={task.id} />
          <button type="submit" className="rounded bg-green-700 px-4 py-2 text-white">
            Valider la tâche
          </button>
        </form>
      )}
    </main>
  );
}

function fmtDate(iso: string): string {
  return new Date(iso).toLocaleDateString("fr-FR", {
    day: "numeric", month: "short", year: "numeric",
  });
}
