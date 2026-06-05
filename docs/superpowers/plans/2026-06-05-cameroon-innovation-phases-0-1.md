# Cameroon Innovation — Phases 0 + 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire les fondations du produit (auth Clerk↔Firebase de bout en bout) puis la fonctionnalité de **pointage offline-first GPS+photo** avec synchronisation et une vue présence/heures au backoffice.

**Architecture:** Monorepo à trois dossiers — `mobile/` (Flutter Android, offline-first, Riverpod), `web/` (Next.js App Router sur Vercel, backoffice direction), `firebase/` (Firestore + Storage + Cloud Functions TypeScript + règles de sécurité). L'identité est gérée par Clerk ; une Cloud Function `mintFirebaseToken` échange le JWT Clerk contre un jeton Firebase personnalisé portant le rôle en *custom claim*. Les pointages sont écrits dans Firestore (synchro offline automatique) et leurs photos passent par une file locale Drift uploadée vers Storage au retour du réseau.

**Tech Stack:** Flutter 3.x · Riverpod · Drift (SQLite) · geolocator · image_picker · firebase_core/auth/firestore/storage · clerk_flutter · Next.js 15 (App Router) · @clerk/nextjs · firebase-admin · Firebase Cloud Functions (TypeScript) · @clerk/backend · Firebase Local Emulator Suite.

> **Note d'intégration tierce :** les API de `clerk_flutter` / `@clerk/backend` évoluent. Aux tâches concernées, confirmer la signature exacte des méthodes via le MCP **context7** (`resolve-library-id` → `query-docs`) avant de coder. Le plan isole ces appels derrière des services fins pour limiter l'impact d'un changement d'API.

**Pré-requis (comptes à créer par la direction, hors code) :**
- Compte **Firebase** + projet `cameroon-innovation` (plan Blaze requis pour les Cloud Functions, paliers gratuits suffisants au démarrage).
- Compte **Clerk** + une application (récupérer `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`, `CLERK_JWT_ISSUER`/JWKS URL).
- Compte **Vercel** (déploiement du backoffice — peut attendre la fin de Phase 1).
- Outils locaux : Node 20+, Flutter SDK, `firebase-tools` (`npm i -g firebase-tools`), Java (pour les émulateurs).

---

## File Structure

```
App pointage/
├── docs/superpowers/...                  (spec + ce plan)
├── firebase/
│   ├── firebase.json                     config émulateurs + déploiement
│   ├── .firebaserc
│   ├── firestore.rules                   règles de sécurité Firestore
│   ├── storage.rules                     règles de sécurité Storage
│   ├── firestore.indexes.json
│   └── functions/
│       ├── package.json
│       ├── tsconfig.json
│       ├── src/
│       │   ├── index.ts                  exports des fonctions
│       │   ├── auth/mintFirebaseToken.ts pont Clerk → Firebase custom token
│       │   └── auth/clerkVerify.ts       vérification du JWT Clerk (isolé)
│       └── test/
│           ├── mintFirebaseToken.test.ts
│           └── rules.test.ts             tests des règles Firestore (emulator)
├── web/                                   backoffice Next.js
│   ├── package.json
│   ├── middleware.ts                      Clerk middleware
│   ├── lib/firebaseAdmin.ts               init firebase-admin (serveur)
│   ├── lib/hours.ts                       calcul des heures (pairing in/out)
│   ├── lib/geo.ts                         distance GPS / hors-rayon
│   ├── app/(dashboard)/presence/page.tsx  vue présence du jour
│   ├── app/layout.tsx                     ClerkProvider
│   └── __tests__/
│       ├── hours.test.ts
│       └── geo.test.ts
└── mobile/                                app Flutter
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── core/firebase_bootstrap.dart
    │   ├── auth/clerk_auth_service.dart   récupère le JWT Clerk (isolé)
    │   ├── auth/firebase_bridge.dart      appelle mintFirebaseToken + signIn
    │   ├── models/punch.dart
    │   ├── models/site.dart
    │   ├── pointage/geo_service.dart      capture GPS + permissions
    │   ├── pointage/photo_service.dart    capture photo
    │   ├── pointage/punch_repository.dart écrit le doc Firestore + enqueue photo
    │   ├── outbox/outbox_db.dart          Drift: file d'attente photos
    │   ├── outbox/outbox_uploader.dart    upload Storage + patch doc
    │   ├── pointage/pointage_screen.dart  écran de pointage
    │   └── widgets/sync_badge.dart        "X non synchronisés"
    └── test/
        ├── punch_test.dart
        ├── outbox_db_test.dart
        ├── outbox_uploader_test.dart
        └── hours_local_test.dart
```

---

# PHASE 0 — Fondations & pont d'authentification

### Task 0.1: Structure du dépôt

**Files:**
- Create: `mobile/.gitkeep`, `web/.gitkeep`, `firebase/.gitkeep`
- Create: `.gitignore`

- [ ] **Step 1: Créer les dossiers et le .gitignore**

Créer `.gitignore` à la racine :

```gitignore
# Node
node_modules/
.next/
firebase/functions/lib/
# Flutter
mobile/.dart_tool/
mobile/build/
mobile/.flutter-plugins*
# Secrets / env
.env
.env.local
*.local
serviceAccount*.json
# Firebase
firebase/.runtimeconfig.json
.firebase/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore mobile/.gitkeep web/.gitkeep firebase/.gitkeep
git commit -m "chore: structure de depot (mobile/web/firebase)"
```

---

### Task 0.2: Initialiser Firebase (émulateurs en premier)

**Files:**
- Create: `firebase/firebase.json`, `firebase/.firebaserc`, `firebase/firestore.rules`, `firebase/storage.rules`, `firebase/firestore.indexes.json`

- [ ] **Step 1: Écrire `firebase/firebase.json`**

```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "storage": { "rules": "storage.rules" },
  "functions": { "source": "functions", "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"] },
  "emulators": {
    "auth": { "port": 9099 },
    "functions": { "port": 5001 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
}
```

- [ ] **Step 2: Écrire `firebase/.firebaserc`**

```json
{ "projects": { "default": "cameroon-innovation" } }
```

- [ ] **Step 3: Écrire des règles temporaires verrouillées**

`firebase/firestore.rules` :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /{document=**} { allow read, write: if false; }
  }
}
```

`firebase/storage.rules` :

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} { allow read, write: if false; }
  }
}
```

`firebase/firestore.indexes.json` :

```json
{ "indexes": [], "fieldOverrides": [] }
```

- [ ] **Step 4: Vérifier que les émulateurs démarrent**

Run: `cd firebase && firebase emulators:start --only firestore,auth,storage`
Expected: « All emulators ready » + UI sur http://localhost:4000. Puis arrêter (Ctrl+C).

- [ ] **Step 5: Commit**

```bash
git add firebase/
git commit -m "chore(firebase): config emulateurs + regles verrouillees"
```

