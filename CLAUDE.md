# Kës Bi — Contexte projet

Application mobile de gestion financière pour commerçants et PME sénégalais.
Remplace le cahier de caisse : encaissements, dépenses, trésorerie multi-comptes
(Caisse, Wave, Orange Money — Banque hors MVP), créances clients avec relances.

- **Deadline MVP** : 1er décembre 2026 — **Android ET iOS publiés** (voir [ADR 0001](docs/decisions/0001-plateformes-cibles.md))
- **Équipe** : 1 dev (CTO), ~20h/semaine
- **Démarrage** : semaine du 21/09/2026 (S1)

## Stack (verrouillée — ne pas proposer d'alternatives)
| Couche | Techno |
|---|---|
| Mobile | Flutter 3.47.x + Dart (`/mobile`) |
| API | Django + DRF sur Render (`/backend`) |
| BDD / Auth / Realtime | Supabase (PostgreSQL, Supabase Auth OTP, Realtime) |
| Push | Firebase Cloud Messaging (APNs pour iOS) |
| Offline | sqflite + connectivity_plus + workmanager |
| Sécurité | JWT Supabase, AES-256, flutter_secure_storage, RLS |
| PDF | ReportLab (côté Django) |
| Landing | Astro + Vercel (hors MVP) |
| CI/CD | GitHub → Render (auto-deploy depuis `main`) |

## Règles non négociables
1. **Montants en entiers FCFA** (`BigIntegerField` / `int`). Jamais de float.
2. **Soldes calculés** depuis les transactions, jamais stockés/modifiés à la main.
3. **UUID générés côté client**, écritures idempotentes (offline-first, [ADR 0002](docs/decisions/0002-schema-offline-first.md)).
4. **`boutique_id` sur toutes les tables métier.** Django filtre chaque requête par boutique (Django contourne RLS).
5. **Dates en UTC** en base, affichage Africa/Dakar.
6. **Aucun secret commité** (`.env`, `google-services.json`, `GoogleService-Info.plist`, clés `.p8`, keystores).
7. Chaque feature testée **sur Android ET iOS** avant merge dans `dev`.
8. Toute décision technique structurante → un ADR dans `docs/decisions/`.

## Décisions produit
- Relances clients toujours **manuelles** (validation du commerçant avant envoi, deep link WhatsApp).
- Dashboard : vue **semaine** par défaut.
- Comptes affichés **séparément** : Caisse / Wave / Orange Money. Banque hors MVP ([ADR 0004](docs/decisions/0004-comptes-et-soldes-ouverture.md)).
- Transferts entre comptes (Caisse ↔ Wave ↔ OM) : 2 transactions liées, hors CA/dépenses ; les frais = vraie dépense.
- Soldes d'ouverture saisis à l'onboarding (« Ignorer » = 0), stockés comme transactions `ouverture`.
- « Corriger le solde » = transaction `ajustement` de la différence (jamais d'écriture directe du solde).
- Auth : OTP SMS à l'inscription / nouvel appareil, **PIN 6 chiffres local** au quotidien ([ADR 0003](docs/decisions/0003-authentification-otp-pin.md)). Le PIN n'est jamais envoyé au serveur.
- **1 utilisateur par boutique** au MVP (mais modèle prêt pour multi-user).
- Suppression de compte disponible dans l'app (exigence Apple + Google).

## Hors MVP
Multi-utilisateur/rôles (P2), prévision trésorerie 30/90j (P2), scoring bancaire (P3).

## Palette UI
| Rôle | Hex |
|---|---|
| Primary | `#1B5E3B` |
| Accent | `#D4A017` |
| Background | `#F2EDE3` |
| Surface | `#FAFAF5` |
| Text dark | `#0D2E1C` |
| Error | `#C0392B` |

## Workflow Git
Voir [docs/git-workflow.md](docs/git-workflow.md). Résumé : `feature/*` → `dev` → `main` (deploy).

## Documentation
- [docs/architecture.md](docs/architecture.md) — architecture et flux
- [docs/setup.md](docs/setup.md) — installer l'environnement (Windows + Mac)
- [docs/roadmap.md](docs/roadmap.md) — planning 10 semaines + jalons stores
- [docs/design/](docs/design/README.md) — maquettes, écrans manquants, règles UI (contraste, montants)
- [docs/decisions/](docs/decisions/) — ADR
