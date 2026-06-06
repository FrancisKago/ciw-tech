export type Role = "admin" | "manager" | "technician";

/** Le backoffice est réservé à la direction : admin et manager uniquement. */
export function canAccessBackoffice(role: string | null | undefined): boolean {
  return role === "admin" || role === "manager";
}