---

### Task 0.3: Cloud Functions — squelette TypeScript

**Files:**
- Create: `firebase/functions/package.json`, `firebase/functions/tsconfig.json`, `firebase/functions/src/index.ts`, `firebase/functions/.env.example`

- [ ] **Step 1: `firebase/functions/package.json`**

```json
{
  "name": "functions",
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "test": "jest"
  },
  "dependencies": {
    "@clerk/backend": "^1.0.0",
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.0",
    "@types/jest": "^29.5.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.0",
    "typescript": "^5.4.0"
  }
}
```

- [ ] **Step 2: `firebase/functions/tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2021",
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

- [ ] **Step 3: `firebase/functions/.env.example`**

```
CLERK_SECRET_KEY=sk_test_xxx
CLERK_JWT_KEY=
```

- [ ] **Step 4: `firebase/functions/src/index.ts` (stub)**

```ts
import * as admin from "firebase-admin";
admin.initializeApp();

export { mintFirebaseToken } from "./auth/mintFirebaseToken";
```

- [ ] **Step 5: Installer + build**

Run: `cd firebase/functions && npm install && npm run build`
Expected: compile (échec attendu tant que `mintFirebaseToken` n'existe pas — créé en 0.5 ; pour l'instant retirer la ligne export ou créer un stub vide).

Créer un stub `firebase/functions/src/auth/mintFirebaseToken.ts` :

```ts
export const mintFirebaseToken = null as unknown;
```

Re-run build → succès.

- [ ] **Step 6: Commit**

```bash
git add firebase/functions
git commit -m "chore(functions): squelette typescript"
```

---

### Task 0.4: Vérification du JWT Clerk (isolée, TDD)

**Files:**
- Create: `firebase/functions/src/auth/clerkVerify.ts`
- Test: `firebase/functions/test/clerkVerify.test.ts`
- Create: `firebase/functions/jest.config.js`

> Confirmer l'API de `@clerk/backend` (`verifyToken`) via context7 avant de coder.

- [ ] **Step 1: `firebase/functions/jest.config.js`**

```js
module.exports = { preset: "ts-jest", testEnvironment: "node", testMatch: ["**/test/**/*.test.ts"] };
```

- [ ] **Step 2: Écrire le test qui échoue**

`firebase/functions/test/clerkVerify.test.ts` :

```ts
import { extractClaims } from "../src/auth/clerkVerify";

describe("extractClaims", () => {
  it("retourne userId et role depuis un payload Clerk vérifié", () => {
    const payload = { sub: "user_123", public_metadata: { role: "technician" } };
    expect(extractClaims(payload)).toEqual({ userId: "user_123", role: "technician" });
  });

  it("utilise le rôle 'technician' par défaut si absent", () => {
    const payload = { sub: "user_456", public_metadata: {} };
    expect(extractClaims(payload)).toEqual({ userId: "user_456", role: "technician" });
  });

  it("rejette un payload sans sub", () => {
    expect(() => extractClaims({ public_metadata: {} } as never)).toThrow("invalid token: missing sub");
  });
});
```

- [ ] **Step 3: Lancer le test → échec**

Run: `cd firebase/functions && npx jest clerkVerify`
Expected: FAIL (`extractClaims` non défini).

- [ ] **Step 4: Implémenter**

`firebase/functions/src/auth/clerkVerify.ts` :

```ts
import { verifyToken } from "@clerk/backend";

export interface ClerkClaims { userId: string; role: string; }

interface ClerkPayload { sub?: string; public_metadata?: { role?: string }; }

export function extractClaims(payload: ClerkPayload): ClerkClaims {
  if (!payload.sub) throw new Error("invalid token: missing sub");
  const role = payload.public_metadata?.role ?? "technician";
  return { userId: payload.sub, role };
}

export async function verifyClerkJwt(token: string): Promise<ClerkClaims> {
  const payload = await verifyToken(token, { secretKey: process.env.CLERK_SECRET_KEY! });
  return extractClaims(payload as ClerkPayload);
}
```

- [ ] **Step 5: Lancer le test → succès**

Run: `npx jest clerkVerify`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/auth/clerkVerify.ts firebase/functions/test/clerkVerify.test.ts firebase/functions/jest.config.js
git commit -m "feat(functions): verification et extraction des claims Clerk"
```

---

### Task 0.5: Cloud Function `mintFirebaseToken`

**Files:**
- Modify: `firebase/functions/src/auth/mintFirebaseToken.ts`
- Test: `firebase/functions/test/mintFirebaseToken.test.ts`

- [ ] **Step 1: Écrire le test qui échoue**

`firebase/functions/test/mintFirebaseToken.test.ts` :

```ts
import { buildTokenResponse } from "../src/auth/mintFirebaseToken";

describe("buildTokenResponse", () => {
  it("crée un custom token avec uid = userId et le rôle en claim", async () => {
    const fakeAuth = {
      createCustomToken: (uid: string, claims: object) =>
        Promise.resolve(`token:${uid}:${JSON.stringify(claims)}`),
    };
    const res = await buildTokenResponse(fakeAuth as never, { userId: "user_123", role: "manager" });
    expect(res.firebaseToken).toBe('token:user_123:{"role":"manager"}');
  });
});
```

- [ ] **Step 2: Lancer → échec**

Run: `cd firebase/functions && npx jest mintFirebaseToken`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`firebase/functions/src/auth/mintFirebaseToken.ts` :

```ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { verifyClerkJwt, ClerkClaims } from "./clerkVerify";

interface AuthLike { createCustomToken(uid: string, claims: object): Promise<string>; }

export async function buildTokenResponse(auth: AuthLike, claims: ClerkClaims) {
  const firebaseToken = await auth.createCustomToken(claims.userId, { role: claims.role });
  return { firebaseToken };
}

export const mintFirebaseToken = onCall(async (request) => {
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
```

- [ ] **Step 4: Lancer → succès**

Run: `npx jest mintFirebaseToken`
Expected: PASS.

- [ ] **Step 5: Build complet**

Run: `npm run build`
Expected: compile sans erreur.

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/auth/mintFirebaseToken.ts firebase/functions/test/mintFirebaseToken.test.ts firebase/functions/src/index.ts
git commit -m "feat(functions): mintFirebaseToken (pont Clerk -> Firebase)"
```

---

### Task 0.6: Règles de sécurité Firestore basées sur le rôle (TDD émulateur)

**Files:**
- Modify: `firebase/firestore.rules`
- Test: `firebase/functions/test/rules.test.ts`

- [ ] **Step 1: Écrire le test qui échoue (rules-unit-testing)**

`firebase/functions/test/rules.test.ts` :

```ts
import { initializeTestEnvironment, RulesTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { setDoc, doc, getDoc } from "firebase/firestore";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "cameroon-innovation",
    firestore: { rules: readFileSync("../firestore.rules", "utf8"), host: "localhost", port: 8080 },
  });
});
afterAll(() => env.cleanup());
beforeEach(() => env.clearFirestore());

