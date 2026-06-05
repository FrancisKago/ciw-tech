# Conception — Application de pointage & gestion de tâches (Cameroon Innovation)

**Date :** 2026-06-05
**Statut :** Validé (brainstorming) — prêt pour le plan d'implémentation
**Auteur :** Direction Cameroon Innovation + Claude

---

## 1. Contexte & objectif

Cameroon Innovation est une société de techniciens déployés chaque jour sur des
**sites différents**. La direction veut **contrôler les heures de travail** et
**piloter les tâches** confiées aux techniciens, avec un suivi en ligne.

Le produit comprend :

- une **application mobile Flutter (Android)** pour les techniciens et les managers ;
- un **backoffice web Next.js** réservé à la direction ;
- un **backend Firebase** partagé.

### Contraintes clés (issues du cadrage)

| Sujet | Décision |
|---|---|
| Pointage | Le technicien pointe librement (arrivée/départ) ; les données remontent au serveur (≥ 4×/jour, voir §3). |
| Connectivité | **Souvent hors ligne** → architecture **offline-first**. |
| Preuve de présence | **GPS + photo obligatoires** à chaque pointage. |
| Authentification | **Clerk** (identité, web + mobile). |
| Plateforme mobile | **Android uniquement.** |
| Taille | Petite équipe au départ, **vouée à grandir**. |
| Backoffice | **Direction uniquement** (managers créent les tâches sur mobile). |
| Notifications | **Push (FCM) activées.** |

---

## 2. Architecture générale & authentification

### 2.1 Trois briques déployées

1. **App mobile Flutter (Android)** — techniciens *et* managers ; le rôle vient de
   Clerk. Fonctionne **offline-first**.
2. **Backoffice Next.js (sur Vercel)** — direction uniquement ; lit Firebase côté
   serveur via le **Firebase Admin SDK**.
3. **Projet Firebase (backend partagé)** :
   - **Firestore** — données + synchronisation offline automatique ;
   - **Storage** — photos ;
   - **Cloud Functions** — pont d'auth Clerk, alertes retard (cron), déclenchement des push ;
   - **Cloud Messaging (FCM)** — notifications.
   - **Clerk** — fournisseur d'identité externe.

### 2.2 Authentification (Clerk = source de vérité)

- **Mobile** : connexion via Clerk → l'app obtient le JWT Clerk → appelle une Cloud
  Function `mintFirebaseToken` qui **vérifie le JWT Clerk** et renvoie un **jeton
  Firebase personnalisé** → l'app se connecte à Firebase Auth → les règles de
  sécurité Firestore/Storage s'appuient sur l'`uid` Firebase (= identifiant Clerk).
- **Backoffice** : SDK Clerk Next.js pour la session ; côté serveur, Firebase Admin
  SDK (accès privilégié, pas de pont).
- **Rôles** (`technician` / `manager` / `admin`) : stockés dans Clerk
  (`publicMetadata`), recopiés en *custom claim* dans le jeton Firebase. Les règles
  de sécurité distinguent manager et technicien. **Le pont de jetons est le seul
  composant d'auth sur-mesure.**

### 2.3 Note sur le « 4×/jour »

Firestore synchronise **dès qu'il y a du réseau** (donc souvent plus de 4×/jour).
Le « 4 fois par jour » est traité comme une **garantie minimale de fraîcheur** que
le système dépasse naturellement, et non comme une limite imposée artificiellement.

---

## 3. Modèle de données & flux de pointage

### 3.1 Collections Firestore

- **`users/{userId}`** *(userId = id Clerk)* — `name`, `phone`, `role`, `active`,
  `fcmTokens[]`, `createdAt`.
- **`sites/{siteId}`** — `name`, `address`, `geo {lat, lng}`, `radiusMeters`
  (rayon de tolérance). Sert à vérifier le GPS des pointages.
- **`punches/{punchId}`** *(pointages)* — `userId`, `kind` (`in`/`out`),
  `clientTimestamp` (heure du téléphone), `serverTimestamp` (posé à la synchro),
  `geo {lat, lng, accuracy}`, `photoUrl`, `siteId`, `photoStatus`
  (`pending`/`uploaded`).
- **`tasks/{taskId}`** — voir §4.

### 3.2 Photos & stockage

Images dans Firebase Storage :
`punches/{userId}/{punchId}.jpg`, `tasks/{taskId}/attachments/...`,
`reports/{taskId}/...`.

### 3.3 Outbox photos (la seule vraie ingénierie offline)

Firestore met les **documents** en cache et les synchronise automatiquement, mais
les **uploads Storage ne sont pas mis en file d'attente** hors ligne. On ajoute une
**file locale** (Hive ou Drift) :

1. Le technicien pointe → capture **horodatage + GPS + photo**.
2. L'app écrit le doc `punch` (hors ligne, en cache, `photoStatus: pending`) et
   range le fichier photo dans l'outbox.
3. Au retour du réseau → un *uploader* envoie la photo vers Storage, récupère l'URL
   et met à jour le doc (`photoUrl`, `photoStatus: uploaded`).
4. L'app affiche en permanence « X pointages non synchronisés » tant que l'outbox
   n'est pas vide.

### 3.4 Calcul des heures travaillées

On apparie les pointages `in`/`out` d'un technicien sur une journée → durées
(calcul côté backoffice). Un `in` sans `out` (oubli de pointer le départ) est
**signalé comme anomalie**, jamais ignoré silencieusement.

### 3.5 Anti-triche

