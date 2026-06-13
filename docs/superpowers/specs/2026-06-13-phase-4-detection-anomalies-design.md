# Design — Phase 4 (cycle) : Détection d'anomalies de pointage

**Date :** 2026-06-13
**Statut :** spec validée (brainstorming), prête pour le plan d'implémentation.
**Périmètre :** premier chantier de la Phase 4 (durcissement). Les autres chantiers (App Check,
chemins Storage par utilisateur, publication Play Store) restent indépendants et feront chacun
l'objet de leur propre cycle spec → plan → exécution.

## Objectif
Permettre à la direction de repérer au backoffice les **pointages suspects** : technicien hors du
rayon du site, GPS trop imprécis, photo jamais remontée, pointage sans site, doublons rapprochés,
horloge d'appareil trafiquée. Le contrôle d'intégrité central (le pointage est-il bien
géographiquement *sur le site* ?) est aujourd'hui **absent** alors que GPS + photo sont la raison
d'être du pointage.

## Principe d'architecture
Librairie de détection **pure et testée**, + calcul **au rendu** dans une nouvelle page backoffice
**Alertes**. **Aucun changement** de règles Firestore, de Cloud Function, ni de l'app mobile.
Lecture seule, dans la lignée de la Phase 3.

Justification : les *entrées* de chaque règle (geo, accuracy, siteId, clientTimestamp,
serverTimestamp, photoStatus) sont déjà stockées **immuablement** sur chaque doc `punches`.
Recalculer le drapeau d'anomalie au rendu est donc **aussi fiable** que de le stocker — stocker le
drapeau n'apporterait de l'intégrité supplémentaire à rien. Le seul gain d'une approche
server-side (Cloud Function) serait le **push temps réel** au manager et l'affichage côté mobile,
explicitement **hors périmètre** de ce cycle (différable si le besoin émerge).

## Composants

### 1. `web/src/lib/anomalies.ts` — détection pure (cœur du cycle)
Module sans effet de bord, testable en env node.

