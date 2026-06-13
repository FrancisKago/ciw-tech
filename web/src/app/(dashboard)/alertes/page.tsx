import { db } from "@/lib/firebaseAdmin";
import { loadDirectory, displayUser, displaySite } from "@/lib/directory";
import { parsePeriod, PeriodKey } from "@/lib/stats";
import { detectAnomalies, PunchForAnomaly, SiteRef, Anomaly } from "@/lib/anomalies";

export const dynamic = "force-dynamic";

const PERIODS: { key: PeriodKey; label: string }[] = [
  { key: "today", label: "Aujourd'hui" },
  { key: "7d", label: "7 jours" },
  { key: "30d", label: "30 jours" },
];

export default async function AlertesPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string; site?: string; tech?: string }>;
}) {
  const sp = await searchParams;
  const now = new Date();
  const { period, start } = parsePeriod(sp.period ?? "7d", now);

  const database = db();
  const [snap, dir] = await Promise.all([
    database.collection("punches").where("clientTimestamp", ">=", start).get(),
    loadDirectory(database),
  ]);

  const punches: PunchForAnomaly[] = snap.docs.map((d) => {
    const data = d.data();
    const geo =
      data.geo != null
        ? { lat: data.geo.lat as number, lng: data.geo.lng as number, accuracy: data.geo.accuracy as number }
        : null;
    return {
      id: d.id,
      userId: data.userId as string,
      kind: data.kind as "in" | "out",
      clientTimestamp: data.clientTimestamp.toDate(),
      serverTimestamp: data.serverTimestamp != null ? data.serverTimestamp.toDate() : null,
      geo,
      siteId: (data.siteId as string | null) ?? null,
      photoStatus: data.photoStatus as "pending" | "uploaded",
    };
  });

  const sites = new Map<string, SiteRef>();
  for (const [id, s] of dir.sites) sites.set(id, { geo: s.geo, radiusMeters: s.radiusMeters });

  const byPunch = detectAnomalies(punches, sites, now);

  let rows = punches
    .filter((p) => byPunch.has(p.id))
    .map((p) => ({ punch: p, anomalies: byPunch.get(p.id)! }));

  if (sp.site) rows = rows.filter((r) => r.punch.siteId === sp.site);
  if (sp.tech) rows = rows.filter((r) => r.punch.userId === sp.tech);

  const hasAlerte = (a: Anomaly[]) => a.some((x) => x.severity === "alerte");
  rows.sort((x, y) => {
    const ax = hasAlerte(x.anomalies) ? 0 : 1;
    const ay = hasAlerte(y.anomalies) ? 0 : 1;
    if (ax !== ay) return ax - ay;
    return y.punch.clientTimestamp.getTime() - x.punch.clientTimestamp.getTime();
  });

  return (
    <div className="p-6">
      <h1 className="mb-4 text-2xl font-semibold">Alertes</h1>

      <div className="mb-6 flex gap-2 text-sm">
        {PERIODS.map((p) => (
          <a
            key={p.key}
            href={`/alertes?period=${p.key}`}
            className={
              "rounded px-3 py-1 " +
              (period === p.key ? "bg-gray-900 text-white" : "border text-gray-700 hover:bg-gray-100")
            }
          >
            {p.label}
          </a>
        ))}
      </div>

      <table className="w-full max-w-4xl border-collapse text-sm">
        <thead>
          <tr className="border-b text-left text-gray-500">
            <th className="py-2">Technicien</th>
            <th>Site</th>
            <th>Type</th>
            <th>Heure</th>
            <th>Anomalies</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.punch.id} className="border-b">
              <td className="py-2">{displayUser(r.punch.userId, dir)}</td>
              <td>{displaySite(r.punch.siteId ?? "", dir)}</td>
              <td>{r.punch.kind === "in" ? "Entrée" : "Sortie"}</td>
              <td>{r.punch.clientTimestamp.toLocaleString("fr-FR")}</td>
              <td>
                <div className="flex flex-wrap gap-1">
                  {r.anomalies.map((a) => (
                    <span
                      key={a.type}
                      className={
                        "rounded px-2 py-0.5 text-xs " +
                        (a.severity === "alerte"
                          ? "bg-red-100 text-red-700"
                          : "bg-amber-100 text-amber-700")
                      }
                    >
                      {a.label}
                    </span>
                  ))}
                </div>
              </td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td colSpan={5} className="py-2 text-gray-400">
                Aucune anomalie sur la période.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
