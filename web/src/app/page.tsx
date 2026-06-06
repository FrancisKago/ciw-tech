import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { SignInButton } from "@clerk/nextjs";

export default async function Home() {
  const { userId } = await auth();
  if (userId) redirect("/presence");

  return (
    <div style={{ padding: 48, maxWidth: 560, margin: "0 auto", textAlign: "center" }}>
      <h1 style={{ fontSize: 28, fontWeight: 600 }}>Cameroon Innovation — Backoffice</h1>
      <p style={{ marginTop: 12, color: "#555" }}>
        Suivi des heures et des tâches des techniciens.
      </p>
      <div style={{ marginTop: 24 }}>
        <SignInButton mode="modal">
          <button
            style={{
              padding: "10px 20px",
              fontSize: 16,
              borderRadius: 8,
              border: "none",
              background: "#3730a3",
              color: "white",
              cursor: "pointer",
            }}
          >
            Se connecter
          </button>
        </SignInButton>
      </div>
    </div>
  );
}