Types :
- `AnomalyType = 'hors-rayon' | 'gps-imprecis' | 'photo-manquante' | 'sans-site' | 'doublon' | 'horloge'`
- `AnomalySeverity = 'alerte' | 'info'`
- `Anomaly { type: AnomalyType; severity: AnomalySeverity; label: string }`
- `PunchForAnomaly { id; userId; kind: 'in' | 'out'; clientTimestamp: Date; serverTimestamp: Date | null; geo: { lat; lng; accuracy } | null; siteId: string | null; photoStatus: 'pending' | 'uploaded' }`
- `SiteGeo { geo: { lat; lng } | null; radiusMeters: number | null }` (fourni via l'annuaire)
- `AnomalyThresholds` (config, valeurs par défaut ci-dessous) — passable pour faciliter les tests.

Fonctions :
- `haversineMeters(a: {lat;lng}, b: {lat;lng}): number` — distance grand-cercle en mètres.
- `detectAnomalies(punches: PunchForAnomaly[], sites: Map<string, SiteGeo>, now: Date, opts?: Partial<AnomalyThresholds>): Map<string, Anomaly[]>`
  — prend l'**ensemble** des pointages de la période (le doublon est inter-pointages) et renvoie,
  par `punchId`, la liste de ses anomalies (vide si aucune).

### 2. `web/src/lib/directory.ts` — petite extension rétro-compatible
`Directory.sites` porte désormais `{ name; geo: {lat;lng} | null; radiusMeters: number | null }`
(au lieu de `{ name }`). `loadDirectory` lit `geo` + `radiusMeters` des docs `sites`. Les
consommateurs actuels (Présence, Stats, Board) ne lisent que `.name` → aucun impact.
`displaySite` inchangé.

### 3. `web/src/app/(dashboard)/alertes/page.tsx` — page Alertes (Server Component)
- `export const dynamic = "force-dynamic"` (comme Présence).
- Charge en parallèle : `db().collection('punches').where('clientTimestamp','>=', start).get()`
  et `loadDirectory(db)`.
- Mappe les docs en `PunchForAnomaly[]` (geo/serverTimestamp défensifs : `null` si absents).
- Construit `Map<siteId, SiteGeo>` depuis l'annuaire ; appelle `detectAnomalies(...)`.
- **Ne garde que les pointages ayant ≥ 1 anomalie.**
- Applique les filtres `searchParams` : `period` (via `parsePeriod`), `site`, `tech`.
- Rend un tableau trié **alertes (🔴) d'abord** : Technicien (`displayUser`), Site (`displaySite`),
  Type de pointage (in/out), Heure (`clientTimestamp`), Badges d'anomalie (couleur par sévérité).
- État vide : « Aucune anomalie sur la période. »

### 4. `web/src/components/Sidebar.tsx` — navigation
Ajout d'une entrée « Alertes » (`/alertes`), même style/lien-actif que les entrées existantes.

## Règles de détection (par pointage)

| Type | Règle | Sévérité | Seuil par défaut |
|---|---|---|---|
| **hors-rayon** | site connu (geo + radiusMeters) **et** GPS assez précis (`accuracy ≤ seuil gps`) **et** `haversine(punch.geo, site.geo) − accuracy > radiusMeters` (règle **tolérante** : dehors même en tenant compte de l'erreur GPS) | 🔴 alerte | — |
| **gps-imprécis** | `geo.accuracy > 100` (m) | 🟠 info | 100 m |
| **photo-manquante** | `photoStatus ≠ 'uploaded'` **et** `now − clientTimestamp > 24 h` | 🟠 info | 24 h |
| **sans-site** | `siteId == null` | 🔴 alerte | — |
| **doublon** | il existe un autre pointage du **même** `userId`, **même** `kind`, dont l'écart `|clientTimestamp|` < 5 min | 🟠 info | 5 min |
| **horloge** | `serverTimestamp` connu **et** `clientTimestamp − serverTimestamp > 10 min` (horloge appareil **en avance** ; asymétrique : un `clientTimestamp` *antérieur* au `serverTimestamp` est le retard de synchro offline normal, **non** signalé) | 🔴 alerte | 10 min |

Seuils par défaut regroupés dans `AnomalyThresholds` :
`gpsAccuracyMaxMeters: 100`, `photoGraceHours: 24`, `duplicateWindowMinutes: 5`, `clockAheadMinutes: 10`.

**Interactions volontaires :**
- `hors-rayon` ne se déclenche que si le GPS est assez précis (sinon le cas est couvert par
  `gps-imprécis`) **et** le site connu (sinon `sans-site`). Un même pointage peut cumuler
  `gps-imprécis` + `sans-site`, mais pas `hors-rayon` + `gps-imprécis`.
- Tri d'affichage : un pointage portant au moins une anomalie 🔴 passe avant les pointages
  purement 🟠.

## Flux de données
```
AlertesPage (searchParams: period?, site?, tech?)
  → parsePeriod(period) → {start, end}
  → Promise.all[ punches.where(clientTimestamp >= start).get(), loadDirectory(db) ]
  → map docs → PunchForAnomaly[]   (geo/serverTimestamp → null si absents)
  → sites: Map<siteId, SiteGeo> (depuis l'annuaire)
  → detectAnomalies(punches, sites, now, thresholds) → Map<punchId, Anomaly[]>
  → garder punchId avec anomalies.length > 0
  → filtrer par site/tech (searchParams)
  → trier (alertes d'abord) → tableau
```

## Gestion d'erreurs (défensive, sans inventer de types)
- Pointage sans `geo` (anciens docs) → règles géo (`hors-rayon`, `gps-imprécis`) **sautées**, pas
  de crash.
- `siteId` présent mais site absent de l'annuaire (ou site sans geo/radius) → géofence **sautée**
  (geo de référence indisponible) ; `displaySite` montre l'id brut.
- `serverTimestamp` null (juste après une écriture offline, avant résolution serveur) → règle
  `horloge` **sautée**.

## Tests
- **`web/__tests__/anomalies.test.ts`** (jest, même infra que l'existant) :
  - `haversineMeters` : distance connue (ex. deux points à ~1 km) à tolérance près ; distance 0.
  - `hors-rayon` : juste **dedans** vs juste **dehors** en tenant compte de `accuracy` (tolérance) ;
    non déclenché si GPS imprécis ; non déclenché si site/geo inconnu.
  - `gps-imprécis` : bornes autour de 100 m.
  - `photo-manquante` : `pending` à 23 h 59 (non) vs 24 h 01 (oui) ; `uploaded` jamais signalé.
  - `sans-site` : `siteId == null`.
  - `doublon` : deux `in` à 4 min (oui) / 6 min (non) ; deux `kind` différents (non).
  - `horloge` : `clientTimestamp` en avance > 10 min (oui) ; en retard de plusieurs heures
    = synchro offline (non) ; `serverTimestamp` null (non).
  - Interactions : un pointage imprécis **et** hors-rayon ne remonte que `gps-imprécis`.
- Validation de la page via `next build` (pas d'infra de test composant dans le repo — cohérent
  avec l'approche Phase 3).
- Garde-fous finaux : `npx jest`, `npx tsc --noEmit`, `npx eslint .`, `npx next build`.

## Hors périmètre (YAGNI)
- Pas de changement de règles Firestore, de Cloud Function, ni de mobile.
- Pas de **push** temps réel (différable → approche Cloud Function ultérieure si le besoin émerge).
- Pas d'« acquittement » / résolution d'anomalie : signal **lecture seule**.
- Pas de configuration des seuils en UI (constantes dans le code).
- Pas de fusion des anomalies de séquence in/out existantes (`in sans out` / `out sans in`) :
  elles restent affichées sur la page Présence via `computeWorkedMinutes`.
- Pas d'anomalie « hors-horaire » (aucun modèle d'horaire/shift n'existe ; nécessiterait de
  nouvelles données).

## Conventions
- TDD (test rouge → vert → commit), commits atomiques en français (`feat/test/chore(scope):`).
- Logique pure dans `web/src/lib/`, tests dans `web/__tests__/`, page sous
  `web/src/app/(dashboard)/`, role gate hérité du layout (centralisé).
- Backoffice déployé sur Vercel (auto-deploy sur push `main`).
