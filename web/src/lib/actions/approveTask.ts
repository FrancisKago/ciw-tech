"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "@/lib/firebaseAdmin";
import { getUserRole } from "@/lib/currentRole";
import { canApprove } from "@/lib/approval";

/**
 * Valide une tâche (done → approved). Server Action : re-vérifie le rôle côté serveur
 * (on ne fait pas confiance à l'UI role-gatée) et approuve en transaction, seulement si
 * la tâche est encore au statut 'done' (garde anti-double-validation / anti-course).
 * Le rôle est lu juste avant la transaction ; cette fenêtre TOCTOU est acceptable car les
 * changements de rôle Clerk sont des opérations manuelles d'administration.
 */
export async function approveTask(formData: FormData) {
  const taskId = formData.get("taskId");
  if (typeof taskId !== "string" || !taskId) throw new Error("taskId manquant");

  const { userId } = await auth();
  if (!userId) throw new Error("non authentifié");
  const role = await getUserRole(userId);

  const database = db();
  const ref = database.doc(`tasks/${taskId}`);

  await database.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("tâche introuvable");
    const currentStatus = (snap.get("status") ?? "assigned") as string;
    if (!canApprove(role, currentStatus)) {
      throw new Error("validation non autorisée");
    }
    tx.update(ref, {
      status: "approved",
      approvedBy: userId,
      approvedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  revalidatePath("/board");
  revalidatePath(`/board/${taskId}`);
}
