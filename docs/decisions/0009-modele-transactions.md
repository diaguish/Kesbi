# 0009 — Modèle des transactions : montant signé, comptes sans table, annulation

- Statut : Accepté
- Date : 2026-10-07

## Contexte
Les ADR 0002 (offline-first, écritures immuables) et 0004 (comptes, ouverture, ajustement,
transferts) fixent les règles métier. Il reste à choisir leur représentation en base et dans l'API,
avant les soldes d'ouverture (onboarding) et les encaissements, qui reposent sur le même modèle.

## Décision
**Une seule table `transaction_financiere`** pour tous les types : `encaissement`, `depense`,
`ouverture`, `ajustement`, `transfert_sortie`, `transfert_entree`.

**Montant signé = effet sur le solde du compte** (FCFA, `bigint`).
- Encaissement, ouverture, transfert entrant : `> 0` (ouverture : `≥ 0`, « Ignorer » = 0).
- Dépense, transfert sortant : `< 0`. L'API attend aussi le montant signé (`-8000` pour une dépense).
- Ajustement : `≠ 0`, dans un sens ou dans l'autre.
- Solde d'un compte = `SUM(montant)`. Aucun cas particulier selon le type.
- Le signe est vérifié par l'API **et** par une contrainte `CHECK` en base.

**Pas de table « Compte »** : `compte` est une valeur fixe (`caisse`, `wave`, `orange_money`).
Rien à créer ni à synchroniser à l'onboarding ; ajouter « Banque » = ajouter une valeur.

**Annulation (E4)** : `POST /api/transactions/<id>/annuler/` crée une écriture de même type et de
montant opposé, liée par `annulation_de` (unique : une seule annulation par écriture). L'originale
n'est jamais modifiée. Une annulation, un solde d'ouverture (→ « Corriger le solde ») et un transfert
(→ Trésorerie, S6) ne s'annulent pas par cet endpoint.

**Idempotence** : `POST /api/transactions/` et l'annulation prennent un UUID généré par l'app.
Même UUID renvoyé → l'écriture existante est retournée (200) sans être modifiée ; UUID utilisé par
une autre boutique → 409.

**Un seul solde d'ouverture par compte** (contrainte unique conditionnelle).

**Pas de `PATCH` / `DELETE`** sur les transactions.

## Conséquences
- Chiffre d'affaires d'une période = somme des `encaissement` (annulations comprises, qui se
  neutralisent) ; dépenses = somme des `depense`. `ouverture`, `ajustement` et transferts sont exclus.
- Les transferts (S6) passeront par un endpoint dédié créant les deux écritures liées par
  `transfert_id` dans une même transaction SQL ; ils ne sont pas créables par `POST /api/transactions/`.
- Le lien client (créances, E2) sera ajouté avec le module Créances.
