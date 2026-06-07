import type { Firestore } from "firebase-admin/firestore";

export interface Directory {
  users: Map<string, { name: string }>;
  sites: Map<string, { name: string }>;
}

/** Nom du technicien, ou son ID en repli si inconnu. */
export function displayUser(uid: string, dir: Directory): string {
  return dir.users.get(uid)?.name ?? uid;
}

/** Nom du site, ou son ID en repli si inconnu. */
export function displaySite(siteId: string, dir: Directory): string {
  return dir.sites.get(siteId)?.name ?? siteId;
}

/** Charge les collections users + sites dans des Map indexées par ID. */
export async function loadDirectory(db: Firestore): Promise<Directory> {
  const [usersSnap, sitesSnap] = await Promise.all([
    db.collection("users").get(),
    db.collection("sites").get(),
  ]);
  const users = new Map<string, { name: string }>();
  for (const d of usersSnap.docs) {
    users.set(d.id, { name: (d.data().name as string) ?? d.id });
  }
  const sites = new Map<string, { name: string }>();
  for (const d of sitesSnap.docs) {
    sites.set(d.id, { name: (d.data().name as string) ?? d.id });
  }
  return { users, sites };
}
