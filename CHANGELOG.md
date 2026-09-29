# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versions [SemVer](https://semver.org/lang/fr/).

## [Unreleased]
### Ajouté
- Structure du repo, documentation initiale.
- ADR 0001 (Android + iOS), 0002 (schéma offline-first), 0003 (auth OTP + PIN local),
  0004 (comptes, soldes d'ouverture, transferts, ajustements).
- Maquettes v0 et règles UI (`docs/design/`).
- App Flutter `mobile/` (Android + iOS), identifiant `com.kesbi.app` (ADR 0005),
  thème aux couleurs Kës Bi, formatage FCFA testé.
- Riverpod + go_router (ADR 0006) : barre à 4 onglets, garde d'accès OTP / PIN / onboarding testée.
