import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { db } from "@/lib/firebaseAdmin";
import { getUserRole } from "@/lib/currentRole";
import { canAccessBackoffice } from "@/lib/roles";
import SiteForm from "./site-form";

export const dynamic = "force-dynamic";

interface SiteDoc {
  id: string;
  name: string;
  lat: number;
  lng: number;
  radiusMeters: number;
}

export default async function SitesPage() {
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

  const snap = await db().collection("sites").get();
  const sites: SiteDoc[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      name: data.name ?? "",
      lat: data.geo?.lat ?? 0,
      lng: data.geo?.lng ?? 0,
      radiusMeters: data.radiusMeters ?? 0,
    };
  });

  return (
    <main style={{ padding: 24 }}>
      <h1>Sites</h1>
      <table cellPadding={8} style={{ borderCollapse: "collapse", width: "100%", maxWidth: 700 }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left" }}>Nom</th>
            <th style={{ textAlign: "left" }}>Latitude</th>
            <th style={{ textAlign: "left" }}>Longitude</th>
            <th style={{ textAlign: "left" }}>Rayon (m)</th>
          </tr>
        </thead>
        <tbody>
          {sites.map((s) => (
            <tr key={s.id} style={{ borderTop: "1px solid #ddd" }}>
              <td>{s.name}</td>
              <td>{s.lat}</td>
              <td>{s.lng}</td>
              <td>{s.radiusMeters}</td>
            </tr>
          ))}
          {sites.length === 0 && (
            <tr>
              <td colSpan={4}>Aucun site enregistré.</td>
            </tr>
          )}
        </tbody>
      </table>

      <SiteForm />
    </main>
  );
}
