import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { db } from "@/lib/firebaseAdmin";
import { computeWorkedMinutes, PunchLite } from "@/lib/hours";
import { getUserRole } from "@/lib/currentRole";
import { canAccessBackoffice } from "@/lib/roles";

export const dynamic = "force-dynamic";

export default async function PresencePage() {
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

  const start = new Date(); start.setUTCHours(0, 0, 0, 0);
  const snap = await db()
    .collection("punches")
    .where("clientTimestamp", ">=", start)
    .get();

  const byUser = new Map<string, PunchLite[]>();
  for (const d of snap.docs) {
    const data = d.data();
    const list = byUser.get(data.userId) ?? [];
    list.push({ kind: data.kind, at: data.clientTimestamp.toDate() });
    byUser.set(data.userId, list);
  }

  const rows = [...byUser.entries()].map(([uid, punches]) => {
    const { minutes, anomalies } = computeWorkedMinutes(punches);
    return { uid, hours: (minutes / 60).toFixed(2), anomalies };
  });

  return (
    <div style={{ padding: 24 }}>
      <h1>Présence du jour</h1>
      <table cellPadding={8} style={{ borderCollapse: "collapse" }}>
        <thead><tr><th>Technicien</th><th>Heures</th><th>Anomalies</th></tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.uid} style={{ borderTop: "1px solid #ddd" }}>
              <td>{r.uid}</td>
              <td>{r.hours}</td>
              <td style={{ color: r.anomalies.length ? "crimson" : "green" }}>
                {r.anomalies.length ? r.anomalies.join(", ") : "—"}
              </td>
            </tr>
          ))}
          {rows.length === 0 && <tr><td colSpan={3}>Aucun pointage aujourd'hui.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
