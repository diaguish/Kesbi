# Décisions d'architecture (ADR)

Un fichier par décision structurante : `NNNN-titre-court.md`.
Une décision n'est jamais modifiée après acceptation : on crée un nouvel ADR qui la remplace.

| # | Titre | Statut |
|---|---|---|
| [0001](0001-plateformes-cibles.md) | Plateformes cibles : Android + iOS au MVP | Accepté |
| [0002](0002-schema-offline-first.md) | Schéma de données offline-first | Accepté |
| [0003](0003-authentification-otp-pin.md) | Authentification : OTP SMS + code PIN local | Accepté |
| [0004](0004-comptes-et-soldes-ouverture.md) | Comptes MVP (sans Banque), soldes d'ouverture, transferts | Accepté |
| [0005](0005-identifiant-application.md) | Identifiant de l'application : `com.kesbi.app` | Accepté |
| [0006](0006-riverpod-go-router.md) | Gestion d'état Riverpod, navigation go_router | Accepté |
| [0007](0007-backend-auth-jwt-et-isolation.md) | Backend : JWT Supabase et isolation par boutique | Accepté |
| [0008](0008-auth-mobile-implementation.md) | Auth mobile : session sécurisée, hachage du PIN, verrouillage | Accepté |
| [0009](0009-modele-transactions.md) | Transactions : montant signé, comptes sans table, annulation | Accepté |
| [0010](0010-suppression-de-compte.md) | Suppression de compte (données + utilisateur Supabase) | Accepté |
| [0011](0011-synchronisation-hors-ligne.md) | Synchronisation hors ligne des transactions | Accepté |

## Modèle
```markdown
# NNNN — Titre

- Statut : Proposé | Accepté | Remplacé par NNNN
- Date : AAAA-MM-JJ

## Contexte
## Décision
## Conséquences
```