function ctx(uid: string, role: string) {
  return env.authenticatedContext(uid, { role }).firestore();
}

describe("règles punches", () => {
  it("un technicien peut créer SON propre pointage", async () => {
    const db = ctx("user_1", "technician");
    await assertSucceeds(setDoc(doc(db, "punches/p1"), { userId: "user_1", kind: "in" }));
  });
  it("un technicien ne peut PAS créer un pointage pour un autre", async () => {
    const db = ctx("user_1", "technician");
    await assertFails(setDoc(doc(db, "punches/p2"), { userId: "user_2", kind: "in" }));
  });
  it("un technicien ne peut PAS lire le pointage d'un autre", async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), "punches/p3"), { userId: "user_2", kind: "in" }));
    const db = ctx("user_1", "technician");
    await assertFails(getDoc(doc(db, "punches/p3")));
  });
  it("un manager peut lire le pointage d'un autre", async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), "punches/p4"), { userId: "user_2", kind: "in" }));
    const db = ctx("mgr", "manager");
    await assertSucceeds(getDoc(doc(db, "punches/p4")));
  });
});
```

Ajouter `firebase` aux devDependencies des functions : `npm i -D firebase`.

- [ ] **Step 2: Lancer → échec**

Run: `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected: FAIL (règles verrouillées → même les cas « succeeds » échouent).

- [ ] **Step 3: Écrire les règles**

`firebase/firestore.rules` :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function isSignedIn() { return request.auth != null; }
    function role() { return request.auth.token.role; }
    function isManager() { return isSignedIn() && (role() == "manager" || role() == "admin"); }

    match /users/{userId} {
      allow read: if isSignedIn() && (request.auth.uid == userId || isManager());
      allow write: if false; // écrit uniquement par les Cloud Functions (admin)
    }

    match /sites/{siteId} {
      allow read: if isSignedIn();
      allow write: if isManager();
    }

    match /punches/{punchId} {
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow read: if isSignedIn() && (resource.data.userId == request.auth.uid || isManager());
      allow update: if isSignedIn() && resource.data.userId == request.auth.uid
                    && request.resource.data.userId == resource.data.userId;
      allow delete: if false;
    }
  }
}
```

- [ ] **Step 4: Lancer → succès**

Run: `firebase emulators:exec --only firestore "cd functions && npx jest rules"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules firebase/functions/test/rules.test.ts firebase/functions/package.json
git commit -m "feat(firebase): regles de securite Firestore basees sur le role"
```

---

### Task 0.7: Backoffice Next.js — scaffold + Clerk + firebase-admin

**Files:**
- Create: `web/` (via `create-next-app`), `web/middleware.ts`, `web/app/layout.tsx`, `web/lib/firebaseAdmin.ts`, `web/.env.local.example`

- [ ] **Step 1: Scaffolder Next.js**

Run: `cd web && npx create-next-app@latest . --ts --app --tailwind --eslint --src-dir=false --import-alias "@/*" --no-turbopack --yes`
Expected: projet créé.

- [ ] **Step 2: Installer Clerk + firebase-admin + jest**

Run: `npm i @clerk/nextjs firebase-admin && npm i -D jest ts-jest @types/jest`

- [ ] **Step 3: `web/.env.local.example`**

```
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_xxx
CLERK_SECRET_KEY=sk_test_xxx
FIREBASE_PROJECT_ID=cameroon-innovation
FIREBASE_CLIENT_EMAIL=xxx@cameroon-innovation.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

- [ ] **Step 4: `web/middleware.ts`**

```ts
import { clerkMiddleware } from "@clerk/nextjs/server";
export default clerkMiddleware();
export const config = { matcher: ["/((?!_next|.*\\..*).*)", "/(api|trpc)(.*)"] };
```

- [ ] **Step 5: `web/app/layout.tsx`**

```tsx
import { ClerkProvider, SignedIn, SignedOut, SignInButton, UserButton } from "@clerk/nextjs";
import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="fr">
        <body>
          <header style={{ display: "flex", justifyContent: "flex-end", padding: 12 }}>
            <SignedOut><SignInButton /></SignedOut>
            <SignedIn><UserButton /></SignedIn>
          </header>
          <main>{children}</main>
        </body>
      </html>
    </ClerkProvider>
  );
}
```

- [ ] **Step 6: `web/lib/firebaseAdmin.ts`**

```ts
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
```

- [ ] **Step 7: Vérifier le démarrage**

Run: `npm run dev` (avec `.env.local` rempli)
Expected: page d'accueil + bouton « Sign in » Clerk. Arrêter ensuite.

- [ ] **Step 8: Commit**

```bash
git add web/ ':!web/node_modules'
git commit -m "feat(web): scaffold Next.js + Clerk + firebase-admin"
```

---

### Task 0.8: App Flutter — scaffold + bootstrap Firebase

**Files:**
- Create: `mobile/` (via `flutter create`), `mobile/pubspec.yaml` (deps), `mobile/lib/core/firebase_bootstrap.dart`

- [ ] **Step 1: Scaffolder Flutter (Android only)**

Run: `cd mobile && flutter create . --org com.cameroon.innovation --platforms android --project-name pointage`
Expected: projet Android créé.

- [ ] **Step 2: Ajouter les dépendances**

Éditer `mobile/pubspec.yaml` (section dependencies) :

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  cloud_functions: ^5.0.0
  geolocator: ^12.0.0
  image_picker: ^1.1.0
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  connectivity_plus: ^6.0.0
  clerk_flutter: ^0.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
```

Run: `flutter pub get`
Expected: résolution OK.

> Si `clerk_flutter` n'est pas disponible/compatible, confirmer le nom/version exacts via context7 ou pub.dev avant de continuer.

- [ ] **Step 3: Configurer Firebase pour Android**

Run: `dart pub global activate flutterfire_cli && flutterfire configure --project=cameroon-innovation --platforms=android`
Expected: génère `mobile/lib/firebase_options.dart` + `android/app/google-services.json`.

- [ ] **Step 4: `mobile/lib/core/firebase_bootstrap.dart`**

```dart
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
```

- [ ] **Step 5: Vérifier le build**

Run: `flutter analyze`
Expected: « No issues found » (ou seulement des infos).

- [ ] **Step 6: Commit**

```bash
git add mobile/ ':!mobile/build'
git commit -m "feat(mobile): scaffold Flutter Android + bootstrap Firebase"
```

---

### Task 0.9: Pont d'auth côté Flutter (Clerk → Firebase)

**Files:**
- Create: `mobile/lib/auth/clerk_auth_service.dart`, `mobile/lib/auth/firebase_bridge.dart`
- Test: `mobile/test/firebase_bridge_test.dart`

> Le service Clerk isole l'API `clerk_flutter`. Confirmer la méthode exacte d'obtention du JWT de session via context7/pub.dev.

- [ ] **Step 1: Écrire le test qui échoue (logique du bridge, sans réseau)**

`mobile/test/firebase_bridge_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/auth/firebase_bridge.dart';

