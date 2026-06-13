# Identité visuelle — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner à l'app (mobile Flutter + backoffice web) l'identité Cameroon Innovation — logo, thème clair bleu nuit/orange, et représentation data-driven des 3 branches (Électricité, Informatique, Plomberie).

**Architecture:** Deux parties. **Partie A** pose les fondations (assets logo SVG, tokens de couleur + thème Flutter & web, placement du logo). **Partie B** rend les branches réelles via un champ `domaine` sur `Task`, un composant puce de branche partagé, et l'affichage sur mobile + web + stats. Aucun changement de règles Firestore.

**Tech Stack:** Flutter (Material 3, Riverpod), Next.js 16 + Tailwind 4, Firestore. Tests : `flutter_test`, `jest`. Spec : `docs/superpowers/specs/2026-06-13-identite-visuelle-design.md`.

**Branche :** `identite-visuelle` (déjà créée, contient la spec). Mobile depuis `mobile/`, web depuis `web/`. Le **build APK et la génération icône/splash ne se lancent PAS dans le contexte Claude** — garde-fous mobile = `flutter analyze` + `flutter test` ; le user lance la génération d'icônes/splash + l'APK.

---

## Tokens de référence (utilisés partout)

| Rôle | Hex |
|---|---|
| Bleu nuit (primary) | `#1A3C5E` · foncé `#13314D` · clair `#2D7D9A` |
| Orange (accent) | `#E67E22` · tint `#FEF0E3` |
| Page / surface | `#F4F6F9` / `#FFFFFF` |
| Texte / secondaire | `#13314D` / `#5F6B78` |

Branches (`bg` / `fg` / icône Tabler · Material) :
| Branche | bg | fg | Tabler | Material icon |
|---|---|---|---|---|
| electricite | `#FBF0D6` | `#854F0B` | `bolt` | `Icons.bolt` |
| informatique | `#E1F0FA` | `#0C447C` | `device-cctv` | `Icons.videocam` |
| plomberie | `#E1F5EE` | `#0F6E56` | `droplet` | `Icons.water_drop` |
| autre | `#F1EFE8` | `#444441` | `tools` | `Icons.build` |

---

# PARTIE A — Marque & thème

## Task A1: Assets logo SVG (marque + lockup)

**Files:**
- Create: `mobile/assets/brand/logo_mark.svg`
- Create: `mobile/assets/brand/logo_lockup.svg`
- Create: `web/public/brand/logo_mark.svg`
- Create: `web/public/brand/logo_lockup.svg`

