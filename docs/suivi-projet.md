# Suivi projet Kës Bi — cahier des charges et avancement

> **Document vivant.** Mis à jour à la fin de chaque session de travail.
> But : savoir à tout moment où on en est, ce qui est fait, ce qui reste jusqu'au MVP,
> et permettre à une autre personne de reprendre le projet.
>
> Dernière mise à jour : **04/10/2026** (fin S2)

---

## 1. Fiche projet

| | |
|---|---|
| Produit | App mobile de gestion financière pour commerçants et PME sénégalais (remplace le cahier de caisse) |
| Plateformes | Android + iOS ([ADR 0001](decisions/0001-plateformes-cibles.md)) |
| Livraison MVP | **1er décembre 2026** — publication Play Store + App Store |
| Équipe | Diago (CTO, seule dev), ~20h/semaine |
| Repo | https://github.com/diaguish/Kesbi — branches `feature/*` → `dev` → `main` |
| Stack | Voir [CLAUDE.md](../CLAUDE.md) |

---

## 2. Cahier des charges fonctionnel (périmètre MVP)

Légende : ✅ fait · 🟡 en cours · ⬜ à faire · ❌ retiré

### 2.1 Authentification et compte — S1-S2 ([ADR 0003](decisions/0003-authentification-otp-pin.md))
| # | Exigence | État |
|---|---|---|
| A1 | Inscription par numéro de téléphone (+221) et OTP SMS | ⬜ |
| A2 | Création d'un PIN à 6 chiffres, stocké haché sur le téléphone uniquement | ⬜ |
| A3 | Déverrouillage quotidien par PIN, fonctionne hors ligne | ⬜ |
| A4 | Nouvel appareil / PIN oublié / 5 PIN faux → retour OTP | ⬜ |
| A5 | Verrouillage automatique après quelques minutes en arrière-plan | ⬜ |
| A6 | Création de la boutique (nom, activité) | ⬜ |
| A7 | Soldes d'ouverture par compte (« Ignorer » = 0) ([ADR 0004](decisions/0004-comptes-et-soldes-ouverture.md)) | ⬜ |
| A8 | Suppression du compte depuis l'app (exigence Apple + Google) | ⬜ |
| A9 | Vérification du JWT Supabase par Django à chaque requête | 🟡 codé et testé (`feature/setup-backend`), à valider avec un vrai JWT |