void main() {
  test('extractFirebaseToken lit le champ firebaseToken de la réponse', () {
    expect(extractFirebaseToken({'firebaseToken': 'abc'}), 'abc');
  });

  test('extractFirebaseToken lève si le champ est absent', () {
    expect(() => extractFirebaseToken({}), throwsA(isA<StateError>()));
  });
}
```

- [ ] **Step 2: Lancer → échec**

Run: `cd mobile && flutter test test/firebase_bridge_test.dart`
Expected: FAIL (fonction inexistante).

- [ ] **Step 3: Implémenter les services**

`mobile/lib/auth/clerk_auth_service.dart` :

```dart
// Wrapper fin autour de clerk_flutter. Confirmer l'API exacte via la doc du package.
abstract class ClerkAuthService {
  /// Retourne le JWT de session Clerk de l'utilisateur connecté, ou null.
  Future<String?> sessionJwt();
}
```

`mobile/lib/auth/firebase_bridge.dart` :

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'clerk_auth_service.dart';

String extractFirebaseToken(Map<dynamic, dynamic> data) {
  final token = data['firebaseToken'];
  if (token is! String) throw StateError('firebaseToken absent de la réponse');
  return token;
}

class FirebaseBridge {
  FirebaseBridge(this._clerk, this._functions, this._auth);
  final ClerkAuthService _clerk;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  /// Échange le JWT Clerk contre un jeton Firebase et connecte l'utilisateur.
  Future<void> signInToFirebase() async {
    final jwt = await _clerk.sessionJwt();
    if (jwt == null) throw StateError('Aucune session Clerk active');
    final callable = _functions.httpsCallable('mintFirebaseToken');
    final result = await callable.call(<String, dynamic>{'clerkJwt': jwt});
    final firebaseToken = extractFirebaseToken(result.data as Map);
    await _auth.signInWithCustomToken(firebaseToken);
  }
}
```

- [ ] **Step 4: Lancer → succès**

Run: `flutter test test/firebase_bridge_test.dart`
Expected: PASS.

- [ ] **Step 5: Vérification d'intégration manuelle (émulateurs)**

Démarrer émulateurs (`firebase emulators:start`), pointer l'app dessus (ajouter dans `main.dart` `FirebaseFunctions.instance.useFunctionsEmulator('10.0.2.2', 5001)` et idem Auth/Firestore en mode debug), se connecter via Clerk, appeler `signInToFirebase()`, vérifier qu'un doc `users/{id}` est créé dans l'UI émulateur.
Expected: utilisateur Firebase connecté + doc users créé avec le bon rôle.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/auth mobile/test/firebase_bridge_test.dart
git commit -m "feat(mobile): pont d'auth Clerk -> Firebase custom token"
```

---

**🔁 CHECKPOINT PHASE 0 :** À ce stade, un utilisateur peut se connecter avec Clerk sur mobile **et** web, obtenir une identité Firebase avec son rôle, et les règles de sécurité distinguent technicien/manager. **Demander une revue avant la Phase 1.**

---

# PHASE 1 — Pointage offline-first (GPS + photo)

### Task 1.1: Modèles `Site` et `Punch` (Flutter, TDD)

**Files:**
- Create: `mobile/lib/models/site.dart`, `mobile/lib/models/punch.dart`
- Test: `mobile/test/punch_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

`mobile/test/punch_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/punch.dart';

void main() {
  test('toFirestore sérialise les champs attendus', () {
    final p = Punch(
      id: 'p1', userId: 'u1', kind: PunchKind.checkIn,
      clientTimestamp: DateTime.utc(2026, 6, 5, 8, 0),
      lat: 4.05, lng: 9.7, accuracy: 12.0, siteId: 's1',
      photoStatus: PhotoStatus.pending,
    );
    final map = p.toFirestore();
    expect(map['userId'], 'u1');
    expect(map['kind'], 'in');
    expect(map['geo'], {'lat': 4.05, 'lng': 9.7, 'accuracy': 12.0});
    expect(map['photoStatus'], 'pending');
    expect(map.containsKey('serverTimestamp'), true); // sentinel
  });

  test('kind sérialisé en in/out', () {
    expect(PunchKind.checkOut.wire, 'out');
    expect(PunchKindX.fromWire('in'), PunchKind.checkIn);
  });
}
```

- [ ] **Step 2: Lancer → échec**

Run: `cd mobile && flutter test test/punch_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`mobile/lib/models/site.dart` :

```dart
class Site {
  Site({required this.id, required this.name, required this.lat, required this.lng, required this.radiusMeters});
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  factory Site.fromFirestore(String id, Map<String, dynamic> d) => Site(
        id: id,
        name: d['name'] as String,
        lat: (d['geo']['lat'] as num).toDouble(),
        lng: (d['geo']['lng'] as num).toDouble(),
        radiusMeters: (d['radiusMeters'] as num).toDouble(),
      );
}
```

`mobile/lib/models/punch.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PunchKind { checkIn, checkOut }
extension PunchKindX on PunchKind {
  String get wire => this == PunchKind.checkIn ? 'in' : 'out';
  static PunchKind fromWire(String w) => w == 'in' ? PunchKind.checkIn : PunchKind.checkOut;
}

enum PhotoStatus { pending, uploaded }
extension PhotoStatusX on PhotoStatus {
  String get wire => this == PhotoStatus.pending ? 'pending' : 'uploaded';
}

class Punch {
  Punch({
    required this.id, required this.userId, required this.kind,
    required this.clientTimestamp, required this.lat, required this.lng,
    required this.accuracy, required this.siteId, required this.photoStatus,
    this.photoUrl,
  });
  final String id;
  final String userId;
  final PunchKind kind;
  final DateTime clientTimestamp;
  final double lat, lng, accuracy;
  final String? siteId;
  final PhotoStatus photoStatus;
  final String? photoUrl;

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'kind': kind.wire,
        'clientTimestamp': Timestamp.fromDate(clientTimestamp),
        'serverTimestamp': FieldValue.serverTimestamp(),
        'geo': {'lat': lat, 'lng': lng, 'accuracy': accuracy},
        'siteId': siteId,
        'photoStatus': photoStatus.wire,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}
