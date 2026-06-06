import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { verifyClerkJwt, ClerkClaims } from "./clerkVerify";

// Lie le secret au runtime : sans cette déclaration, process.env.CLERK_SECRET_KEY
// est vide dans une fonction v2 déployée, même si `functions:secrets:set` a été fait.
const clerkSecretKey = defineSecret("CLERK_SECRET_KEY");

interface AuthLike { createCustomToken(uid: string, claims: object): Promise<string>; }

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
  await admin.firestore().doc(`users/${claims.userId}`).set(
    { role: claims.role, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  return buildTokenResponse(admin.auth(), claims);
});
