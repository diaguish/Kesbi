# Kës Bi — App mobile (Flutter)

Android + iOS. Identifiant store : **`com.kesbi.app`** ([ADR 0005](../docs/decisions/0005-identifiant-application.md)).

## Lancer
La configuration (Supabase, API) est passée au build ([ADR 0008](../docs/decisions/0008-auth-mobile-implementation.md)) :
```bash
cp env/dev.example.json env/dev.json   # puis renseigner la clé publishable (fichier ignoré par git)
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```
- Connexion de test : numéro `77 000 00 00`, code SMS `123456` (numéro de test Supabase, aucun SMS envoyé).
- L'API Django doit tourner (`runserver 0.0.0.0:8000`) pour savoir si la boutique existe ;
  sans elle, l'app passe à l'onboarding.
Tests et analyse (obligatoires avant chaque PR) :
```bash
flutter analyze
flutter test
```

## Structure de `lib/`
```
lib/
  main.dart            Point d'entrée
  app.dart             MaterialApp, thème, navigation
  core/                Code partagé, sans logique métier d'un module
    router/            go_router : Routes (chemins), authRedirect (garde unique), appRouterProvider
    theme/             AppColors (seule source des couleurs), AppTheme
    utils/money.dart   Formatage FCFA (seule fonction de formatage des montants)
    widgets/           MainShell (barre 4 onglets), widgets partagés
  features/            Un dossier par module (créé au fil des semaines)
    auth/
    encaissements/
    ...
```
Chaque module de `features/` suit le même découpage : `data/` (API, sqflite),
`domain/` (modèles), `presentation/` (écrans, widgets).

## État et navigation ([ADR 0006](../docs/decisions/0006-riverpod-go-router.md))
- **Riverpod** (sans génération de code) : les écrans lisent les données via des providers,
  jamais sqflite ou l'API en direct.
- **go_router** : chemins dans `Routes`, accès contrôlé par `authRedirect()`
  (OTP → PIN → onboarding → app). Nouvel écran protégé = nouveau test dans `routes_test.dart`.

## Règles
- Couleurs : uniquement via `AppColors`. Jamais de hex dans un widget.
- Montants : `int` FCFA, affichés uniquement via `formatFcfa` / `formatFcfaSigned`.
- Tester sur Android **et** iOS avant tout merge dans `dev`.

## Identifiants par plateforme
| Plateforme | Fichier | Valeur |
|---|---|---|
| Android `applicationId` | `android/app/build.gradle.kts` | `com.kesbi.app` |
| Android `namespace` (interne, code Kotlin) | `android/app/build.gradle.kts` | `com.kesbi.kesbi` |
| iOS Bundle ID | `ios/Runner.xcodeproj/project.pbxproj` | `com.kesbi.app` |
| Nom affiché | `AndroidManifest.xml` / `Info.plist` | Kës Bi |