```

- [ ] **Step 4: Lancer → succès**

Run: `flutter test test/punch_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models mobile/test/punch_test.dart
git commit -m "feat(mobile): modeles Site et Punch"
```

---

### Task 1.2: File d'attente locale Drift (outbox, TDD)

**Files:**
- Create: `mobile/lib/outbox/outbox_db.dart`
- Test: `mobile/test/outbox_db_test.dart`

- [ ] **Step 1: Définir la table + le DAO**

`mobile/lib/outbox/outbox_db.dart` :

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'outbox_db.g.dart';

class PendingPhotos extends Table {
  TextColumn get punchId => text()();
  TextColumn get localPath => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {punchId};
}

@DriftDatabase(tables: [PendingPhotos])
class OutboxDb extends _$OutboxDb {
  OutboxDb(super.e);
  factory OutboxDb.memory() => OutboxDb(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<void> enqueue(String punchId, String localPath) =>
      into(pendingPhotos).insertOnConflictUpdate(
          PendingPhotosCompanion.insert(punchId: punchId, localPath: localPath));

  Future<List<PendingPhoto>> pending() => select(pendingPhotos).get();

  Future<void> remove(String punchId) =>
      (delete(pendingPhotos)..where((t) => t.punchId.equals(punchId))).go();

  Future<void> bumpAttempts(String punchId) async {
    final row = await (select(pendingPhotos)..where((t) => t.punchId.equals(punchId))).getSingle();
    await (update(pendingPhotos)..where((t) => t.punchId.equals(punchId)))
        .write(PendingPhotosCompanion(attempts: Value(row.attempts + 1)));
  }

  Future<int> count() async =>
      (await select(pendingPhotos).get()).length;
}
```

- [ ] **Step 2: Générer le code Drift**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: crée `outbox_db.g.dart`.

- [ ] **Step 3: Écrire le test**

`mobile/test/outbox_db_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/outbox_db.dart';

void main() {
  late OutboxDb db;
  setUp(() => db = OutboxDb.memory());
  tearDown(() => db.close());

  test('enqueue puis pending retourne l\'élément', () async {
    await db.enqueue('p1', '/tmp/p1.jpg');
    final items = await db.pending();
    expect(items.length, 1);
    expect(items.first.localPath, '/tmp/p1.jpg');
  });

  test('remove vide la file', () async {
    await db.enqueue('p1', '/tmp/p1.jpg');
    await db.remove('p1');
    expect(await db.count(), 0);
  });

  test('bumpAttempts incrémente', () async {
    await db.enqueue('p1', '/tmp/p1.jpg');
    await db.bumpAttempts('p1');
    final row = (await db.pending()).first;
    expect(row.attempts, 1);
  });
}
```

- [ ] **Step 4: Lancer → succès**

Run: `flutter test test/outbox_db_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/outbox/outbox_db.dart mobile/lib/outbox/outbox_db.g.dart mobile/test/outbox_db_test.dart
git commit -m "feat(mobile): file d'attente locale Drift (outbox photos)"
```

---

### Task 1.3: Service GPS (permissions + capture)

**Files:**
- Create: `mobile/lib/pointage/geo_service.dart`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml` (permissions)

- [ ] **Step 1: Permissions Android**

Ajouter dans `AndroidManifest.xml`, avant `<application>` :

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] **Step 2: Implémenter le service**

`mobile/lib/pointage/geo_service.dart` :

```dart
import 'package:geolocator/geolocator.dart';

class GeoDenied implements Exception { const GeoDenied(); }

class GeoFix {
  GeoFix(this.lat, this.lng, this.accuracy);
  final double lat, lng, accuracy;
}

class GeoService {
  /// Lève [GeoDenied] si la permission est refusée — le pointage est alors bloqué.
  Future<GeoFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const GeoDenied();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw const GeoDenied();
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoFix(pos.latitude, pos.longitude, pos.accuracy);
  }
}
```

- [ ] **Step 3: Vérifier la compilation**

Run: `cd mobile && flutter analyze lib/pointage/geo_service.dart`
Expected: pas d'erreur.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/pointage/geo_service.dart mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat(mobile): service GPS + permissions Android"
```

---

### Task 1.4: Service Photo

**Files:**
- Create: `mobile/lib/pointage/photo_service.dart`

- [ ] **Step 1: Implémenter**

`mobile/lib/pointage/photo_service.dart` :

```dart
import 'package:image_picker/image_picker.dart';

class PhotoCancelled implements Exception { const PhotoCancelled(); }

class PhotoService {
  PhotoService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// Ouvre la caméra. Retourne le chemin local. Lève [PhotoCancelled] si annulé.
  Future<String> capture() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 1280);
    if (file == null) throw const PhotoCancelled();
    return file.path;
  }
}
```

- [ ] **Step 2: Vérifier**

Run: `flutter analyze lib/pointage/photo_service.dart`
Expected: pas d'erreur.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/pointage/photo_service.dart
git commit -m "feat(mobile): service de capture photo"
```

---

### Task 1.5: Dépôt de pointage (écrit Firestore + enqueue photo, TDD)

**Files:**
- Create: `mobile/lib/pointage/punch_repository.dart`
- Test: `mobile/test/punch_repository_test.dart`

- [ ] **Step 1: Écrire le test (avec fakes)**

`mobile/test/punch_repository_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/models/punch.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/pointage/punch_repository.dart';

void main() {
  test('createPunch écrit le doc Firestore ET enqueue la photo', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    final repo = PunchRepository(fs, outbox);

    final id = await repo.createPunch(
      userId: 'u1', kind: PunchKind.checkIn,
      lat: 4.0, lng: 9.0, accuracy: 10, siteId: 's1', photoPath: '/tmp/a.jpg',
      now: DateTime.utc(2026, 6, 5, 8),
    );

    final doc = await fs.collection('punches').doc(id).get();
    expect(doc.exists, true);
    expect(doc.data()!['userId'], 'u1');
    expect(doc.data()!['photoStatus'], 'pending');

    final pending = await outbox.pending();
    expect(pending.single.punchId, id);
    expect(pending.single.localPath, '/tmp/a.jpg');
    await outbox.close();
  });
}
```

Ajouter `fake_cloud_firestore: ^3.0.0` aux `dev_dependencies` puis `flutter pub get`.

- [ ] **Step 2: Lancer → échec**

Run: `cd mobile && flutter test test/punch_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`mobile/lib/pointage/punch_repository.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/punch.dart';
import '../outbox/outbox_db.dart';

class PunchRepository {
  PunchRepository(this._fs, this._outbox);
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;

  Future<String> createPunch({
    required String userId,
    required PunchKind kind,
    required double lat,
    required double lng,
    required double accuracy,
    required String? siteId,
    required String photoPath,
    DateTime? now,
  }) async {
    final ref = _fs.collection('punches').doc();
    final punch = Punch(
      id: ref.id, userId: userId, kind: kind,
      clientTimestamp: (now ?? DateTime.now()).toUtc(),
      lat: lat, lng: lng, accuracy: accuracy, siteId: siteId,
      photoStatus: PhotoStatus.pending,
    );
    // set() ne bloque pas hors ligne : Firestore met en cache et synchronise plus tard.
    ref.set(punch.toFirestore());
    await _outbox.enqueue(ref.id, photoPath);
    return ref.id;
  }
}
```

- [ ] **Step 4: Lancer → succès**