- Double horodatage `clientTimestamp` (fiable même offline) vs `serverTimestamp`
  (posé à la synchro) → un écart anormal (horloge trafiquée) est signalé.
- **GPS + photo obligatoires** : sans permission GPS ou sans photo, le pointage est
  **impossible** (message clair invitant à activer la localisation). La précision
  (`accuracy`) est stockée ; un GPS imprécis est signalé.

---

## 4. Tâches, rapports, notifications & backoffice

### 4.1 Modèle `tasks/{taskId}`

`title`, `description`, `siteId`, `assigneeId`, `createdBy`, `priority`
(`low`/`normal`/`high`), `dueAt` (échéance), `status`
(`assigned` → `in_progress` → `done` / `blocked`), `attachments[]`
(pièces jointes du manager), `createdAt`, `updatedAt`, et un objet **`report`**
intégré : `{ text, photos[], resolution (done/partial/blocked), reason?,
declaredMinutes, submittedAt }`.

### 4.2 Flux tâche

- **Manager (mobile)** : crée la tâche (titre, description, site, échéance,
  priorité, pièces jointes) et l'assigne à un technicien → écriture Firestore.
- **Déclencheur** : Cloud Function sur création/assignation → **push FCM** au
  technicien.
- **Technicien (mobile)** : voit ses tâches, ouvre, passe en `in_progress`, puis
  remplit le **rapport** (texte + photos + statut de résolution + temps passé) →
  `done` ou `blocked`. Hors ligne : lecture cache, écriture du rapport en file,
  photos via l'outbox.

### 4.3 Notifications (FCM)

- À l'assignation → push au technicien concerné.
- Cloud Function **planifiée (cron, ~horaire)** → repère les tâches en retard
  (`dueAt < maintenant` et statut non terminé) → push au technicien **et**
  signalement pour la direction.
- Token FCM de chaque appareil enregistré dans `users/{id}.fcmTokens`.

### 4.4 Backoffice (Next.js, direction uniquement)

- **Tableau de bord du jour** : qui a pointé, heures par technicien
  (jour/semaine/mois), état des tâches.
- **Suivi des tâches** : liste/tableau, filtres par technicien / site / statut ;
  tâches en retard mises en évidence.
- **Alertes de retard** : en direct + via le cron.
- **Statistiques par technicien** : heures travaillées, ponctualité (pointages dans
  le rayon du site vs hors zone), tâches terminées / en retard, temps moyen de
  résolution (`declaredMinutes`).
- **YAGNI** : stats **calculées à la volée** au départ (équipe petite). Agrégats
  pré-calculés (Cloud Functions) ajoutés **seulement si** le volume l'exige.

---

## 5. Cas limites & gestion des erreurs

- **Oubli de pointer le départ** → anomalie signalée au backoffice.
- **Permission GPS refusée / précision faible** → pointage bloqué, précision stockée
  et signalée.
- **Échec répété d'upload photo** → réessais avec back-off, photo conservée dans
  l'outbox, compteur « non synchronisés » visible.
- **Horloge trafiquée** → double horodatage, écart signalé.
- **Double pointage** → anti-rebond + idempotence.
- **Expiration du jeton Clerk↔Firebase** → rafraîchissement automatique.
- **Sécurité** → règles Firestore/Storage : un technicien ne peut ni lire/modifier
  les données d'un autre, ni s'auto-promouvoir manager.

---

## 6. Stratégie de tests

- **Flutter** : tests unitaires (calcul des heures, logique outbox), tests de
  widgets (écran de pointage), test d'intégration **offline→online** avec le
  Firebase Local Emulator.
- **Cloud Functions** : tests unitaires + émulateur (pont de jetons, déclencheur
  push, cron des retards).
- **Next.js** : tests de composants + e2e du tableau de bord avec données semées
  dans l'émulateur.
- **Firebase Local Emulator Suite** pour tout tester sans toucher à la production.

---

## 7. Découpage en phases

Chaque phase fera ensuite l'objet de son propre plan d'implémentation détaillé.

- **Phase 0 — Fondations** : projet Firebase, Clerk, squelette app Flutter,
  squelette Next.js, **pont d'auth de bout en bout** (login + rôle sur les deux).
- **Phase 1 — Pointage** *(cœur de valeur)* : capture GPS+photo offline-first,
  outbox + synchro, vue présence/heures au backoffice.
- **Phase 2 — Tâches** : création/assignation (manager mobile),
  réception/exécution/rapport (technicien), **notifications push**.
- **Phase 3 — Suivi backoffice** : tableau des tâches, alertes de retard,
  statistiques par technicien.
- **Phase 4 — Durcissement** : anomalies, cas limites, finitions, publication
  Play Store.

**Prochaine étape :** rédaction du plan d'implémentation des **Phases 0 + 1** en
premier ; le reste suivra phase par phase.

---

## 8. Pile technique (récapitulatif)

| Couche | Technologie |
|---|---|
| Mobile | Flutter (Android) |
| Backoffice | Next.js (App Router) sur Vercel |
| Données | Firebase Firestore (offline-first) |
| Fichiers | Firebase Storage |
| Auth / identité | Clerk (+ pont vers Firebase Auth via Cloud Function) |
| Logique serveur | Firebase Cloud Functions |
| Notifications | Firebase Cloud Messaging (FCM) |
| File offline locale | Hive ou Drift (à arbitrer au plan d'implémentation) |
| Tests | Firebase Local Emulator Suite |
