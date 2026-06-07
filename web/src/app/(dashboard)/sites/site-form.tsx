"use client";
import { useActionState } from "react";
import { createSite, CreateSiteState } from "./actions";

const initialState: CreateSiteState = {};

export default function SiteForm() {
  const [state, action, pending] = useActionState(createSite, initialState);

  return (
    <form action={action} style={{ marginTop: 32, maxWidth: 480 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 16 }}>Créer un site</h2>

      {state.error && (
        <p role="alert" style={{ color: "crimson", marginBottom: 12 }}>
          {state.error}
        </p>
      )}
      {state.ok && (
        <p role="status" style={{ color: "green", marginBottom: 12 }}>
          Site créé avec succès.
        </p>
      )}

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        <label>
          <span style={{ display: "block", fontSize: 14, marginBottom: 4 }}>Nom</span>
          <input
            type="text"
            name="name"
            required
            style={{ width: "100%", padding: "6px 8px", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <label>
          <span style={{ display: "block", fontSize: 14, marginBottom: 4 }}>Latitude</span>
          <input
            type="number"
            name="lat"
            step="any"
            required
            style={{ width: "100%", padding: "6px 8px", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <label>
          <span style={{ display: "block", fontSize: 14, marginBottom: 4 }}>Longitude</span>
          <input
            type="number"
            name="lng"
            step="any"
            required
            style={{ width: "100%", padding: "6px 8px", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <label>
          <span style={{ display: "block", fontSize: 14, marginBottom: 4 }}>Rayon (mètres)</span>
          <input
            type="number"
            name="radiusMeters"
            step="any"
            min="1"
            required
            style={{ width: "100%", padding: "6px 8px", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <button
          type="submit"
          disabled={pending}
          style={{
            marginTop: 8,
            padding: "8px 20px",
            background: pending ? "#888" : "#1a56db",
            color: "#fff",
            border: "none",
            borderRadius: 4,
            cursor: pending ? "not-allowed" : "pointer",
            fontWeight: 600,
          }}
        >
          {pending ? "Enregistrement…" : "Créer le site"}
        </button>
      </div>
    </form>
  );
}