Run: `flutter test test/punch_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/pointage/punch_repository.dart mobile/test/punch_repository_test.dart mobile/pubspec.yaml
git commit -m "feat(mobile): depot de pointage (Firestore + enqueue photo)"
```

---

### Task 1.6: Uploader d'outbox (upload Storage + patch doc, TDD)

**Files:**
- Create: `mobile/lib/outbox/outbox_uploader.dart`
- Test: `mobile/test/outbox_uploader_test.dart`

- [ ] **Step 1: Écrire le test avec un uploader de Storage injecté (fake)**

`mobile/test/outbox_uploader_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pointage/outbox/outbox_db.dart';
import 'package:pointage/outbox/outbox_uploader.dart';

void main() {
  test('drainOnce upload chaque photo et patche le doc en uploaded', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'userId': 'u1', 'photoStatus': 'pending'});
    await outbox.enqueue('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(
      fs, outbox,
      uploadFn: (punchId, path) async => 'https://storage/$punchId.jpg',
    );

    await uploader.drainOnce();

    final doc = await fs.collection('punches').doc('p1').get();
    expect(doc.data()!['photoStatus'], 'uploaded');
    expect(doc.data()!['photoUrl'], 'https://storage/p1.jpg');
    expect(await outbox.count(), 0);
    await outbox.close();
  });

  test('un upload qui échoue bumpAttempts et garde l\'élément', () async {
    final fs = FakeFirebaseFirestore();
    final outbox = OutboxDb.memory();
    await fs.collection('punches').doc('p1').set({'photoStatus': 'pending'});
    await outbox.enqueue('p1', '/tmp/p1.jpg');

    final uploader = OutboxUploader(
      fs, outbox,
      uploadFn: (_, __) async => throw Exception('réseau'),
    );

    await uploader.drainOnce();

    expect(await outbox.count(), 1);
    expect((await outbox.pending()).first.attempts, 1);
    await outbox.close();
  });
}
```

- [ ] **Step 2: Lancer → échec**

Run: `cd mobile && flutter test test/outbox_uploader_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`mobile/lib/outbox/outbox_uploader.dart` :

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'outbox_db.dart';

typedef UploadFn = Future<String> Function(String punchId, String localPath);

class OutboxUploader {
  OutboxUploader(this._fs, this._outbox, {UploadFn? uploadFn})
      : _upload = uploadFn ?? _defaultUpload;
  final FirebaseFirestore _fs;
  final OutboxDb _outbox;
  final UploadFn _upload;

  static Future<String> _defaultUpload(String punchId, String localPath) async {
    final ref = FirebaseStorage.instance.ref('punches/$punchId.jpg');
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }

  /// Tente d'uploader toutes les photos en attente. Sûr à appeler souvent.
  Future<void> drainOnce() async {
    for (final item in await _outbox.pending()) {
      try {
        final url = await _upload(item.punchId, item.localPath);
        await _fs.collection('punches').doc(item.punchId).set(
          {'photoUrl': url, 'photoStatus': 'uploaded'},
          SetOptions(merge: true),
        );
        await _outbox.remove(item.punchId);
      } catch (_) {
        await _outbox.bumpAttempts(item.punchId);
      }
    }
  }
}
```

- [ ] **Step 4: Lancer → succès**

Run: `flutter test test/outbox_uploader_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/outbox/outbox_uploader.dart mobile/test/outbox_uploader_test.dart
git commit -m "feat(mobile): uploader d'outbox (Storage + patch du doc)"
```

---

### Task 1.7: Déclenchement de l'uploader sur retour de connectivité

**Files:**
- Create: `mobile/lib/outbox/sync_controller.dart`
- Test: `mobile/test/sync_controller_test.dart`

- [ ] **Step 1: Écrire le test**

`mobile/test/sync_controller_test.dart` :

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/outbox/sync_controller.dart';

void main() {
  test('un événement "online" déclenche drainOnce', () async {
    var drains = 0;
    final controller = StreamController<bool>();
    final sync = SyncController(
      onlineStream: controller.stream,
      drain: () async => drains++,
    );
    sync.start();
    controller.add(true);   // online
    await Future<void>.delayed(Duration.zero);
    controller.add(false);  // offline → pas de drain
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1);
    await controller.close();
    sync.dispose();
  });
}
```

- [ ] **Step 2: Lancer → échec**

Run: `cd mobile && flutter test test/sync_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`mobile/lib/outbox/sync_controller.dart` :

```dart
import 'dart:async';

class SyncController {
  SyncController({required Stream<bool> onlineStream, required Future<void> Function() drain})
      : _onlineStream = onlineStream, _drain = drain;
  final Stream<bool> _onlineStream;
  final Future<void> Function() _drain;
  StreamSubscription<bool>? _sub;

  void start() {
    _sub = _onlineStream.listen((online) {
      if (online) _drain();
    });
  }

  void dispose() => _sub?.cancel();
}
```

> À l'assemblage (`main.dart`), brancher `onlineStream` sur `connectivity_plus` :
> `Connectivity().onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none))`.

- [ ] **Step 4: Lancer → succès**

Run: `flutter test test/sync_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/outbox/sync_controller.dart mobile/test/sync_controller_test.dart
git commit -m "feat(mobile): declenchement de la synchro sur retour de connexion"
```

---

### Task 1.8: Écran de pointage + badge « non synchronisés »

**Files:**
- Create: `mobile/lib/widgets/sync_badge.dart`, `mobile/lib/pointage/pointage_screen.dart`
- Test: `mobile/test/pointage_screen_test.dart`

- [ ] **Step 1: Badge de synchro**

`mobile/lib/widgets/sync_badge.dart` :

```dart
import 'package:flutter/material.dart';

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) {
      return const Chip(avatar: Icon(Icons.cloud_done, size: 18), label: Text('À jour'));
    }
    return Chip(
      avatar: const Icon(Icons.cloud_upload, size: 18),
      label: Text('$pendingCount non synchronisé(s)'),
    );
  }
}
```

- [ ] **Step 2: Écran de pointage (gating GPS+photo obligatoires)**

