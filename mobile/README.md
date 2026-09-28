# Kës Bi — App mobile (Flutter)

Android + iOS. Identifiant store : **`com.kesbi.app`** ([ADR 0005](../docs/decisions/0005-identifiant-application.md)).

## Lancer
```bash
flutter pub get
flutter run
```
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
    theme/             AppColors (seule source des couleurs), AppTheme
    utils/money.dart   Formatage FCFA (seule fonction de formatage des montants)
  features/            Un dossier par module (créé au fil des semaines)
    auth/
    encaissements/
    ...
```
Chaque module de `features/` suit le même découpage : `data/` (API, sqflite),
`domain/` (modèles), `presentation/` (écrans, widgets).

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
