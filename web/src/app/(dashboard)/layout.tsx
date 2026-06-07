import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { getUserRole } from "@/lib/currentRole";
import { canAccessBackoffice } from "@/lib/roles";
import Sidebar from "@/components/Sidebar";

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
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

  return (
    <div style={{ display: "flex" }}>
      <Sidebar />
      <div style={{ flex: 1 }}>{children}</div>
    </div>
  );
}
