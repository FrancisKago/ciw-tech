import type { Firestore } from "firebase-admin/firestore";

export interface Directory {
  users: Map<string, { name: string }>;
  sites: Map<string, { name: string }>;
}

/** Forme minimale d'un utilisateur Clerk dont on dérive un nom d'affichage. */
export interface ClerkUserLite {
  id: string;
  firstName?: string | null;
  lastName?: string | null;
  username?: string | null;
  primaryEmailAddressId?: string | null;
  emailAddresses?: { id: string; emailAddress: string }[];
}

/**
 * Nom d'affichage d'un utilisateur Clerk : prénom+nom → username → email principal → id.
 * Clerk étant la source d'identité du projet, ceci garantit un libellé lisible même quand
 * le doc Firestore `users` n'a pas de champ `name`.
 */
export function clerkDisplayName(u: ClerkUserLite): string {
  const name = [u.firstName, u.lastName].filter(Boolean).join(" ").trim();
  if (name) return name;
  if (u.username) return u.username;
  const primary =
    u.emailAddresses?.find((e) => e.id === u.primaryEmailAddressId)?.emailAddress ??
    u.emailAddresses?.[0]?.emailAddress;
  if (primary) return primary;
  return u.id;
}

/** Nom du technicien, ou son ID en repli si inconnu. */
export function displayUser(uid: string, dir: Directory): string {
  return dir.users.get(uid)?.name ?? uid;
}

/** Nom du site ; 'Sans site' si le pointage n'a pas de siteId ; l'ID en repli si site inconnu. */
export function displaySite(siteId: string, dir: Directory): string {
  if (!siteId) return "Sans site";
  return dir.sites.get(siteId)?.name ?? siteId;
}

/**
 * Construit l'annuaire : noms d'utilisateurs depuis **Clerk** (source d'identité),
 * sites depuis Firestore. `clerkClient` est importé dynamiquement pour que ce module
 * reste sans effet de bord à l'import (tests unitaires en env node sans Clerk).
 */
export async function loadDirectory(db: Firestore): Promise<Directory> {
  const { clerkClient } = await import("@clerk/nextjs/server");
  const client = await clerkClient();
  const [userList, sitesSnap] = await Promise.all([
    client.users.getUserList({ limit: 500 }),
    db.collection("sites").get(),
  ]);

  const users = new Map<string, { name: string }>();
  for (const u of userList.data) {
    users.set(u.id, { name: clerkDisplayName(u) });
  }
  const sites = new Map<string, { name: string }>();
  for (const d of sitesSnap.docs) {
    sites.set(d.id, { name: (d.data().name as string) ?? d.id });
  }
  return { users, sites };
}
