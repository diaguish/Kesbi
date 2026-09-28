# Design — maquettes et règles UI

Source : [Figma Kës Bi](https://www.figma.com/design/wJg3VO7GCraQ69Ngsg4woU/Kes-bi)
Captures v0 (28/09/2026) : [maquettes/](maquettes/)

## Écrans maquettés (v0)
| Écran | Capture | Module / semaine |
|---|---|---|
| Connexion | v0-connexion-accueil-creance.png | Auth — S2 |
| Accueil | v0-connexion-accueil-creance.png | Dashboard — S5 |
| Détail créance | v0-creance-encaissement-tresorerie.png | Créances — S7 |
| Nouvel encaissement | v0-creance-encaissement-tresorerie.png | Encaissements — S3 |
| Trésorerie | v0-creance-encaissement-tresorerie.png | Trésorerie — S6 |
| Liste créances | v0-creances.png | Créances — S7 |

## Écrans manquants (à maquetter)
| Écran | Nécessaire pour |
|---|---|
| Inscription + saisie OTP | Auth — S2 |
| Création boutique + **soldes d'ouverture** par compte | Auth / onboarding — S2-S3 |
| Nouvelle dépense | S4 |
| Historique complet des transactions (filtres) | S3-S4 |
| **Transfert entre comptes** (ex. dépôt Caisse → Banque) | Trésorerie — S6 |
| Nouvelle créance (client, montant, **date d'échéance**) | S7 |
| Historique des paiements d'une créance | S7 |
| Aperçu du message de relance WhatsApp | S7 |
| Rapports | S9 |
| Profil / paramètres / **suppression de compte** | S2 (exigence stores) |

## Règles UI
- **Police** : Poppins, **embarquée dans les assets** (pas de chargement réseau — l'app doit marcher offline).
- **Montants** : entiers, séparateur de milliers espace, suffixe ` FCFA`. Formatage centralisé
  (un seul helper). Encaissement `+ 25 000 FCFA` (vert), dépense `− 8 000 FCFA` (rouge).
- **Contraste** : l'or `#D4A017` ne doit **jamais** servir de couleur de texte sur fond crème ni
  de fond sous du texte blanc (ratio ≈ 2:1, illisible en plein soleil). Or = fond avec texte
  `#0D2E1C`, ou élément décoratif.
- **Comptes** toujours affichés séparément : Caisse, Wave, Orange Money (Banque hors MVP — retirer des maquettes).
- **Connexion** : remplacer le champ « Mot de passe » par un parcours OTP puis PIN 6 chiffres (ADR 0003).
- Navigation : 4 onglets (Accueil, Trésorerie, Créances, Rapport). Profil / paramètres
  accessibles depuis l'en-tête de l'Accueil.
- Chaque donnée affichée hors ligne indique son état (« Mis à jour à 14h32 », « en attente de sync »).
