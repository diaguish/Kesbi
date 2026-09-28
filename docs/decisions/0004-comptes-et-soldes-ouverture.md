# 0004 — Comptes du MVP et soldes d'ouverture

- Statut : Accepté
- Date : 2026-09-28

## Contexte
Les comptes prévus étaient Caisse, Wave, Orange Money, Banque. Le commerçant a déjà de
l'argent le jour où il installe l'app.

## Décision
**Comptes MVP : Caisse, Wave, Orange Money.** Le compte Banque est retiré du MVP
(réintroductible plus tard sans migration lourde : le type de compte est une valeur d'enum).

**Soldes d'ouverture** : étape d'onboarding après la création de la boutique.
- L'utilisateur saisit le montant actuel de chaque compte, ou appuie sur « Ignorer ».
- « Ignorer » = solde d'ouverture à 0.
- Chaque solde d'ouverture est enregistré comme une **transaction de type `ouverture`**
  (cohérent avec la règle « soldes calculés depuis les transactions »).
- Une transaction `ouverture` n'est comptée ni comme encaissement ni comme dépense
  dans le dashboard et les rapports.

**Transferts entre comptes** (décidé le 28/09/2026) : inclus au MVP, module Trésorerie (S6).
- Cas d'usage : dépôt d'espèces sur Wave/OM chez un agent, retrait pour remplir la caisse,
  Wave ↔ Orange Money.
- Écran : compte de départ, compte d'arrivée, montant, frais (optionnel), date.
- Stockage : **deux transactions liées** par un même `transfert_id` (une sortie, une entrée),
  créées ensemble de façon atomique. Elles ne sont comptées **ni** comme encaissement **ni**
  comme dépense.
- **Frais** (ex. frais de retrait Wave / Orange Money) : s'ils sont saisis, ils créent une
  vraie dépense de catégorie « Frais de transfert » sur le compte de départ. C'est de
  l'argent réellement perdu, il doit apparaître dans les dépenses.
- Compte de départ = compte d'arrivée : refusé.

**Correction de solde** (décidé le 28/09/2026) : bouton « Corriger le solde » dans Trésorerie.
- L'utilisateur saisit le montant réel du compte.
- L'app enregistre la différence (positive ou négative) comme une transaction `ajustement`,
  visible dans l'historique. Le solde n'est jamais modifié directement.
- Une transaction `ajustement` n'est comptée ni comme encaissement ni comme dépense.

## Conséquences
- Types de transaction : `encaissement`, `depense`, `ouverture`, `ajustement`,
  `transfert_sortie`, `transfert_entree`.
  Seuls `encaissement` et `depense` entrent dans le chiffre d'affaires et les dépenses.
- Des ajustements fréquents signalent des oublis de saisie : information utile à afficher
  plus tard (et pour le scoring P3).
