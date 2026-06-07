import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";
import {
  parsePeriod, hoursPerTechnician, completionByKey, lateCountByKey, hoursPerSite,
  StatsPunch, StatsTask, PeriodKey,
} from "@/lib/stats";

export const dynamic = "force-dynamic";

const PERIODS: { key: PeriodKey; label: string }[] = [
  { key: "today", label: "Aujourd'hui" },
  { key: "7d", label: "7 jours" },
  { key: "30d", label: "30 jours" },
];

export default async function StatsPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string }>;
}) {
  const sp = await searchParams;
  const now = new Date();
  const { period, start, end } = parsePeriod(sp.period, now);

  const database = db();
  const [tasksSnap, punchesSnap, dir] = await Promise.all([
    database.collection("tasks").get(),
    database.collection("punches").where("clientTimestamp", ">=", start).get(),
    loadDirectory(database),
  ]);

  const punches: StatsPunch[] = punchesSnap.docs.map((d) => {
    const data = d.data();
    return { userId: data.userId, kind: data.kind, at: data.clientTimestamp.toDate(), siteId: data.siteId ?? "" };
  });
  const tasks: StatsTask[] = tasksSnap.docs.map((d) => {
    const data = d.data();
    return {
      assigneeId: data.assigneeId ?? "",
      siteId: data.siteId ?? "",
      status: data.status ?? "assigned",
      dueAt: data.dueAt ? data.dueAt.toDate() : null,
    };
  });

  const range = { start, end };
  const hoursT = hoursPerTechnician(punches);
  const compT = completionByKey(tasks, range, "assigneeId");
  const lateT = lateCountByKey(tasks, now, "assigneeId");
  const techKeys = new Set<string>([...hoursT.keys(), ...compT.keys(), ...lateT.keys()]);

  const hoursS = hoursPerSite(punches);
  const compS = completionByKey(tasks, range, "siteId");
  const lateS = lateCountByKey(tasks, now, "siteId");
  const siteKeys = new Set<string>([...hoursS.keys(), ...compS.keys(), ...lateS.keys()]);

  return (
    <main className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Statistiques</h1>

      <div className="mb-6 flex gap-2 text-sm">
        {PERIODS.map((p) => (
          <a
            key={p.key}
            href={`/stats?period=${p.key}`}
            className={
              "rounded px-3 py-1 " +
              (period === p.key ? "bg-gray-900 text-white" : "border text-gray-700 hover:bg-gray-100")
            }
          >
            {p.label}
          </a>
        ))}
      </div>

      <h2 className="mb-2 text-lg font-semibold">Par technicien</h2>
      <table className="mb-8 w-full max-w-3xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Technicien</th><th>Heures</th><th>Complétion</th><th>Retards</th><th>Anomalies</th>
          </tr>
        </thead>
        <tbody>
          {[...techKeys].map((uid) => {
            const h = hoursT.get(uid);
            const c = compT.get(uid);
            return (
              <tr key={uid} className="border-b">
                <td className="py-2">{displayUser(uid, dir)}</td>
                <td>{((h?.minutes ?? 0) / 60).toFixed(2)}</td>
                <td>{c ? `${c.done}/${c.total}` : "—"}</td>
                <td className={lateT.get(uid) ? "font-semibold text-red-600" : ""}>{lateT.get(uid) ?? 0}</td>
                <td className={h?.anomalies.length ? "text-red-600" : "text-gray-400"}>
                  {h?.anomalies.length ? h.anomalies.join(", ") : "—"}
                </td>
              </tr>
            );
          })}
          {techKeys.size === 0 && <tr><td colSpan={5} className="py-2 text-gray-400">Aucune donnée sur la période.</td></tr>}
        </tbody>
      </table>

      <h2 className="mb-2 text-lg font-semibold">Par site</h2>
      <table className="w-full max-w-3xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Site</th><th>Heures</th><th>Complétion</th><th>Retards</th>
          </tr>
        </thead>
        <tbody>
          {[...siteKeys].map((sid) => {
            const c = compS.get(sid);
            return (
              <tr key={sid} className="border-b">
                <td className="py-2">{displaySite(sid, dir)}</td>
                <td>{((hoursS.get(sid) ?? 0) / 60).toFixed(2)}</td>
                <td>{c ? `${c.done}/${c.total}` : "—"}</td>
                <td className={lateS.get(sid) ? "font-semibold text-red-600" : ""}>{lateS.get(sid) ?? 0}</td>
              </tr>
            );
          })}
          {siteKeys.size === 0 && <tr><td colSpan={4} className="py-2 text-gray-400">Aucune donnée sur la période.</td></tr>}
        </tbody>
      </table>
    </main>
  );
}
