# Cycle #5 — Managers = aussi techniciens (design)

**Date :** 2026-06-09
**Statut :** design validé, prêt pour plan d'implémentation.
**Approche retenue :** A (chirurgicale — réutilisation des widgets existants, diff minimal).

## Contexte & problème

La navigation mobile est cloisonnée par rôle (`HomeShell`) :
- **manager/admin** → un seul onglet « Tâches créées » (pas de barre de navigation) ;
- **technicien** → Pointage + Mes tâches.

Or un manager est aussi un technicien de terrain. Il doit pouvoir **pointer** et
**s'auto-assigner des tâches**. C'est la dette produit notée depuis la Phase 3
(cf. `docs/HANDOFF.md`).

## Périmètre

**Dans le périmètre :** manager = technicien (pointer + s'auto-assigner ; onglets cumulés).

**Hors périmètre (cycles ultérieurs) :**
- « Sans site » des stats (pointage sans tâche active → `siteId=null`). Comportement
  préexistant des techniciens, indépendant de ce cycle.
- Séparation des tâches (un manager qui validerait sa propre tâche au backoffice). Noté,
  non bloquant : la validation `done → approved` se fait au backoffice (réservé direction).

## Décisions de conception

1. **Sélecteur d'assigné** : techniciens **+ une entrée « Moi (vous) »** (pas tous les
   utilisateurs). Le manager s'assigne à lui-même, pas aux autres managers.
2. **Push vers soi-même** : garde-fou `assigneeId == createdBy` dans les Cloud Functions.
   Les push « Nouvelle tâche » et « à valider » (qui iraient à soi) sont **supprimés** ;
   le push « validée » est **conservé** (informe le manager-exécutant, quel que soit
   l'approbateur).
3. **Défaut d'assigné** à la création : premier **technicien** s'il en existe, sinon `self`.
   L'auto-assignation reste un choix explicite quand des techniciens existent.

## Conception détaillée

### 1. Modèle de données & règles — aucun changement

- `tasks` possède déjà `assigneeId` + `createdBy`. L'auto-assignation = tâche avec
  `assigneeId == createdBy`. Aucun champ ajouté.
- **Règles Firestore inchangées** (vérifié en lecture, `firebase/firestore.rules`) :
  - `create tasks` : `isManager() && request.resource.data.createdBy == request.auth.uid`,
    **sans contrainte sur `assigneeId`** → auto-assignation autorisée.
  - `create punches` : `isSignedIn() && userId == auth.uid` → pointage manager autorisé.
  - `update tasks` : `isManager() || (assigné && bornes)` → un manager-assigné peut
    `start`/`report` sa propre tâche (couvert par `isManager()`).
- On garde les tests de règles existants verts (15/15) et on ajoute **un test documentaire** :
  un manager crée une tâche `assigneeId == self`, puis la fait passer à `in_progress` puis
  `done`.

### 2. `HomeShell` (`mobile/lib/tasks/home_shell.dart`)

- `isManager` → onglets `[pointageTab, myTasksTab, managerTasksTab]` avec 3
  `NavigationDestination` : **Pointage** (`Icons.access_time`), **Mes tâches**
  (`Icons.checklist`), **Tâches créées** (`Icons.assignment`).
- Technicien : inchangé (Pointage + Mes tâches).
- `IndexedStack` conservé. La branche manager passe de 1 onglet sans barre à 3 onglets
  avec barre de navigation.

### 3. `TaskCreateScreen` (`mobile/lib/tasks/task_create_screen.dart`)

- Nouveau paramètre optionnel `final TechOption? self;`.
- Si `self != null`, la liste d'options d'assignés est **préfixée** d'une entrée
  « Moi (vous) » (id = uid du manager, libellé distinct).
- Défaut d'assigné (`initState`) : `technicians.isNotEmpty ? technicians.first.id : self?.id`.
- `_canSubmit` et état vide : autoriser la soumission dès qu'**au moins une option** existe
  (technicien *ou* soi). Aujourd'hui `_canSubmit` exige `technicians.isNotEmpty` — à
  élargir. L'état vide « Aucun technicien disponible » ne s'affiche que si **aucune** option
  n'existe (ni technicien, ni soi).

### 4. Câblage (`mobile/lib/auth/firebase_auth_gate.dart`)

- `_openCreate` (déclenché uniquement depuis l'onglet manager « Tâches créées ») passe
  `self: (id: uid, name: 'Moi (vous)')` à `TaskCreateScreen`. Aucun check de rôle
  supplémentaire : l'entrée de création est déjà manager-only.
- `HomeShell` reçoit déjà les 3 onglets construits (pointage, mes tâches, tâches créées) ;
  rien à changer côté construction — seul l'affichage évolue (§2).

### 5. Cloud Functions — garde-fou anti-push-perso

- `firebase/functions/src/tasks/onTaskAssigned.ts` : ajouter `createdBy` à l'interface lue ;
  si `assigneeId == createdBy` → **return** avant l'envoi (pas de push « Nouvelle tâche »).
- `firebase/functions/src/tasks/onTaskUpdated.ts` (`routeStatusChange`, fonction pure) :
  le push `report_submitted` (destinataire `createdBy`) est **omis** si
  `after.assigneeId == after.createdBy`. Le push `approved` est **conservé** dans tous les cas.

## Tests (TDD : rouge → vert → commit)

- **Mobile** (`flutter test`) :
  - `home_shell` : un manager affiche les 3 destinations (Pointage, Mes tâches, Tâches
    créées) et peut basculer d'onglet ; technicien inchangé.
  - `task_create` : l'option « Moi (vous) » apparaît quand `self` est fourni ; sa sélection
    produit `assigneeId == uid` au submit ; la soumission est possible même sans aucun
    technicien (self seul).
- **Functions** (`npx jest`) :
  - `onTaskAssigned` : aucun push quand `assigneeId == createdBy` ; push normal sinon.
  - `routeStatusChange` : omet `report_submitted` quand `assigneeId == createdBy`, mais
    émet toujours `approved`.
- **Règles** (émulateur) : test documentaire d'auto-assignation (§1) ; non-régression 15/15.

## Validation finale (hors contexte Claude)

- `cd mobile && flutter analyze && flutter test`.
- `cd firebase/functions && npx jest`.
- Règles : `cd firebase && firebase emulators:exec --only firestore "cd functions && npx jest rules"`.
- Build APK + validation sur tablette SM X115 (terminal utilisateur) : un compte **manager**
  pointe (onglet Pointage), crée une tâche en se choisissant comme assigné (« Moi (vous) »),
  la voit dans « Mes tâches », la démarre et la clôture — **sans recevoir de push pour
  lui-même**.
- Déploiement Functions : `cd firebase && firebase deploy --only functions`.
