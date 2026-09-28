# Installation de l'environnement

## Versions de référence
| Outil | Version |
|---|---|
| Flutter | 3.47.5 (stable) — **identique sur Windows et Mac** |
| Python | 3.13 |
| Xcode | dernière stable (Mac uniquement) |

> Si la version Flutter change, mettre à jour ce tableau dans le même commit.

## Windows (dev Android + backend)
- Flutter SDK, Android SDK, un émulateur ou un téléphone Android
- Python 3.13
- `flutter doctor` sans erreur sur la partie Android

## Mac (build et tests iOS)
```bash
xcode-select --install
brew install cocoapods
flutter doctor
```
- Un iPhone physique est nécessaire pour les notifications push et les tests offline réels.
- Ouvrir `mobile/ios/Runner.xcworkspace` (pas `.xcodeproj`) pour la signature.

## Backend
_À compléter lors du scaffold Django._

## Mobile
_À compléter lors du scaffold Flutter._

## Secrets
Chaque dossier fournit un `.env.example`. Copier en `.env` et remplir.
Les fichiers Firebase (`google-services.json`, `GoogleService-Info.plist`) sont
à récupérer depuis la console Firebase — ils ne sont pas dans le repo.
