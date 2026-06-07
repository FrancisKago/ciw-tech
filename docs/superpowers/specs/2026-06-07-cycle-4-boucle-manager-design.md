# Cycle #4 — Boucle manager : validation des tâches (design)

**Date :** 2026-06-07
**Statut :** design approuvé, à planifier
**Précède :** Phase 3 (suivi backoffice, lecture seule). Ce cycle ouvre la **première
écriture** du backoffice et durcit les règles en conséquence.

## Objectif

Fermer la boucle de gestion des tâches : un manager, depuis le backoffice, **revoit le
rapport** d'une tâche terminée et la **valide** (`done → approved`). Deux notifications
push relient les deux bouts : le manager est prévenu quand un rapport est soumis, le
technicien est prévenu quand sa tâche est validée.

## Décisions de périmètre (tranchées au brainstorming)

- **Action manager = validation uniquement** (`done → approved`). Pas de rejet/renvoi,
  pas de réassignation, pas de contrôle de statut libre. (YAGNI ; reportable.)
- **Deux push FCM** : technicien→manager à la soumission du rapport ; manager→technicien
  à la validation.
- **Durcissement des règles Firestore** : un client assigné ne peut plus poser n'importe
  quel `status` ; `approved` devient réservé au manager.
- **Revue du rapport via une vue détail de tâche** dédiée (pas de carte dépliable, pas de
  validation à l'aveugle).

## Contexte technique établi (exploration)

- **Le backoffice web écrit via Firebase Admin SDK côté serveur**
  (`web/src/lib/firebaseAdmin.ts`) → il **contourne les règles Firestore**. Donc « ouvrir
  l'écriture backoffice » ne nécessite aucun changement de règles pour fonctionner ; la
  revue des règles sert au **durcissement du client mobile**.
- Le statut `approved` est **déjà anticipé** côté web (`board.ts` : `isLate` et
  `groupByStatus` le traitent comme `done`). L'enum mobile `TaskStatus` ne le connaît pas.
- `report.photoUrls` contient des **URLs de téléchargement Firebase avec token**
  (`getDownloadURL()` dans `mobile/lib/outbox/outbox_uploader.dart:25`) → directement
  affichables dans un `<img>`, **aucune signature Admin SDK nécessaire** côté web.
- Le manager utilise aussi l'app mobile (création de tâches) → ses `fcmTokens` sont déjà
  enregistrés par `fcm_service.dart`, donc le push technicien→manager a une cible.
- Pattern Functions existant à imiter : `onTaskAssigned.ts` (helpers purs testés jest +
  `splitInvalidTokens` pour purger les tokens morts).

## Modèle de données

`tasks/{taskId}` gagne deux champs, posés **uniquement à la validation** :

| Champ        | Type              | Sens                                  |
|--------------|-------------------|---------------------------------------|
| `approvedBy` | string (uid Clerk)| manager ayant validé                  |
| `approvedAt` | Timestamp         | `serverTimestamp()` à la validation   |

Le statut `approved` est ajouté à l'enum mobile **en lecture seule** (affichage
« validé »). Le technicien ne l'émet jamais.

## Architecture

### Cloud Functions — `firebase/functions/src/tasks/onTaskUpdated.ts`

Un **unique** trigger `onDocumentUpdated('tasks/{taskId}')`. Cohérent avec le pattern
`onTaskAssigned` (une fonction, helpers purs testables).

Routeur pur `routeStatusChange(before, after)` :

- `before.status !== 'done' && after.status === 'done'`
  → push au **`createdBy`** (manager) : « Tâche _{title}_ terminée, à valider ».
- `before.status !== 'approved' && after.status === 'approved'`
  → push à l'**`assigneeId`** (technicien) : « Ta tâche _{title}_ a été validée ✓ ».

Pour chaque cible : lecture `users/{uid}.fcmTokens`, `sendEachForMulticast`, puis purge des
tokens invalides via `splitInvalidTokens` (réutilisé). Builders de message dédiés
(`buildReportSubmittedMessage`, `buildApprovedMessage`). Exporté dans `index.ts`.

### Web — vue détail + validation

