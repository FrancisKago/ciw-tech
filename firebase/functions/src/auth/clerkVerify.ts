import { verifyToken } from "@clerk/backend";

export interface ClerkClaims { userId: string; role: string; }

interface ClerkPayload { sub?: string; public_metadata?: { role?: string }; }

export function extractClaims(payload: ClerkPayload): ClerkClaims {
  if (!payload.sub) throw new Error("invalid token: missing sub");
  const role = payload.public_metadata?.role ?? "technician";
  return { userId: payload.sub, role };
}

export async function verifyClerkJwt(token: string): Promise<ClerkClaims> {
  // TODO: confirm @clerk/backend verifyToken signature if API changes
  const payload = await verifyToken(token, { secretKey: process.env.CLERK_SECRET_KEY! });
  return extractClaims(payload as ClerkPayload);
}
