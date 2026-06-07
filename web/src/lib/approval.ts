import { canAccessBackoffice } from "./roles";

/**
 * Une validation n'est permise que pour un manager/admin et sur une tâche au statut 'done'
 * (idempotence : une tâche déjà 'approved' n'est pas re-validable).
 */
export function canApprove(role: string | null | undefined, currentStatus: string): boolean {
  return canAccessBackoffice(role) && currentStatus === "done";
}