Le logo a deux formes : **marque** (écusson + monogramme `ci`, pour l'icône et les petites tailles) et **lockup** (marque + circuit orange + wordmark, pour splash/en-têtes). On crée les SVG une fois et on les copie aux deux emplacements.

- [ ] **Step 1: Créer `logo_mark.svg`**

Contenu (écusson bleu nuit, monogramme `ci` blanc, point du `i` orange comme rappel d'accent ; carré 512, fond transparent) — créer `mobile/assets/brand/logo_mark.svg` :

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <rect x="96" y="96" width="320" height="320" rx="72" fill="#1A3C5E"/>
  <path d="M283.3 210.7 A64 64 0 1 0 283.3 301.3" fill="none" stroke="#FFFFFF" stroke-width="30" stroke-linecap="round"/>
  <rect x="296" y="240" width="28" height="96" rx="14" fill="#FFFFFF"/>
  <circle cx="310" cy="212" r="16" fill="#E67E22"/>
</svg>
```

- [ ] **Step 2: Créer `logo_lockup.svg`**

Lockup horizontal (marque à gauche + circuit orange au-dessus + wordmark à droite). Créer `mobile/assets/brand/logo_lockup.svg` :

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 280" width="900" height="280">
  <g>
    <polyline points="150,86 150,52" fill="none" stroke="#E67E22" stroke-width="4" stroke-linecap="round"/>
    <polyline points="150,86 110,62 110,50" fill="none" stroke="#E67E22" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
    <polyline points="150,86 190,62 190,50" fill="none" stroke="#E67E22" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="150" cy="46" r="6" fill="#E67E22"/><circle cx="110" cy="45" r="6" fill="#E67E22"/><circle cx="190" cy="45" r="6" fill="#E67E22"/>
    <rect x="80" y="90" width="140" height="140" rx="32" fill="#1A3C5E"/>
    <path d="M168 124 A30 30 0 1 0 168 166" fill="none" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round"/>
    <rect x="174" y="138" width="13" height="46" rx="6.5" fill="#FFFFFF"/>
    <circle cx="180.5" cy="124" r="7.5" fill="#E67E22"/>
  </g>
  <text x="250" y="148" font-family="Arial, sans-serif" font-size="46" font-weight="400" fill="#1A3C5E">Cameroon</text>
  <text x="250" y="198" font-family="Arial, sans-serif" font-size="46" font-weight="700" fill="#1A3C5E" letter-spacing="2">INNOVATION</text>
</svg>
```

- [ ] **Step 3: Copier les SVG côté web**

```bash
mkdir -p web/public/brand
cp mobile/assets/brand/logo_mark.svg web/public/brand/logo_mark.svg
cp mobile/assets/brand/logo_lockup.svg web/public/brand/logo_lockup.svg
```

- [ ] **Step 4: Aperçu visuel (facultatif mais recommandé)**

Ouvrir les deux SVG dans un navigateur (ou via l'outil de visualisation) pour vérifier le rendu (écusson net, `ci` lisible, wordmark aligné). Ajuster les coordonnées si besoin — c'est un asset, l'aspect prime.

- [ ] **Step 5: Commit**

```bash
git add mobile/assets/brand web/public/brand
git commit -m "feat(brand): assets logo SVG (marque + lockup) Cameroon Innovation"
```

## Task A2: PNG 1024 pour le lanceur

**Files:**
- Create: `mobile/assets/brand/logo_mark_1024.png`

Le lanceur Android a besoin d'un PNG. On rasterise `logo_mark.svg` en 1024×1024.

- [ ] **Step 1: Rasteriser le SVG en PNG 1024**

Essayer, dans l'ordre, un outil disponible :

```bash
# option 1 (ImageMagick)
magick -background none -density 384 mobile/assets/brand/logo_mark.svg -resize 1024x1024 mobile/assets/brand/logo_mark_1024.png
# option 2 (rsvg)
rsvg-convert -w 1024 -h 1024 mobile/assets/brand/logo_mark.svg -o mobile/assets/brand/logo_mark_1024.png
# option 3 (inkscape)
inkscape mobile/assets/brand/logo_mark.svg --export-type=png -w 1024 -h 1024 -o mobile/assets/brand/logo_mark_1024.png
```

Si **aucun** outil n'est disponible : marquer ce point comme **à faire côté user** (exporter le SVG en PNG 1024 transparent) et continuer — le reste du plan n'en dépend pas tant que la génération d'icônes (Task A4) n'est pas lancée par le user.

- [ ] **Step 2: Vérifier**

```bash
python -c "import struct;f=open(r'mobile/assets/brand/logo_mark_1024.png','rb').read();import sys;assert f[:8]==b'\x89PNG\r\n\x1a\n';print('1024 PNG OK',struct.unpack('>II',f[16:24]))"
```
Expected: `1024 PNG OK (1024, 1024)`.

- [ ] **Step 3: Commit**

```bash
git add mobile/assets/brand/logo_mark_1024.png
git commit -m "feat(brand): icône lanceur PNG 1024 dérivée de la marque"
```

## Task A3: Thème Flutter (AppColors + AppTheme)

**Files:**
- Create: `mobile/lib/theme/app_colors.dart`
- Create: `mobile/lib/theme/app_theme.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/app_theme_test.dart`

- [ ] **Step 1: Écrire le test (rouge)**

Créer `mobile/test/app_theme_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/theme/app_colors.dart';
import 'package:pointage/theme/app_theme.dart';

void main() {
  test('AppColors expose les couleurs de marque', () {
    expect(AppColors.bleuNuit, const Color(0xFF1A3C5E));
    expect(AppColors.orange, const Color(0xFFE67E22));
  });
  test('AppTheme.light est clair, primary bleu nuit, secondary orange', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.colorScheme.primary, AppColors.bleuNuit);
    expect(t.colorScheme.secondary, AppColors.orange);
    expect(t.useMaterial3, isTrue);
  });
}
```

- [ ] **Step 2: Lancer le test (échec)**

Run: `cd mobile && flutter test test/app_theme_test.dart`
Expected: FAIL (modules introuvables).

- [ ] **Step 3: Créer `app_colors.dart`**

```dart
import 'package:flutter/material.dart';

/// Couleurs de marque Cameroon Innovation (source unique).
class AppColors {
  AppColors._();
  static const bleuNuit = Color(0xFF1A3C5E);
  static const bleuNuitFonce = Color(0xFF13314D);
  static const bleuClair = Color(0xFF2D7D9A);
  static const orange = Color(0xFFE67E22);
  static const orangeTint = Color(0xFFFEF0E3);
  static const page = Color(0xFFF4F6F9);
  static const texte = Color(0xFF13314D);
  static const texteSecondaire = Color(0xFF5F6B78);
}
```

- [ ] **Step 4: Créer `app_theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Thème clair de l'application (Material 3).
class AppTheme {
  AppTheme._();
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.bleuNuit,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.bleuNuit,
      secondary: AppColors.orange,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.page,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bleuNuit,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Lancer le test (succès)**

Run: `cd mobile && flutter test test/app_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Brancher dans `main.dart`**

Dans `mobile/lib/main.dart`, remplacer :

```dart
final theme = ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);
```

par :

```dart
final theme = AppTheme.light();
```

et ajouter l'import en tête du fichier :

```dart
import 'theme/app_theme.dart';
```

- [ ] **Step 7: Analyse + tests**

Run: `cd mobile && flutter analyze && flutter test`
Expected: « No issues found! » + suite verte (≥ 46 tests : base 44 + 2 thème).

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/theme mobile/lib/main.dart mobile/test/app_theme_test.dart
git commit -m "feat(theme): thème Flutter clair bleu nuit/orange (AppColors + AppTheme)"
```

## Task A4: Config icône + splash Flutter

**Files:**
- Modify: `mobile/pubspec.yaml`

Ajoute les déclarations d'assets + les plugins de génération d'icône/splash. **La génération elle-même (commandes) est lancée par le user** (hors contexte Claude) ; Claude valide que le pubspec résout (`flutter pub get`).

- [ ] **Step 1: Déclarer le dossier d'assets**

Dans `mobile/pubspec.yaml`, sous la clé `flutter:`, ajouter (ou compléter) la section `assets` :

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/brand/
```

- [ ] **Step 2: Ajouter les plugins en dev_dependencies**

Sous `dev_dependencies:` ajouter :

```yaml
  flutter_launcher_icons: ^0.14.1
  flutter_native_splash: ^2.4.1
```

- [ ] **Step 3: Ajouter les configs de génération (fin de fichier)**

À la fin de `mobile/pubspec.yaml`, ajouter :

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/brand/logo_mark_1024.png"
  adaptive_icon_background: "#1A3C5E"
  adaptive_icon_foreground: "assets/brand/logo_mark_1024.png"

flutter_native_splash:
  color: "#1A3C5E"
  image: "assets/brand/logo_mark_1024.png"
  android_12:
    color: "#1A3C5E"
    image: "assets/brand/logo_mark_1024.png"
```

- [ ] **Step 4: Vérifier la résolution des dépendances**

Run: `cd mobile && flutter pub get`
Expected: résolution OK (récupère flutter_launcher_icons + flutter_native_splash). Si un conflit de version survient, ajuster la contrainte au plus proche compatible et re-`pub get`.

- [ ] **Step 5: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "chore(brand): config flutter_launcher_icons + native_splash (génération côté user)"
```

> **Note pour le user (après merge)** : générer les assets natifs depuis ton terminal :
> `cd mobile && dart run flutter_launcher_icons && dart run flutter_native_splash:create`, puis build APK.

## Task A5: Logo in-app Flutter (écran de connexion / AppBar)

**Files:**
- Modify: `mobile/lib/auth/clerk_sign_in_screen.dart` (ou l'écran de connexion existant — voir note)
- Modify: `mobile/lib/home/home_shell.dart` (titre AppBar avec marque)

> Note : repérer l'écran de connexion réel (`grep -ril "SignIn\|connexion\|Clerk" mobile/lib`). S'il n'y a pas d'écran de connexion personnalisable (widget Clerk packagé), se limiter à l'AppBar du `HomeShell`.

Comme les SVG ne sont pas rendus nativement par Flutter sans `flutter_svg`, on affiche le **PNG 1024** (déjà en assets) à taille réduite. (Pas de nouvelle dépendance.)

- [ ] **Step 1: Afficher la marque dans l'AppBar du HomeShell**

Dans `mobile/lib/home/home_shell.dart`, remplacer le `title:` texte de l'`AppBar` par une ligne logo + titre :

```dart
title: Row(
  children: [
    Image.asset('assets/brand/logo_mark_1024.png', height: 28),
    const SizedBox(width: 8),
    const Text('Cameroon Innovation'),
  ],
),
```

(adapter le texte si le titre actuel diffère ; conserver les `actions:` existantes comme la déconnexion).

- [ ] **Step 2: Analyse + tests**

Run: `cd mobile && flutter analyze && flutter test`
Expected: propre + suite verte (l'asset est déclaré en Task A4 ; si A4 pas encore appliqué, l'`Image.asset` reste valide à l'analyse).

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/home/home_shell.dart
git commit -m "feat(brand): marque Cameroon Innovation dans l'AppBar mobile"
```

## Task A6: Tokens de marque web + composant Logo

**Files:**
- Modify: `web/src/app/globals.css`
- Create: `web/src/components/Logo.tsx`
- Modify: `web/src/components/Sidebar.tsx`

- [ ] **Step 1: Ajouter les variables de marque dans `globals.css`**

Dans `web/src/app/globals.css`, ajouter (dans `:root`, ou en fin de fichier sous un nouveau bloc) :

```css
:root {
  --brand-bleu-nuit: #1A3C5E;
  --brand-bleu-nuit-fonce: #13314D;
  --brand-orange: #E67E22;
  --brand-orange-tint: #FEF0E3;
  --brand-page: #F4F6F9;
}
```

- [ ] **Step 2: Créer le composant `Logo`**

Créer `web/src/components/Logo.tsx` :

```tsx
import Image from "next/image";

/** Logo Cameroon Innovation. variant="mark" (écusson) ou "lockup" (avec wordmark). */
export default function Logo({
  variant = "mark",
  className,
}: {
  variant?: "mark" | "lockup";
  className?: string;
}) {
  const src = variant === "lockup" ? "/brand/logo_lockup.svg" : "/brand/logo_mark.svg";
  const dims = variant === "lockup" ? { width: 180, height: 56 } : { width: 36, height: 36 };
  return <Image src={src} alt="Cameroon Innovation" {...dims} className={className} priority />;
}
```

- [ ] **Step 3: Utiliser le logo + chrome bleu nuit dans la Sidebar**

Dans `web/src/components/Sidebar.tsx`, remplacer le bloc texte du titre :

```tsx
<div className="mb-6 text-sm font-semibold text-gray-700">Cameroon Innovation</div>
```

par :

```tsx
<div className="mb-6 flex items-center gap-2">
  <Logo variant="mark" />
  <span className="text-sm font-semibold text-white">Cameroon Innovation</span>
</div>
```

et donner à la `<nav>` le fond bleu nuit : remplacer `bg-gray-50` par `bg-[var(--brand-bleu-nuit)]` dans son `className`, et adapter la couleur des liens actifs/inactifs pour rester lisibles sur fond sombre :
- lien actif : `bg-[var(--brand-orange)] text-white`
- lien inactif : `text-gray-200 hover:bg-white/10`

Ajouter l'import en tête : `import Logo from "@/components/Logo";`

- [ ] **Step 4: Typecheck + build**

Run: `cd web && npx tsc --noEmit && npx next build`
Expected: build OK (la Sidebar et le composant Logo compilent ; les SVG sont servis depuis `public/brand`).

- [ ] **Step 5: Commit**

```bash
git add web/src/app/globals.css web/src/components/Logo.tsx web/src/components/Sidebar.tsx
git commit -m "feat(brand): tokens de marque web + logo et sidebar bleu nuit"
```

---

# PARTIE B — Branches data-driven (`domaine`)

## Task B1: Enum `DomaineTrade` + champ `Task.domaine` (mobile)

**Files:**
- Modify: `mobile/lib/models/task.dart`
- Test: `mobile/test/task_test.dart`

- [ ] **Step 1: Écrire le test (rouge)**

Ajouter à `mobile/test/task_test.dart` :

```dart
import 'package:pointage/models/task.dart';

void mainDomaine() {}

void _domaineTests() {
  group('Task.domaine', () {
    test('wire/fromWire round-trip', () {
      expect(DomaineTrade.electricite.wire, 'electricite');
      expect(DomaineTradeX.fromWire('plomberie'), DomaineTrade.plomberie);
      expect(DomaineTradeX.fromWire(null), isNull);
      expect(DomaineTradeX.fromWire('inconnu'), DomaineTrade.autre);
    });
  });
}
```

Puis, dans le `void main()` existant de ce fichier, appeler `_domaineTests();` (l'ajouter à la fin du `main`). Et ajouter un cas dans le test de sérialisation existant (ou un nouveau test) :

```dart
  test('toFirestore/fromMap conservent domaine', () {
    final t = Task(
      id: 't1', title: 'x', description: '', siteId: 's1', assigneeId: 'u1',
      createdBy: 'm1', priority: TaskPriority.normal, status: TaskStatus.assigned,
      domaine: DomaineTrade.informatique,
    );
    final back = Task.fromMap('t1', t.toFirestore());
    expect(back.domaine, DomaineTrade.informatique);
  });
```

> Note : adapter les noms d'arguments du constructeur `Task` à ceux réellement présents (voir le fichier). Si `Task.fromMap` a une autre signature (ex. `Task.fromFirestore(doc)`), utiliser celle existante avec une map.

- [ ] **Step 2: Lancer le test (échec)**

Run: `cd mobile && flutter test test/task_test.dart`
Expected: FAIL (`DomaineTrade` inconnu / `domaine` absent).

- [ ] **Step 3: Ajouter l'enum + le champ**

Dans `mobile/lib/models/task.dart`, ajouter près des autres enums :

```dart
enum DomaineTrade { electricite, informatique, plomberie, autre }

extension DomaineTradeX on DomaineTrade {
  String get wire => name; // 'electricite' | 'informatique' | 'plomberie' | 'autre'
  static DomaineTrade? fromWire(String? w) {
    if (w == null) return null;
    return DomaineTrade.values.firstWhere(
      (d) => d.name == w,
      orElse: () => DomaineTrade.autre,
    );
  }
}
```

Dans la classe `Task` : ajouter le champ `final DomaineTrade? domaine;`, l'ajouter au constructeur (`this.domaine`), dans `toFirestore()` ajouter `if (domaine != null) 'domaine': domaine!.wire,`, et dans `fromMap`/`fromFirestore` ajouter `domaine: DomaineTradeX.fromWire(m['domaine'] as String?),`.

- [ ] **Step 4: Lancer le test (succès)**

Run: `cd mobile && flutter test test/task_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/task.dart mobile/test/task_test.dart
git commit -m "feat(task): champ domaine + enum DomaineTrade (mobile)"
```

## Task B2: Métadonnées de branche + `BranchChip` (mobile)

**Files:**
- Create: `mobile/lib/branches/branch_meta.dart`
- Create: `mobile/lib/branches/branch_chip.dart`
- Test: `mobile/test/branch_meta_test.dart`

- [ ] **Step 1: Écrire le test (rouge)**

Créer `mobile/test/branch_meta_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/models/task.dart';
import 'package:pointage/branches/branch_meta.dart';

void main() {
  test('branchMeta mappe chaque branche', () {
    expect(branchMeta(DomaineTrade.electricite).label, 'Électricité');
    expect(branchMeta(DomaineTrade.informatique).icon, Icons.videocam);
    expect(branchMeta(DomaineTrade.plomberie).bg, const Color(0xFFE1F5EE));
    expect(branchMeta(DomaineTrade.autre).label, 'Autre');
  });
  test('branchMeta(null) = Non précisé', () {
    expect(branchMeta(null).label, 'Non précisé');
  });
}
```

- [ ] **Step 2: Lancer le test (échec)**

Run: `cd mobile && flutter test test/branch_meta_test.dart`
Expected: FAIL.

- [ ] **Step 3: Créer `branch_meta.dart`**

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';

class BranchMeta {
  const BranchMeta(this.label, this.icon, this.bg, this.fg);
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
}

BranchMeta branchMeta(DomaineTrade? d) {
  switch (d) {
    case DomaineTrade.electricite:
      return const BranchMeta('Électricité', Icons.bolt, Color(0xFFFBF0D6), Color(0xFF854F0B));
    case DomaineTrade.informatique:
      return const BranchMeta('Informatique', Icons.videocam, Color(0xFFE1F0FA), Color(0xFF0C447C));
    case DomaineTrade.plomberie:
      return const BranchMeta('Plomberie', Icons.water_drop, Color(0xFFE1F5EE), Color(0xFF0F6E56));
    case DomaineTrade.autre:
      return const BranchMeta('Autre', Icons.build, Color(0xFFF1EFE8), Color(0xFF444441));
    case null:
      return const BranchMeta('Non précisé', Icons.help_outline, Color(0xFFF1EFE8), Color(0xFF5F6B78));
  }
}
```

- [ ] **Step 4: Lancer le test (succès)**

Run: `cd mobile && flutter test test/branch_meta_test.dart`
Expected: PASS.

- [ ] **Step 5: Créer le widget `BranchChip`**

Créer `mobile/lib/branches/branch_chip.dart` :

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import 'branch_meta.dart';

/// Puce compacte représentant la branche métier d'une tâche.
class BranchChip extends StatelessWidget {
  const BranchChip(this.domaine, {super.key});
  final DomaineTrade? domaine;

  @override
  Widget build(BuildContext context) {
    final m = branchMeta(domaine);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: m.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m.icon, size: 14, color: m.fg),
          const SizedBox(width: 4),
          Text(m.label, style: TextStyle(fontSize: 12, color: m.fg)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Test de rendu du widget**

Ajouter à `mobile/test/branch_meta_test.dart` :

```dart
  testWidgets('BranchChip affiche le libellé de la branche', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BranchChip(DomaineTrade.electricite)),
    ));
    expect(find.text('Électricité'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });
```

Ajouter l'import : `import 'package:pointage/branches/branch_chip.dart';`

- [ ] **Step 7: Lancer + analyse**

Run: `cd mobile && flutter test test/branch_meta_test.dart && flutter analyze lib/branches`
Expected: PASS + propre.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/branches mobile/test/branch_meta_test.dart
git commit -m "feat(branches): branchMeta + widget BranchChip (mobile)"
```

## Task B3: Sélecteur de domaine à la création (mobile)

**Files:**
- Modify: `mobile/lib/tasks/task_create_screen.dart`
- Modify: `mobile/lib/firebase_auth_gate.dart` (câblage de `onCreate`)
- Modify: `mobile/lib/tasks/task_repository.dart` (si `onCreate` y écrit la tâche)
- Test: `mobile/test/task_create_screen_test.dart`

> Note : suivre le flux réel de création. Le `task_create_screen` a un callback `onCreate(title, description, siteId, assigneeId, priority, dueAt)` ; on y ajoute `domaine`. Adapter chaque maillon (screen → gate → repository) à la signature réelle.

- [ ] **Step 1: Écrire/adapter le test (rouge)**

Dans `mobile/test/task_create_screen_test.dart`, ajouter un test vérifiant que le sélecteur de domaine est présent et que la valeur choisie est transmise. S'inspirer des tests existants du même fichier pour le harnais (pump du widget + sélection). Exemple :

```dart
  testWidgets('le sélecteur de domaine transmet la branche choisie', (tester) async {
    DomaineTrade? captured;
    await tester.pumpWidget(MaterialApp(
      home: TaskCreateScreen(
        sites: const [(id: 's1', name: 'Site 1')],
        technicians: const [(id: 'u1', name: 'Tech 1')],
        onCreate: ({required title, required description, required siteId,
                    required assigneeId, required priority, dueAt, domaine}) {
          captured = domaine;
        },
      ),
    ));
    // ouvrir le dropdown domaine et choisir « Plomberie »
    await tester.tap(find.byKey(const Key('domaine-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plomberie').last);
    await tester.pumpAndSettle();
    // remplir le minimum requis puis soumettre (adapter aux champs réels)
    await tester.enterText(find.byKey(const Key('title-field')), 'Tâche');
    await tester.tap(find.byKey(const Key('submit-create')));
    await tester.pumpAndSettle();
    expect(captured, DomaineTrade.plomberie);
  });
```

> Adapter les clés (`title-field`, `submit-create`, etc.) à celles du screen réel ; en ajouter si absentes. La signature exacte de `onCreate` doit correspondre à l'implémentation (Step 3).

- [ ] **Step 2: Lancer le test (échec)**

Run: `cd mobile && flutter test test/task_create_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Ajouter le sélecteur + étendre `onCreate`**

Dans `mobile/lib/tasks/task_create_screen.dart` :
- Étendre la signature du callback `onCreate` avec un paramètre nommé optionnel `DomaineTrade? domaine`.
- Ajouter un état `DomaineTrade _domaine = DomaineTrade.electricite;` (défaut Électricité).
- Ajouter un `DropdownButtonFormField<DomaineTrade>` (clé `Key('domaine-selector')`) listant les 4 branches via `branchMeta(d).label`, placé après le sélecteur de priorité.
- Passer `domaine: _domaine` lors de l'appel à `onCreate`.

```dart
DropdownButtonFormField<DomaineTrade>(
  key: const Key('domaine-selector'),
  value: _domaine,
  decoration: const InputDecoration(labelText: 'Domaine'),
  items: DomaineTrade.values
      .map((d) => DropdownMenuItem(value: d, child: Text(branchMeta(d).label)))
      .toList(),
  onChanged: (v) => setState(() => _domaine = v ?? DomaineTrade.electricite),
),
```

Ajouter les imports : `import '../branches/branch_meta.dart';` et `import '../models/task.dart';` (si pas déjà importé pour `DomaineTrade`).

- [ ] **Step 4: Propager `domaine` dans le câblage**

Dans `mobile/lib/firebase_auth_gate.dart` (et/ou `task_repository.dart`), répercuter le nouveau paramètre `domaine` jusqu'à la création de la tâche Firestore (ajouter `domaine` au `Task` construit, qui le sérialise via Task B1).

- [ ] **Step 5: Lancer le test (succès) + analyse**

Run: `cd mobile && flutter test test/task_create_screen_test.dart && flutter analyze`
Expected: PASS + propre.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/tasks/task_create_screen.dart mobile/lib/firebase_auth_gate.dart mobile/lib/tasks/task_repository.dart mobile/test/task_create_screen_test.dart
git commit -m "feat(tasks): sélecteur de domaine à la création (mobile)"
```

## Task B4: Affichage de la branche (listes + détail mobile)

**Files:**
- Modify: `mobile/lib/tasks/tasks_list_screen.dart`
- Modify: `mobile/lib/tasks/task_detail_screen.dart`

Affichage seul (pas de nouvelle logique testable au-delà du `BranchChip` déjà testé) → validé par `flutter analyze` + suite.

- [ ] **Step 1: Puce dans la liste des tâches**

Dans `mobile/lib/tasks/tasks_list_screen.dart`, dans le `ListTile` de chaque tâche, ajouter `BranchChip(task.domaine)` (par ex. dans le `subtitle` via une `Row`/`Wrap`, ou en `trailing`). Importer `package:pointage/branches/branch_chip.dart`.

- [ ] **Step 2: Puce dans le détail**

Dans `mobile/lib/tasks/task_detail_screen.dart`, ajouter `BranchChip(task.domaine)` près du statut/priorité. Importer le widget.

- [ ] **Step 3: Analyse + suite complète**

Run: `cd mobile && flutter analyze && flutter test`
Expected: « No issues found! » + suite verte.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/tasks/tasks_list_screen.dart mobile/lib/tasks/task_detail_screen.dart
git commit -m "feat(tasks): puce de branche sur liste et détail (mobile)"
```

## Task B5: `domaine` + métadonnées de branche (web)

**Files:**
- Modify: `web/src/lib/tasks.ts`
- Create: `web/src/lib/branches.ts`
- Test: `web/__tests__/branches.test.ts`
- Test: `web/__tests__/tasks.test.ts` (si présent ; sinon créer un test ciblé)

- [ ] **Step 1: Écrire le test branches (rouge)**

Créer `web/__tests__/branches.test.ts` :

```ts
import { branchMeta, DOMAINES } from "@/lib/branches";

describe("branchMeta", () => {
  it("mappe chaque branche", () => {
    expect(branchMeta("electricite").label).toBe("Électricité");
    expect(branchMeta("informatique").icon).toBe("device-cctv");
    expect(branchMeta("plomberie").bg).toBe("#E1F5EE");
    expect(branchMeta("autre").label).toBe("Autre");
  });
  it("fallback pour valeur absente/inconnue", () => {
    expect(branchMeta(undefined).label).toBe("Non précisé");
    expect(branchMeta("bidon").label).toBe("Non précisé");
  });
  it("DOMAINES liste les 4 branches", () => {
    expect(DOMAINES).toEqual(["electricite", "informatique", "plomberie", "autre"]);
  });
});
```

- [ ] **Step 2: Lancer (échec)**

Run: `cd web && npx jest branches`
Expected: FAIL (module absent).

- [ ] **Step 3: Créer `web/src/lib/branches.ts`**

```ts
export type Domaine = "electricite" | "informatique" | "plomberie" | "autre";
export const DOMAINES: Domaine[] = ["electricite", "informatique", "plomberie", "autre"];

export interface BranchMeta { label: string; icon: string; bg: string; fg: string; }

const META: Record<Domaine, BranchMeta> = {
  electricite: { label: "Électricité", icon: "bolt", bg: "#FBF0D6", fg: "#854F0B" },
  informatique: { label: "Informatique", icon: "device-cctv", bg: "#E1F0FA", fg: "#0C447C" },
  plomberie: { label: "Plomberie", icon: "droplet", bg: "#E1F5EE", fg: "#0F6E56" },
  autre: { label: "Autre", icon: "tools", bg: "#F1EFE8", fg: "#444441" },
};
const UNSET: BranchMeta = { label: "Non précisé", icon: "help", bg: "#F1EFE8", fg: "#5F6B78" };

export function branchMeta(d: string | undefined | null): BranchMeta {
  if (d && d in META) return META[d as Domaine];
  return UNSET;
}
```

- [ ] **Step 4: Lancer (succès)**

Run: `cd web && npx jest branches`
Expected: PASS.

- [ ] **Step 5: Ajouter `domaine` au mapping des tâches**

Dans `web/src/lib/tasks.ts` : ajouter `domaine?: string` à `TaskDoc` et `TaskRow`, et dans `mapTaskDoc` mapper `domaine: data.domaine ?? undefined`. Si un test `web/__tests__/tasks.test.ts` existe, y ajouter un cas (présent/absent) ; sinon créer un test minimal vérifiant `mapTaskDoc` conserve `domaine`.

- [ ] **Step 6: Typecheck + jest**

Run: `cd web && npx tsc --noEmit && npx jest branches tasks`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add web/src/lib/branches.ts web/src/lib/tasks.ts web/__tests__/branches.test.ts web/__tests__/tasks.test.ts
git commit -m "feat(branches): domaine sur TaskRow + branchMeta (web)"
```

## Task B6: `BranchBadge` + affichage (board, détail, table — web)

**Files:**
- Create: `web/src/components/BranchBadge.tsx`
- Modify: `web/src/app/(dashboard)/board/page.tsx`
- Modify: `web/src/app/(dashboard)/board/[taskId]/page.tsx`
- Modify: `web/src/app/(dashboard)/tasks/page.tsx`

- [ ] **Step 1: Créer `BranchBadge`**

Créer `web/src/components/BranchBadge.tsx` :

```tsx
import { branchMeta } from "@/lib/branches";

/** Puce de branche métier (couleur + libellé). */
export default function BranchBadge({ domaine }: { domaine?: string | null }) {
  const m = branchMeta(domaine);
  return (
    <span
      style={{ backgroundColor: m.bg, color: m.fg }}
      className="inline-block rounded px-2 py-0.5 text-xs"
    >
      {m.label}
    </span>
  );
}
```

- [ ] **Step 2: Afficher dans le board, le détail et la table**

- `board/page.tsx` : ajouter `<BranchBadge domaine={t.domaine} />` dans chaque carte.
- `board/[taskId]/page.tsx` : ajouter `<BranchBadge domaine={task.domaine} />` près du site/statut.
- `tasks/page.tsx` : ajouter une colonne « Domaine » (en-tête + `<td><BranchBadge domaine={t.domaine} /></td>`) après la colonne Site.

Importer `BranchBadge` dans chaque page (`import BranchBadge from "@/components/BranchBadge";`).

- [ ] **Step 3: Typecheck + build**

Run: `cd web && npx tsc --noEmit && npx next build`
Expected: build OK (routes board/tasks inchangées en nombre, colonnes ajoutées).

- [ ] **Step 4: Commit**

```bash
git add web/src/components/BranchBadge.tsx "web/src/app/(dashboard)/board/page.tsx" "web/src/app/(dashboard)/board/[taskId]/page.tsx" "web/src/app/(dashboard)/tasks/page.tsx"
git commit -m "feat(branches): BranchBadge sur board, détail et table (web)"
```

## Task B7: Stats regroupées par branche (web)

**Files:**
- Modify: `web/src/lib/stats.ts`
- Modify: `web/src/app/(dashboard)/stats/page.tsx`
- Test: `web/__tests__/stats.test.ts`

- [ ] **Step 1: Écrire le test (rouge)**

Ajouter à `web/__tests__/stats.test.ts` :

```ts
import { completionByDomaine } from "@/lib/stats";

describe("completionByDomaine", () => {
  const range = { start: new Date(Date.UTC(2026, 5, 1)), end: new Date(Date.UTC(2026, 5, 30)) };
  const mk = (domaine: string | undefined, status: string) =>
    ({ assigneeId: "u1", siteId: "s1", status, dueAt: new Date(Date.UTC(2026, 5, 10)), createdAt: null, domaine } as any);
  it("regroupe complétion par branche, fallback 'non-precise'", () => {
    const m = completionByDomaine(
      [mk("electricite", "done"), mk("electricite", "assigned"), mk(undefined, "approved")],
      range,
    );
    expect(m.get("electricite")).toEqual({ done: 1, total: 2 });
    expect(m.get("non-precise")).toEqual({ done: 1, total: 1 });
  });
});
```

- [ ] **Step 2: Lancer (échec)**

Run: `cd web && npx jest stats`
Expected: FAIL.

- [ ] **Step 3: Implémenter `completionByDomaine`**

Dans `web/src/lib/stats.ts` : ajouter `domaine?: string` à l'interface `StatsTask`, puis ajouter la fonction (réutilise `taskInPeriod` existant) :

```ts
/** Complétion par branche (domaine), fallback 'non-precise'. */
export function completionByDomaine(
  tasks: StatsTask[],
  range: { start: Date; end: Date },
): Map<string, { done: number; total: number }> {
  const out = new Map<string, { done: number; total: number }>();
  for (const t of tasks) {
    if (!taskInPeriod(t, range.start, range.end)) continue;
    const k = t.domaine ?? "non-precise";
    const cur = out.get(k) ?? { done: 0, total: 0 };
    cur.total += 1;
    if (t.status === "done" || t.status === "approved") cur.done += 1;
    out.set(k, cur);
  }
  return out;
}
```

- [ ] **Step 4: Lancer (succès)**

Run: `cd web && npx jest stats`
Expected: PASS.

- [ ] **Step 5: Afficher la section « Par branche » dans la page stats**

Dans `web/src/app/(dashboard)/stats/page.tsx` : charger `domaine` dans le mapping des tâches (depuis le doc Firestore), appeler `completionByDomaine`, et rendre un tableau « Complétion par branche » utilisant `branchMeta(key).label` (key === 'non-precise' → « Non précisé »). Importer `completionByDomaine` et `branchMeta`.

- [ ] **Step 6: Typecheck + jest + build**

Run: `cd web && npx tsc --noEmit && npx jest && npx next build`
Expected: PASS + build OK.

- [ ] **Step 7: Commit**

```bash
git add web/src/lib/stats.ts "web/src/app/(dashboard)/stats/page.tsx" web/__tests__/stats.test.ts
git commit -m "feat(stats): complétion par branche (web)"
```

---

## Task C1: Garde-fous finaux

**Files:** aucun (vérification globale).

- [ ] **Step 1: Mobile**

Run: `cd mobile && flutter analyze && flutter test`
Expected: « No issues found! » + suite verte (base 44 + thème + domaine + branches).

- [ ] **Step 2: Web**

Run: `cd web && npx jest && npx tsc --noEmit && npx eslint . && npx next build`
Expected: tout vert, routes `/board`, `/tasks`, `/stats` présentes.

- [ ] **Step 3: Finalisation de branche**

Utiliser **superpowers:finishing-a-development-branch** : merge `--no-ff` vers `main`. Mettre à jour `CLAUDE.md` (Phase 4 → identité visuelle livrée) et `docs/HANDOFF.md`.

> **Reste côté user (après merge)** :
> - Web : push `main` → auto-deploy Vercel ; valider le rendu (sidebar bleu nuit, logo, badges de branche).
> - Mobile : `cd mobile && dart run flutter_launcher_icons && dart run flutter_native_splash:create`, puis build APK + validation appareil (icône, splash, thème, sélecteur de domaine, puces de branche).

---

## Notes
- **Aucun changement de règles Firestore** (le `domaine` est posé par le manager à la création ; l'assigné ne le modifie pas). Pas de `firebase deploy`.
- Le **cycle 2** (refonte du formulaire de rapport CI-F-003) réutilisera `DomaineTrade`/`domaine`.
- Les SVG et le rendu visuel se valident à l'œil (aperçu navigateur / Vercel) en plus des garde-fous automatiques.
