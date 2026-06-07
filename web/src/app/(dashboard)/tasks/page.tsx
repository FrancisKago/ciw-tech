import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { db } from "@/lib/firebaseAdmin";
import { mapTaskDoc, TaskRow } from "@/lib/tasks";
import { getUserRole } from "@/lib/currentRole";
import { canAccessBackoffice } from "@/lib/roles";

export const dynamic = "force-dynamic";

export default async function TasksPage() {
  const { userId } = await auth();
  if (!userId) redirect("/");

  const role = await getUserRole(userId);
  if (!canAccessBackoffice(role)) {
    return (
      <div style={{ padding: 48, maxWidth: 560, margin: "0 auto", textAlign: "center" }}>
        <h1 style={{ fontSize: 24, fontWeight: 600 }}>Accès refusé</h1>
        <p style={{ marginTop: 12, color: "#555" }}>
          Le backoffice est réservé à la direction (rôle <code>admin</code> ou{" "}
          <code>manager</code>). Votre rôle actuel : <strong>{role ?? "non défini"}</strong>.
        </p>
      </div>
    );
  }

  const snap = await db().collection("tasks").orderBy("createdAt", "desc").get();
  const rows: TaskRow[] = snap.docs.map((d) => mapTaskDoc(d.id, d.data()));

  return (
    <main style={{ padding: 24 }}>
      <h1>Tâches</h1>
      <table cellPadding={8} style={{ borderCollapse: "collapse" }}>
        <thead>
          <tr>
            <th>Titre</th>
            <th>Site</th>
            <th>Assigné</th>
            <th>Statut</th>
            <th>Échéance</th>
            <th>Rapport</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((t) => (
            <tr key={t.id} style={{ borderTop: "1px solid #ddd" }}>
              <td>{t.title}</td>
              <td>{t.siteId}</td>
              <td>{t.assigneeId}</td>
              <td>{t.status}</td>
              <td>{t.dueAt ?? "—"}</td>
              <td>{t.hasReport ? "✓" : "—"}</td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td colSpan={6}>Aucune tâche.</td>
            </tr>
          )}
        </tbody>
      </table>
    </main>
  );
}
