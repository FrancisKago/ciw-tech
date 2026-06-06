import { clerkClient } from "@clerk/nextjs/server";

/**
 * Lit le rôle d'un utilisateur depuis ses public metadata Clerk.
 * Indépendant de la personnalisation du jeton de session (appel API direct).
 */
export async function getUserRole(userId: string): Promise<string | undefined> {
  const client = await clerkClient();
  const user = await client.users.getUser(userId);
  const role = user.publicMetadata?.role;
  return typeof role === "string" ? role : undefined;
}
