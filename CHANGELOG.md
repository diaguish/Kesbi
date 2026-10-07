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
- API Django `backend/` (ADR 0007) : vérification du JWT Supabase (JWKS / HS256), modèles
  Boutique et Membre, isolation par boutique, RLS sur les tables créées, `render.yaml`.
- Auth mobile (ADR 0003, 0008) : numéro +221 → OTP SMS Supabase → création du PIN, déverrouillage
  hors ligne, 5 erreurs → OTP, « PIN oublié », verrouillage après 3 min en arrière-plan,
  session dans le stockage sécurisé.
- API transactions (ADR 0009) : comptes Caisse / Wave / Orange Money, transactions à montant signé,
  création idempotente, annulation, soldes calculés, historique filtrable et paginé.
- Onboarding (A6, A7) : création de la boutique, soldes d'ouverture par compte (« Ignorer » = 0),
  reprise à la bonne étape ; Accueil provisoire avec les soldes.
- Profil et suppression de compte (A8, ADR 0010) : boutique, transactions et utilisateur Supabase.
- Encaissements (E1, E3, E4, E5 ; ADR 0011) : saisie, stockage local sqflite, synchronisation
  hors ligne (saisie, déverrouillage, premier plan, retour réseau), annulation, historique filtrable,
  soldes de l'Accueil calculés en local.
- Dépenses (D1, D2) : saisie (catégories dédiées, compte débité), hors ligne et synchronisation,
  annulation, confirmation si le compte deviendrait négatif, filtre Encaissements / Dépenses
  dans l'historique, bouton « − Dépense » sur l'Accueil.
