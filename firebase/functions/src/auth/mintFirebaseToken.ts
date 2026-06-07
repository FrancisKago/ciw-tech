import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { createClerkClient } from "@clerk/backend";
import { verifyClerkJwt, ClerkClaims } from "./clerkVerify";

// Lie le secret au runtime : sans cette déclaration, process.env.CLERK_SECRET_KEY
// est vide dans une fonction v2 déployée, même si `functions:secrets:set` a été fait.
const clerkSecretKey = defineSecret("CLERK_SECRET_KEY");

interface AuthLike { createCustomToken(uid: string, claims: object): Promise<string>; }

interface ClerkUserLite {
  firstName?: string | null;
  lastName?: string | null;
  phoneNumbers?: { phoneNumber: string }[];
}

export function buildUserProfile(role: string, user: ClerkUserLite | null) {
  const name = [user?.firstName, user?.lastName].filter(Boolean).join(" ").trim();
  const phone = user?.phoneNumbers?.[0]?.phoneNumber;
  return {
    role,
    ...(name ? { name } : {}),
    ...(phone ? { phone } : {}),
  };
}

export async function buildTokenResponse(auth: AuthLike, claims: ClerkClaims) {
  const firebaseToken = await auth.createCustomToken(claims.userId, { role: claims.role });
  return { firebaseToken };
}

export const mintFirebaseToken = onCall({ secrets: [clerkSecretKey] }, async (request) => {
  const clerkJwt = request.data?.clerkJwt as string | undefined;
  if (!clerkJwt) throw new HttpsError("invalid-argument", "clerkJwt requis");
  let claims: ClerkClaims;
  try {
    claims = await verifyClerkJwt(clerkJwt);
  } catch {
    throw new HttpsError("unauthenticated", "JWT Clerk invalide");
  }
  let profile: { role: string; name?: string; phone?: string } = { role: claims.role };
  try {
    const clerk = createClerkClient({ secretKey: process.env.CLERK_SECRET_KEY! });
    const user = await clerk.users.getUser(claims.userId);
    profile = buildUserProfile(claims.role, user as ClerkUserLite);
  } catch {
    // En cas d'échec API Clerk, on conserve au moins le rôle.
  }
  await admin.firestore().doc(`users/${claims.userId}`).set(
    { ...profile, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  return buildTokenResponse(admin.auth(), claims);
});
