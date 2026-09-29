# Décisions d'architecture (ADR)

Un fichier par décision structurante : `NNNN-titre-court.md`.
Une décision n'est jamais modifiée après acceptation : on crée un nouvel ADR qui la remplace.

| # | Titre | Statut |
|---|---|---|
| [0001](0001-plateformes-cibles.md) | Plateformes cibles : Android + iOS au MVP | Accepté |
| [0002](0002-schema-offline-first.md) | Schéma de données offline-first | Accepté |
| [0003](0003-authentification-otp-pin.md) | Authentification : OTP SMS + code PIN local | Accepté |
| [0004](0004-comptes-et-soldes-ouverture.md) | Comptes MVP (sans Banque), soldes d'ouverture, transferts |
| [0005](0005-identifiant-application.md) | Identifiant de l'application : `com.kesbi.app` | Accepté |
| [0006](0006-riverpod-go-router.md) | Gestion d'état Riverpod, navigation go_router | Accepté | Accepté |

## Modèle
```markdown
# NNNN — Titre

- Statut : Proposé | Accepté | Remplacé par NNNN
- Date : AAAA-MM-JJ

## Contexte
## Décision
## Conséquences
```