- **Route `(dashboard)/board/[taskId]/page.tsx`** (Server Component) :
  - Charge la tâche + `loadDirectory`.
  - Entête : titre, technicien (nom résolu), site (nom résolu), échéance, statut.
  - **Rapport** : texte, minutes passées, vignettes photos (`report.photoUrls` directes),
    date de soumission (`report.submittedAt`). Cas « pas de rapport » géré proprement.
  - Si `status === 'done'` → `<form action={approveTask}>` (taskId caché) + bouton
    **Valider**.
  - Si `status === 'approved'` → bandeau « Validé par _{nom}_ le _{date}_ », pas de bouton.

- **Server Action `web/src/lib/actions/approveTask.ts`** :
  - `auth()` (Clerk) → rejette si rôle ∉ {manager, admin} (re-vérification serveur ; on ne
    fait pas confiance à l'UI role-gatée).
  - **Transaction Admin SDK** : approuve **seulement si le statut courant est `done`**
    (garde anti-double-validation / anti-course). Pose `status='approved'`, `approvedBy`,
    `approvedAt`, `updatedAt`.
  - `revalidatePath('/board')` + la route détail.
  - Garde pure extraite (`canApprove({ role, currentStatus })`) pour test unitaire jest.

- **Board (`board/page.tsx`)** : les cartes deviennent des `<Link>` vers le détail. Les
  cartes `done` portent un liseré « à valider » ; les `approved` un badge vert « ✓ validé »
  (distinction visuelle au sein de la colonne « Terminé »).

- **`web/src/lib/tasks.ts`** : `mapTaskDoc` étendu pour porter le détail rapport (texte,
  minutes, photoUrls, photoCount, submittedAt) + `createdBy`, `approvedBy`, `approvedAt`.

### Règles Firestore (durcissement)

Dans `match /tasks/{taskId}`, l'update de l'assigné est restreint : en plus de la
limitation de champs existante (`status`/`report`/`updatedAt`), le nouveau `status` doit
appartenir à `{in_progress, done}`. `approved` devient inatteignable par un client assigné
→ réservé au manager (Admin SDK backoffice). Le manager conserve son update large.

Nouveau helper :

```
function assigneeStatusAllowed() {
  return request.resource.data.status in ['in_progress', 'done'];
}
```

intégré à la branche assigné de `allow update`.

### Mobile

- `TaskStatus.approved` ajouté à l'enum, mappé en lecture (`fromWire('approved')`), affiché
  « validé ». **Aucun nouvel émetteur** : le technicien ne pose jamais `approved`.

## Stratégie de test

- **Functions (jest)** : table de routage `routeStatusChange` (chaque transition pertinente
  + non-transitions) ; builders de message.
- **Web (jest)** : garde pure `canApprove` (rôle + `status === 'done'`) ; mapping du détail
  rapport par `mapTaskDoc`.
- **Règles (émulateur Firestore — lancé par l'utilisateur dans son terminal)** : l'assigné
  ne peut pas poser `approved` (deny) ; l'assigné peut poser `in_progress`/`done` (allow) ;
  le manager peut approuver (allow). Commande :
  `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`.
- **Mobile** : `flutter analyze` + `flutter test` (incl. `fromWire('approved')`).
- **Web global** : `npx jest`, `npx tsc --noEmit`, `npx eslint .`, `npx next build`.

## Hors périmètre (YAGNI)

Rejet/renvoi au technicien, réassignation, contrôle de statut libre, commentaire de
validation, historique d'audit des transitions. Reportables à un cycle ultérieur si le
besoin se confirme.

## Reste à faire côté utilisateur après livraison

- Déployer `firestore:rules` + `functions` (`onTaskUpdated`) :
  `cd firebase && firebase deploy --only firestore:rules,functions`.
- Lancer les tests de règles via l'émulateur (poste utilisateur).
- Déployer le backoffice sur Vercel (dette ops déjà en cours).
- Valider la boucle de bout en bout sur appareil : technicien clôture → manager reçoit le
  push → ouvre le détail au backoffice → Valider → technicien reçoit le push de validation.

## Notes d'implémentation

- `web/AGENTS.md` : « This is NOT the Next.js you know » — lire les guides dans
  `node_modules/next/dist/docs/` avant d'écrire le code (Server Actions, `revalidatePath`,
  routes dynamiques) plutôt que de se fier à la mémoire.
- Mettre à jour le schéma `tasks` dans `CLAUDE.md` (champs `approvedBy`/`approvedAt`,
  statut `approved`).