`mobile/lib/pointage/pointage_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../models/punch.dart';
import '../pointage/geo_service.dart';
import '../pointage/photo_service.dart';
import '../pointage/punch_repository.dart';
import '../widgets/sync_badge.dart';

class PointageScreen extends StatefulWidget {
  const PointageScreen({
    super.key, required this.userId, required this.geo, required this.photo,
    required this.repo, required this.pendingCount,
  });
  final String userId;
  final GeoService geo;
  final PhotoService photo;
  final PunchRepository repo;
  final int pendingCount;

  @override
  State<PointageScreen> createState() => _PointageScreenState();
}

class _PointageScreenState extends State<PointageScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _punch(PunchKind kind) async {
    setState(() { _busy = true; _message = null; });
    try {
      final fix = await widget.geo.currentFix();       // bloque si GPS refusé
      final photoPath = await widget.photo.capture();  // bloque si pas de photo
      await widget.repo.createPunch(
        userId: widget.userId, kind: kind,
        lat: fix.lat, lng: fix.lng, accuracy: fix.accuracy,
        siteId: null, photoPath: photoPath,
      );
      setState(() => _message = 'Pointage enregistré ✓');
    } on GeoDenied {
      setState(() => _message = 'Activez la localisation pour pointer.');
    } on PhotoCancelled {
      setState(() => _message = 'Une photo est obligatoire pour pointer.');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pointage'),
        actions: [Padding(padding: const EdgeInsets.all(8), child: SyncBadge(pendingCount: widget.pendingCount))],
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _punch(PunchKind.checkIn),
            icon: const Icon(Icons.login), label: const Text('Arrivée'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _punch(PunchKind.checkOut),
            icon: const Icon(Icons.logout), label: const Text('Départ'),
          ),
          const SizedBox(height: 24),
          if (_busy) const CircularProgressIndicator(),
          if (_message != null) Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 3: Test de widget (badge)**

`mobile/test/pointage_screen_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/widgets/sync_badge.dart';

