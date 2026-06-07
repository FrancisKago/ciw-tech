import { db } from "@/lib/firebaseAdmin";
import { computeWorkedMinutes, PunchLite } from "@/lib/hours";
import { loadDirectory, displayUser } from "@/lib/directory";
import { parsePeriod, PeriodKey } from "@/lib/stats";

export const dynamic = "force-dynamic";

const PERIODS: { key: PeriodKey; label: string }[] = [
  { key: "today", label: "Aujourd'hui" },
  { key: "7d", label: "7 jours" },
  { key: "30d", label: "30 jours" },
];

export default async function PresencePage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string }>;
}) {
  const sp = await searchParams;
  const now = new Date();
  // Défaut 'today' : la présence est une vue quotidienne ; 7 j / 30 j restent accessibles.
  const { period, start } = parsePeriod(sp.period ?? "today", now);

  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("punches").where("clientTimestamp", ">=", start).get(),
    loadDirectory(database),
  ]);

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
    <div className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Présence</h1>

      <div className="mb-6 flex gap-2 text-sm">
        {PERIODS.map((p) => (
          <a
            key={p.key}
            href={`/presence?period=${p.key}`}
            className={
              "rounded px-3 py-1 " +
              (period === p.key ? "bg-gray-900 text-white" : "border text-gray-700 hover:bg-gray-100")
            }
          >
            {p.label}
          </a>
        ))}
      </div>

      <table className="w-full max-w-2xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Technicien</th><th>Heures</th><th>Anomalies</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.uid} className="border-b">
              <td className="py-2">{displayUser(r.uid, dir)}</td>
              <td>{r.hours}</td>
              <td className={r.anomalies.length ? "text-red-600" : "text-green-700"}>
                {r.anomalies.length ? r.anomalies.join(", ") : "—"}
              </td>
            </tr>
          ))}
          {rows.length === 0 && <tr><td colSpan={3} className="py-2 text-gray-400">Aucun pointage sur la période.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
