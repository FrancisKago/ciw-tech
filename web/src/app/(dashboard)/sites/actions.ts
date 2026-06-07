"use server";
import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { db } from "@/lib/firebaseAdmin";
import { getUserRole } from "@/lib/currentRole";
import { canAccessBackoffice } from "@/lib/roles";
import { parseSiteForm } from "@/lib/sites";

export type CreateSiteState = { error?: string; ok?: boolean };

export async function createSite(_prev: CreateSiteState, formData: FormData): Promise<CreateSiteState> {
  const { userId } = await auth();
  if (!userId) return { error: "Non authentifié." };
  const role = await getUserRole(userId);
  if (!canAccessBackoffice(role)) return { error: "Accès refusé." };

  const parsed = parseSiteForm({
    name: formData.get("name")?.toString(),
    lat: formData.get("lat")?.toString(),
    lng: formData.get("lng")?.toString(),
    radiusMeters: formData.get("radiusMeters")?.toString(),
  });
  if (!parsed.ok) return { error: parsed.error };

  await db().collection("sites").add({
    name: parsed.value.name,
    geo: { lat: parsed.value.lat, lng: parsed.value.lng },
    radiusMeters: parsed.value.radiusMeters,
  });
  revalidatePath("/sites");
  return { ok: true };
}
