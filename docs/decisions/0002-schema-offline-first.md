# 0002 — Schéma de données offline-first

- Statut : Accepté
- Date : 2026-09-28

## Contexte
Le mode offline est planifié en S10 mais conditionne la forme du schéma. Un commerçant
doit pouvoir enregistrer une vente sans réseau ; les données doivent se synchroniser
sans doublon ni perte. Le retrofit d'un schéma non prévu obligerait à réécrire
Encaissements et Décaissements.

## Décision
Toutes les tables métier suivent ces règles dès leur création :

| Champ | Type | Règle |
|---|---|---|
| `id` | UUID | **Généré par le client**, clé primaire. Sert de clé d'idempotence. |
| `boutique_id` | UUID | Obligatoire, filtre de toutes les requêtes |
| `created_at` | timestamptz UTC | Heure de création **côté appareil** |
| `updated_at` | timestamptz UTC | Mis à jour à chaque modification |
| `deleted_at` | timestamptz UTC, nullable | Suppression logique uniquement |
| `montant` | bigint | FCFA, entier, jamais de float |

Côté mobile (sqflite), en plus : `sync_status` (`pending` / `synced` / `error`).

Règles de synchronisation :
- L'API accepte un `POST` avec un UUID déjà connu → renvoie l'existant (idempotence), pas d'erreur ni de doublon.
- **Les transactions financières sont immuables** : pas de modification de montant ;
  une correction = une écriture d'annulation + une nouvelle écriture. Supprime la
  quasi-totalité des conflits.
- Données non financières (clients, libellés) : dernière écriture gagne (`updated_at`).
- Les soldes de comptes sont **calculés** (somme des transactions), jamais stockés.

## Conséquences
- Pas d'ID auto-incrémenté côté serveur pour les entités métier.
- Les écrans doivent afficher l'état de sync (en attente / synchronisé).
- Un historique d'annulations visible pour l'utilisateur (traçabilité, utile aussi au futur scoring P3).
