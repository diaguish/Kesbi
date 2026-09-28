# Workflow Git

## Branches
| Branche | Rôle |
|---|---|
| `main` | Production. Push → auto-deploy Render. Jamais de commit direct. |
| `dev` | Intégration. Toutes les features y sont mergées d'abord. |
| `feature/<module>-<sujet>` | Une branche par feature, créée depuis `dev`. Ex. `feature/auth-otp` |
| `fix/<sujet>` | Correctif, créé depuis `dev` |
| `hotfix/<sujet>` | Correctif urgent prod, créé depuis `main`, mergé dans `main` ET `dev` |

## Cycle
1. `git checkout dev && git pull`
2. `git checkout -b feature/encaissements-crud`
3. Commits → Pull Request vers `dev`
4. Checklist avant merge :
   - [ ] Testé sur Android
   - [ ] Testé sur iOS
   - [ ] Pas de secret commité
   - [ ] Docs / ADR / CHANGELOG à jour si nécessaire
5. Release : PR `dev` → `main`, tag `vX.Y.Z`

## Messages de commit
[Conventional Commits](https://www.conventionalcommits.org/fr/) :
`feat(auth): vérification OTP`, `fix(sync): doublon au rejeu`, `docs: ADR 0003`.
