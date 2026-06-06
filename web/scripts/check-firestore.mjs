// Diagnostic : vérifie les credentials firebase-admin et un accès Firestore.
// Lancer depuis le dossier web :  node --env-file=.env.local scripts/check-firestore.mjs
import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const projectId = process.env.FIREBASE_PROJECT_ID;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
const pk = process.env.FIREBASE_PRIVATE_KEY;

console.log("FIREBASE_PROJECT_ID :", projectId);
console.log("FIREBASE_CLIENT_EMAIL :", clientEmail);
console.log("PRIVATE_KEY présent :", !!pk);
console.log("PRIVATE_KEY début :", pk ? JSON.stringify(pk.slice(0, 32)) : "(absent)");
console.log("PRIVATE_KEY contient des vrais retours-ligne :", pk ? pk.includes("\n") : false);
console.log("PRIVATE_KEY contient des \\n littéraux :", pk ? pk.includes("\\n") : false);
console.log("---");

try {
  initializeApp({
    credential: cert({
      projectId,
      clientEmail,
      privateKey: pk?.replace(/\\n/g, "\n"),
    }),
  });
  const snap = await getFirestore().collection("punches").limit(1).get();
  console.log("✅ LECTURE FIRESTORE OK — documents lus :", snap.size);
} catch (e) {
  console.error("❌ ÉCHEC :", e.code ?? "(no code)", "-", e.message);
}
