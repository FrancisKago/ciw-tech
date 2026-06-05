import { cert, getApps, initializeApp, App } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

let app: App;
export function adminApp(): App {
  if (getApps().length) return getApps()[0];
  app = initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
  });
  return app;
}
export const db = () => getFirestore(adminApp());
