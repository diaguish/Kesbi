# 0011 — Synchronisation hors ligne des transactions

- Statut : Accepté
- Date : 2026-10-07

## Contexte
L'ADR 0002 fixe le principe (UUID client, écritures immuables, API idempotente). Les encaissements
(S3) sont la première saisie qui doit marcher sans réseau : il faut décider où vivent les données
sur le téléphone, quand on synchronise et comment on traite les erreurs.

## Décision
**Stockage local** : table `transactions` dans sqflite (`kesbi.db`), copie de l'API + `sync_status`
(`pending` / `synced` / `error`). Les écrans (soldes, historique, détail) lisent **uniquement** la
base locale : tout s'affiche hors ligne. Les soldes locaux incluent les écritures en attente et
excluent celles refusées par le serveur.

**Écriture** : saisie → insertion locale `pending` → synchronisation lancée en arrière-plan.
Une annulation est une écriture locale `pending` avec `annulation_de`, envoyée sur
`POST /api/transactions/<id>/annuler/`.

**Synchronisation** (`SyncService`) :
1. envoi des écritures `pending` dans l'ordre de création (une annulation après son originale) ;
2. récupération des 200 dernières écritures du serveur (nouvel appareil, réinstallation) —
   sans jamais écraser une écriture locale, seulement son état.
- Réseau absent, 401, 408, 429, 5xx → arrêt, on réessaiera (l'écriture reste `pending`).
- Autre refus (400…) → `error` avec le message du serveur, visible dans le détail ; les écritures
  suivantes continuent.
- Ne lève jamais d'exception (lancée en arrière-plan).

**Déclencheurs** : après chaque saisie, déverrouillage (état `ready`), retour au premier plan,
retour du réseau (`connectivity_plus`), « tirer pour actualiser ». workmanager (non garanti sur iOS) : S10.

**Déconnexion / suppression de compte** : la base locale est vidée.

## Conséquences
- Historique complet au-delà des 200 dernières écritures (pagination par curseur) : S10.
- Une écriture en `error` n'est pas renvoyée automatiquement : correction = nouvelle saisie.
- Les dépenses (S4) réutilisent tel quel ce mécanisme (type `depense`, montant négatif).
- Pas de chiffrement de la base locale au MVP : protégée par le PIN et le stockage de l'app
  (ADR AES-256 à rédiger, voir architecture).