### 2.2 Encaissements — S3
| # | Exigence | État |
|---|---|---|
| E1 | Saisir un encaissement : montant, catégorie, compte crédité, date (défaut aujourd'hui), client, note | ⬜ |
| E2 | Catégorie « Règlement créance » liée à un client existant (diminue le reste dû) | ⬜ |
| E3 | Fonctionne hors ligne (UUID côté app, sync idempotente) ([ADR 0002](decisions/0002-schema-offline-first.md)) | ⬜ |
| E4 | Correction = annulation + nouvelle écriture (pas de modification de montant) | ⬜ |
| E5 | Historique des transactions avec filtres | ⬜ |

### 2.3 Dépenses — S4
| # | Exigence | État |
|---|---|---|
| D1 | Saisir une dépense : montant, catégorie, compte débité, date, note | ⬜ |
| D2 | Hors ligne + annulation, comme les encaissements | ⬜ |

### 2.4 Dashboard — S5
| # | Exigence | État |
|---|---|---|
| B1 | Solde total + solde de chaque compte (Caisse, Wave, Orange Money) | ⬜ |
| B2 | Vue **semaine** par défaut | ⬜ |
| B3 | Transactions récentes | ⬜ |
| B4 | Alerte créances échues | ⬜ |
| B5 | Graphique d'évolution | ⬜ |
| B6 | Mise à jour temps réel (Supabase Realtime) + indication « mis à jour à … » | ⬜ |

### 2.5 Trésorerie — S6
| # | Exigence | État |
|---|---|---|
| T1 | Comptes Caisse, Wave, Orange Money affichés séparément (Banque ❌ retirée du MVP) | ⬜ |
| T2 | Transferts entre comptes + frais (= vraie dépense) | ⬜ |
| T3 | « Corriger le solde » → transaction `ajustement` | ⬜ |
| T4 | Soldes toujours calculés depuis les transactions | ⬜ |

### 2.6 Créances et relances — S7-S8
| # | Exigence | État |
|---|---|---|
| C1 | Créer une créance : client, montant, date d'échéance | ⬜ |
| C2 | Liste filtrable : toutes / en cours / échues / soldées | ⬜ |
| C3 | Détail : reste dû, historique des paiements partiels | ⬜ |
| C4 | Relance WhatsApp **manuelle** (aperçu du message, validation, deep link) | ⬜ |
| C5 | Notification push FCM (Android + APNs iOS) pour échéances | ⬜ |

### 2.7 Rapports — S9
| # | Exigence | État |
|---|---|---|
| R1 | Rapport de période (encaissements, dépenses, par compte, par catégorie) | ⬜ |
| R2 | Export PDF (ReportLab côté Django) | ⬜ |

### 2.8 Transverse
| # | Exigence | État |
|---|---|---|
| X1 | Mode hors ligne complet + synchronisation (ouverture, premier plan, retour réseau, workmanager) | ⬜ |
| X2 | Montants entiers FCFA, format `25 000 FCFA` | ✅ |
| X3 | Thème et couleurs Kës Bi, contraste lisible en extérieur | ✅ (police Poppins ⬜) |
| X4 | Navigation 4 onglets + garde d'accès OTP / PIN / onboarding | ✅ |
| X5 | Politique de confidentialité en ligne | ⬜ |

### 2.9 Hors périmètre MVP
Multi-utilisateur / rôles (P2) · prévision trésorerie 30/90 j (P2) · compte Banque · scoring bancaire (P3) ·
alerte « solde bas » · biométrie.

---

## 3. Planning et avancement

| Semaine | Dates | Objectif | État |
|---|---|---|---|
| **S1-S2** | 21/09 → 04/10 | Infra, auth OTP + PIN, suppression de compte, comptes stores | 🟡 **En retard** : base faite, auth pas commencée |
| S3 | 05/10 → 11/10 | Encaissements · 1er build iOS sur iPhone | ⬜ |
| S4 | 12/10 → 18/10 | Dépenses · 1er build TestFlight | ⬜ |
| S5 | 19/10 → 25/10 | Dashboard | ⬜ |
| S6 | 26/10 → 01/11 | Trésorerie + transferts · **lancement test fermé Play Store** | ⬜ |
| S7-S8 | 02/11 → 15/11 | Créances + FCM · **1ère soumission App Store (S8)** | ⬜ |
| S9 | 16/11 → 22/11 | Rapports + PDF · correctifs review Apple | ⬜ |
| S10 | 23/11 → 01/12 | Tests, offline, publication | ⬜ |

Plan de délestage si retard : alléger Rapports → simplifier le graphique → les jalons stores ne bougent pas.

---

## 4. À faire maintenant

### Diago (actions hors code)
| Priorité | Tâche | État |
|---|---|---|
| ✅ | Créer le projet Supabase — ref `ubpvgafdhjnsimffybnd` (`https://ubpvgafdhjnsimffybnd.supabase.co`) | ✅ 01/10 |
| 🔴 | Autoriser le MCP Supabase (OAuth) — le serveur est vu mais **non authentifié** au 01/10 | ⬜ |
| 🔴 | Supabase : vérifier le type de clés JWT (Settings → JWT Keys : asymétriques attendues) et récupérer la chaîne **Session pooler** | ⬜ |
| 🔴 | Supabase : indiquer la région ; activer Auth → Phone ; ajouter un numéro de test (ex. `+221770000000` / `123456`) | ⬜ |
| 🔴 | Choisir un fournisseur SMS et tester la réception sur Orange / Free / Expresso | ⬜ |
| 🔴 | Ouvrir Apple Developer (99 $) et Play Console (25 $) — personnel ou organisation ? | ⬜ |
| 🟠 | Créer le compte Render, puis New → Blueprint sur le repo (`render.yaml`) avec `DATABASE_URL` et `SUPABASE_URL` | ⬜ |
| 🟠 | Tester `feature/setup-mobile` sur le Mac (iOS) puis ouvrir la PR vers `dev` | ⬜ |
| 🟡 | Police Poppins : télécharger ou autoriser le téléchargement | ⬜ |
| 🟡 | Supprimer l'ancien dossier du repo dans OneDrive | ⬜ |
| 🟡 | Protéger la branche `main` sur GitHub | ⬜ |

### Développement (prochaines étapes)
1. `feature/setup-backend` (🟡 codé, 23 tests au vert) : migrer sur Supabase et tester avec un vrai JWT dès que le MCP / la chaîne de connexion sont disponibles, puis PR vers `dev`.
2. `feature/auth-otp-pin` : écrans numéro → OTP → création PIN, déverrouillage, stockage sécurisé.
3. Onboarding : création boutique, soldes d'ouverture, suppression de compte.

---

## 5. Risques et points de vigilance

| Risque | Impact | Mesure |
|---|---|---|
| Retard auth S2 | Encaissements S3 serré | Démarrer le backend dès que Supabase existe |
| Test fermé Play Store (12 testeurs / 14 jours) | Publication Android bloquée | Lancer en S6 au plus tard, recruter les testeurs dès maintenant |
| Review Apple (refus possible) | Publication iOS retardée | 1ère soumission en S8 |
| Livraison des SMS OTP au Sénégal | Inscription impossible | Tester le fournisseur tôt ; numéros de test Supabase en dev |
| Render gratuit en veille (30-50 s) | Mauvaise 1ère impression | Offre payante (~7 $/mois) en production |
| Charge : ~200 h pour tout le MVP | Retard global | Suivi hebdo dans ce document, délestage Rapports |
| MCP Supabase avec accès écriture (`database`, `account`, `branching`) | Modification de données réelles / coûts | Projet Supabase **séparé** pour la production, jamais relié au MCP (ou `read_only=true`) |
| Tables Django dans le schéma `public` exposé par l'API Supabase | Données lisibles avec la clé `anon` | `enable_rls()` obligatoire dans chaque migration (ADR 0007) |
| `AuthStatus.ready` provisoire dans l'app | App déverrouillée sans auth | Supprimé dans `feature/auth-otp-pin` — **ne jamais publier en l'état** |

---

## 6. Décisions prises

| Date | Décision | Référence |
|---|---|---|
| 28/09 | Android **et** iOS au MVP, builds iOS sur le Mac | [ADR 0001](decisions/0001-plateformes-cibles.md) |
| 28/09 | Schéma offline-first (UUID client, montants entiers, suppression logique, écritures immuables) | [ADR 0002](decisions/0002-schema-offline-first.md) |
| 28/09 | Auth OTP SMS + PIN local (le PIN ne quitte jamais le téléphone) | [ADR 0003](decisions/0003-authentification-otp-pin.md) |
| 28/09 | Comptes Caisse / Wave / OM (Banque retirée), soldes d'ouverture, transferts, ajustements | [ADR 0004](decisions/0004-comptes-et-soldes-ouverture.md) |
| 28/09 | Identifiant d'app `com.kesbi.app` | [ADR 0005](decisions/0005-identifiant-application.md) |
| 29/09 | Riverpod (sans codegen) + go_router | [ADR 0006](decisions/0006-riverpod-go-router.md) |
| 28/09 | Repo déplacé hors OneDrive vers `C:\dev\Kesbi` | — |
| 01/10 | Backend : Django 5.2 LTS sans contrib.auth, JWT Supabase via JWKS, isolation par boutique, RLS sur les tables Django | [ADR 0007](decisions/0007-backend-auth-jwt-et-isolation.md) |

---

## 7. Journal des sessions

### 04/10/2026
- App relancée sur l'émulateur Android : OK (branche `feature/setup-mobile`).
- Correction du tableau des ADR (statuts 0004 et 0006) sur `feature/setup-mobile`.
- **MCP Supabase toujours non autorisé** (connexion OAuth à faire via `/mcp` dans un terminal `claude`).
- Fin S2 : backend scaffoldé mais non testé sur Supabase ; **auth côté app (OTP + PIN) non commencée → glisse sur S3**.

### 01/10/2026 (2)
- MCP Supabase : serveur détecté mais **authentification OAuth non faite** → non vérifié.
- Branche `feature/setup-backend` : Django 5.2 LTS + DRF, vérification du JWT Supabase (JWKS / HS256),
  modèles Boutique + Membre, création idempotente, `BoutiqueScopedMixin`, RLS automatique sur les
  tables créées, `render.yaml`, `.env.example`, ADR 0007. 23 tests au vert (SQLite).
- **Reprise** : autoriser le MCP, vérifier les clés JWT du projet, `migrate` sur Supabase, test de bout en bout.

### 01/10/2026
- App relancée sur l'émulateur Android : OK.
- Bilan S2 : base solide, **authentification pas commencée** (bloquée par Supabase).
- Création de ce document de suivi.
- Projet Supabase créé (ref `ubpvgafdhjnsimffybnd`). Serveur MCP Supabase ajouté au projet
  (`.mcp.json`) — actif après redémarrage de la session et connexion.
- **Reprise à la prochaine session** : vérifier le MCP Supabase, puis démarrer `feature/setup-backend`.

### 29/09/2026
- Ajout de Riverpod et go_router : barre à 4 onglets, garde d'accès unique `authRedirect()` (ADR 0006).
- 11 tests automatiques au vert.
- Premier test sur émulateur Android : thème et navigation OK.

### 28/09/2026
- Cadrage du projet, identification des risques (Play Store, offline, Render, SMS).
- iOS ajouté au MVP. Repo déplacé hors OneDrive.
- Documentation initiale + ADR 0001 à 0005, revue des maquettes Figma v0 (problèmes de contraste,
  écrans manquants, transferts, soldes d'ouverture).
- Création de l'app Flutter (`com.kesbi.app`), thème, formatage FCFA.
- Commits poussés : `main`, `dev`, `feature/setup-mobile`.

---

## 8. Comment mettre à jour ce document
À la fin de chaque session :
1. Changer la date de « Dernière mise à jour ».
2. Mettre à jour les états (✅ 🟡 ⬜) des sections 2, 3 et 4.
3. Ajouter une entrée en haut du journal (section 7).
4. Ajouter toute nouvelle décision en section 6 (et un ADR si elle est structurante).
5. Commit : `docs(suivi): session du JJ/MM`.
