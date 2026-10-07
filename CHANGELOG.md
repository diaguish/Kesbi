# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versions [SemVer](https://semver.org/lang/fr/).

## [Unreleased]
### Ajouté
- Structure du repo, documentation initiale.
- ADR 0001 (Android + iOS), 0002 (schéma offline-first), 0003 (auth OTP + PIN local),
  0004 (comptes, soldes d'ouverture, transferts, ajustements).
- Maquettes v0 et règles UI (`docs/design/`).
- API Django `backend/` (ADR 0007) : vérification du JWT Supabase (JWKS / HS256), modèles
  Boutique et Membre, isolation par boutique, RLS sur les tables créées, `render.yaml`.