void main() {
  testWidgets('SyncBadge affiche le nombre en attente', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SyncBadge(pendingCount: 3))));
    expect(find.text('3 non synchronisé(s)'), findsOneWidget);
  });

  testWidgets('SyncBadge affiche "À jour" quand 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SyncBadge(pendingCount: 0))));
    expect(find.text('À jour'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Lancer → succès**

Run: `cd mobile && flutter test test/pointage_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/sync_badge.dart mobile/lib/pointage/pointage_screen.dart mobile/test/pointage_screen_test.dart
git commit -m "feat(mobile): ecran de pointage + badge de synchro"
```

---

### Task 1.9: Assemblage `main.dart` (Riverpod + wiring)

**Files:**
- Modify: `mobile/lib/main.dart`

- [ ] **Step 1: Câbler l'application**

`mobile/lib/main.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/firebase_bootstrap.dart';
import 'outbox/outbox_db.dart';
import 'outbox/outbox_uploader.dart';
import 'outbox/sync_controller.dart';
import 'pointage/geo_service.dart';
import 'pointage/photo_service.dart';
import 'pointage/punch_repository.dart';
import 'pointage/pointage_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();
  final fs = FirebaseFirestore.instance;
  fs.settings = const Settings(persistenceEnabled: true); // cache offline
  final outbox = OutboxDb.open();
  final uploader = OutboxUploader(fs, outbox);
  final sync = SyncController(
    onlineStream: Connectivity().onConnectivityChanged
        .map((r) => !r.contains(ConnectivityResult.none)),
    drain: uploader.drainOnce,
  )..start();

  runApp(ProviderScope(child: PointageApp(
    outbox: outbox, repo: PunchRepository(fs, outbox),
  )));
}

class PointageApp extends StatelessWidget {
  const PointageApp({super.key, required this.outbox, required this.repo});
  final OutboxDb outbox;
  final PunchRepository repo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cameroon Innovation',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: StreamBuilder<int>(
        stream: outbox.pendingCountStream(),
        initialData: 0,
        builder: (context, snap) => PointageScreen(
          userId: 'TODO-from-auth', // remplacé par l'uid Firebase une fois 0.9 intégré
          geo: GeoService(), photo: PhotoService(), repo: repo,
          pendingCount: snap.data ?? 0,
        ),
      ),
    );
  }
}
```

Ajouter à `OutboxDb` une factory disque + un stream de comptage :

```dart
// dans outbox_db.dart
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/native.dart';
import 'dart:io';

// dans la classe OutboxDb :
factory OutboxDb.open() {
  return OutboxDb(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase(File(p.join(dir.path, 'outbox.sqlite')));
  }));
}

Stream<int> pendingCountStream() =>
    select(pendingPhotos).watch().map((rows) => rows.length);
```

> Le `userId: 'TODO-from-auth'` est branché sur `FirebaseAuth.instance.currentUser!.uid` une fois l'écran d'auth (Task 0.9) intégré au routage. Ajouter un `StreamBuilder` sur `FirebaseAuth.instance.authStateChanges()` qui montre l'écran de connexion Clerk si non connecté, sinon `PointageScreen` avec l'uid réel.

- [ ] **Step 2: Vérifier**

Run: `cd mobile && flutter analyze`
Expected: pas d'erreur (warnings infos tolérés).

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/main.dart mobile/lib/outbox/outbox_db.dart
git commit -m "feat(mobile): assemblage app (cache offline + synchro + pointage)"
```

---

### Task 1.10: Backoffice — calcul des heures (pairing in/out, TDD)

**Files:**
- Create: `web/lib/hours.ts`
- Test: `web/__tests__/hours.test.ts`
- Create: `web/jest.config.js`

- [ ] **Step 1: `web/jest.config.js`**

```js
module.exports = { preset: "ts-jest", testEnvironment: "node", testMatch: ["**/__tests__/**/*.test.ts"] };
```

- [ ] **Step 2: Écrire le test qui échoue**

`web/__tests__/hours.test.ts` :

```ts
import { computeWorkedMinutes, PunchLite } from "@/lib/hours";

const t = (h: number, m = 0) => new Date(Date.UTC(2026, 5, 5, h, m));

describe("computeWorkedMinutes", () => {
  it("apparie in/out et somme les durées", () => {
    const punches: PunchLite[] = [
      { kind: "in", at: t(8) }, { kind: "out", at: t(12) },
      { kind: "in", at: t(13) }, { kind: "out", at: t(17) },
    ];
    expect(computeWorkedMinutes(punches).minutes).toBe(8 * 60);
    expect(computeWorkedMinutes(punches).anomalies).toHaveLength(0);
  });

  it("signale un 'in' sans 'out'", () => {
    const punches: PunchLite[] = [{ kind: "in", at: t(8) }];
    const r = computeWorkedMinutes(punches);
    expect(r.minutes).toBe(0);
    expect(r.anomalies).toContain("in sans out");
  });

  it("signale un 'out' sans 'in' préalable", () => {
    const punches: PunchLite[] = [{ kind: "out", at: t(17) }];
    const r = computeWorkedMinutes(punches);
    expect(r.anomalies).toContain("out sans in");
  });
});
```

- [ ] **Step 3: Lancer → échec**

Run: `cd web && npx jest hours`
Expected: FAIL.

- [ ] **Step 4: Implémenter**

`web/lib/hours.ts` :

```ts
export interface PunchLite { kind: "in" | "out"; at: Date; }
export interface HoursResult { minutes: number; anomalies: string[]; }

export function computeWorkedMinutes(punches: PunchLite[]): HoursResult {
  const sorted = [...punches].sort((a, b) => a.at.getTime() - b.at.getTime());
  let minutes = 0;
  const anomalies: string[] = [];
  let openIn: Date | null = null;
  for (const p of sorted) {
    if (p.kind === "in") {
      if (openIn) anomalies.push("in sans out");
      openIn = p.at;
    } else {
      if (!openIn) { anomalies.push("out sans in"); continue; }
      minutes += (p.at.getTime() - openIn.getTime()) / 60000;
      openIn = null;
    }
  }
  if (openIn) anomalies.push("in sans out");
  return { minutes: Math.round(minutes), anomalies };
}
```

- [ ] **Step 5: Lancer → succès**

Run: `npx jest hours`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add web/lib/hours.ts web/__tests__/hours.test.ts web/jest.config.js
git commit -m "feat(web): calcul des heures travaillees (pairing in/out)"
```

---

### Task 1.11: Backoffice — détection hors-rayon (TDD)

**Files:**
- Create: `web/lib/geo.ts`
- Test: `web/__tests__/geo.test.ts`

- [ ] **Step 1: Écrire le test**

`web/__tests__/geo.test.ts` :

```ts
import { distanceMeters, isOutsideSite } from "@/lib/geo";

describe("geo", () => {
  it("distance ~0 pour le même point", () => {
    expect(distanceMeters(4.05, 9.70, 4.05, 9.70)).toBeLessThan(1);
  });
  it("détecte un pointage hors rayon", () => {
    // ~1.1 km au nord => hors d'un rayon de 200 m
    expect(isOutsideSite({ lat: 4.06, lng: 9.70 }, { lat: 4.05, lng: 9.70, radiusMeters: 200 })).toBe(true);
  });
  it("accepte un pointage dans le rayon", () => {
    expect(isOutsideSite({ lat: 4.0501, lng: 9.7001 }, { lat: 4.05, lng: 9.70, radiusMeters: 200 })).toBe(false);
  });
});
```

- [ ] **Step 2: Lancer → échec**

Run: `cd web && npx jest geo`
Expected: FAIL.

- [ ] **Step 3: Implémenter (Haversine)**

`web/lib/geo.ts` :

```ts
export interface LatLng { lat: number; lng: number; }
export interface SiteGeo extends LatLng { radiusMeters: number; }

export function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function isOutsideSite(punch: LatLng, site: SiteGeo): boolean {
  return distanceMeters(punch.lat, punch.lng, site.lat, site.lng) > site.radiusMeters;
}
```

- [ ] **Step 4: Lancer → succès**

Run: `npx jest geo`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add web/lib/geo.ts web/__tests__/geo.test.ts
git commit -m "feat(web): detection des pointages hors-rayon (Haversine)"
```

---

### Task 1.12: Backoffice — page « Présence du jour »

**Files:**
- Create: `web/app/(dashboard)/presence/page.tsx`

- [ ] **Step 1: Implémenter la page serveur**

`web/app/(dashboard)/presence/page.tsx` :

```tsx
import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { db } from "@/lib/firebaseAdmin";
import { computeWorkedMinutes, PunchLite } from "@/lib/hours";

export const dynamic = "force-dynamic";

export default async function PresencePage() {
  const { userId } = await auth();
  if (!userId) redirect("/");

  const start = new Date(); start.setUTCHours(0, 0, 0, 0);
  const snap = await db()
    .collection("punches")
    .where("clientTimestamp", ">=", start)
    .get();

  const byUser = new Map<string, PunchLite[]>();
  for (const d of snap.docs) {
    const data = d.data();
    const list = byUser.get(data.userId) ?? [];
    list.push({ kind: data.kind, at: data.clientTimestamp.toDate() });
    byUser.set(data.userId, list);
  }

  const rows = [...byUser.entries()].map(([uid, punches]) => {
    const { minutes, anomalies } = computeWorkedMinutes(punches);
    return { uid, hours: (minutes / 60).toFixed(2), anomalies };
  });

  return (
    <div style={{ padding: 24 }}>
      <h1>Présence du jour</h1>
      <table cellPadding={8} style={{ borderCollapse: "collapse" }}>
        <thead><tr><th>Technicien</th><th>Heures</th><th>Anomalies</th></tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.uid} style={{ borderTop: "1px solid #ddd" }}>
              <td>{r.uid}</td>
              <td>{r.hours}</td>
              <td style={{ color: r.anomalies.length ? "crimson" : "green" }}>
                {r.anomalies.length ? r.anomalies.join(", ") : "—"}
              </td>
            </tr>
          ))}
          {rows.length === 0 && <tr><td colSpan={3}>Aucun pointage aujourd'hui.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Vérifier le build**

Run: `cd web && npm run build`
Expected: build OK (page compilée).

- [ ] **Step 3: Vérification d'intégration (émulateur)**

Semer 2 pointages dans l'émulateur Firestore (UI ou script), lancer `npm run dev`, ouvrir `/presence` connecté via Clerk.
Expected: le tableau affiche les heures + colonne anomalies.

- [ ] **Step 4: Commit**

```bash
git add "web/app/(dashboard)/presence/page.tsx"
git commit -m "feat(web): page presence du jour (heures + anomalies)"
```

---

**🔁 CHECKPOINT PHASE 1 :** Un technicien peut pointer (GPS+photo obligatoires) **hors ligne**, les pointages remontent dès le retour réseau (doc d'abord, photo via outbox), et la direction voit présence + heures + anomalies + pointages hors-rayon au backoffice.

---

## Self-Review (couverture spec → tâches)

| Exigence spec | Tâche(s) |
|---|---|
| 3 briques (mobile/web/firebase) | 0.1, 0.7, 0.8 |
| Pont d'auth Clerk↔Firebase + rôle en claim | 0.4, 0.5, 0.9 |
| Règles de sécurité par rôle | 0.6 |
| Modèle Firestore (users/sites/punches) | 0.5 (users), 1.1 (site/punch) |
| Pointage GPS + photo obligatoires | 1.3, 1.4, 1.8 |
| Offline-first (doc en cache + outbox photo) | 1.2, 1.5, 1.6, 1.9 |
| Synchro au retour réseau | 1.7, 1.9 |
| Indicateur « non synchronisés » | 1.8 |
| Calcul des heures + anomalie in/out | 1.10, 1.12 |
| Détection hors-rayon | 1.11, (affichage 1.12 — étendre avec geo si site assigné) |
| Anti-triche double horodatage | 1.1 (client+server timestamp) |

**Hors périmètre Phases 0+1 (planifiés plus tard) :** tâches/rapports (Phase 2), notifications FCM (Phase 2), tableau des tâches & stats & alertes retard (Phase 3), durcissement & publication (Phase 4).

**Note :** la page présence (1.12) affiche les anomalies in/out ; le rattachement d'un pointage à un site assigné pour activer `isOutsideSite` dépend de la notion d'affectation site→technicien, introduite avec les tâches (Phase 2). En Phase 1, `siteId` peut rester nul et le hors-rayon est calculé dès qu'un site est renseigné.
