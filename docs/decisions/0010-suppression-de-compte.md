# 0010 — Suppression de compte

- Statut : Accepté
- Date : 2026-10-07

## Contexte
Apple et Google exigent que l'utilisateur puisse supprimer son compte **depuis l'app** (A8).
Le compte existe à deux endroits : l'utilisateur Supabase Auth (numéro de téléphone) et les
données métier dans Postgres (boutique, membres, transactions).

## Décision
- Écran **Profil** (icône dans l'en-tête de l'Accueil) → « Supprimer mon compte » → confirmation
  forte : il faut taper `SUPPRIMER`.
- `DELETE /api/compte/` (Django), dans **une seule transaction SQL** :
  1. suppression des boutiques de l'utilisateur (cascade : membres, transactions) ;
  2. suppression de l'utilisateur Supabase via l'API d'administration
     (`DELETE /auth/v1/admin/users/<id>`), avec la clé secrète `SUPABASE_SECRET_KEY`.
  Si Supabase échoue, la transaction SQL est annulée : **rien n'est effacé** (503).
  Utilisateur déjà absent chez Supabase (404) = succès : l'appel est rejouable.
- Suppression **définitive** (pas de suppression logique) : c'est ce que l'utilisateur demande.
- L'app n'efface ses données locales (session, PIN, stockage sécurisé) **qu'après** la réponse
  du serveur. Hors ligne : message d'erreur, rien n'est effacé.
- La clé secrète Supabase n'existe que côté serveur (variable d'environnement Render), jamais
  dans l'app ni dans le dépôt.

## Conséquences
- `annulation_de` est en `RESTRICT` (et non `PROTECT`) pour permettre la cascade (ADR 0009).
- Le JWT déjà émis reste valide jusqu'à son expiration (≤ 1 h), mais ne donne plus accès à
  aucune boutique.
- Multi-utilisateur (P2) : ne supprimer que les boutiques dont l'utilisateur est le seul
  propriétaire.
- Le dépôt d'une politique de confidentialité (X5) devra décrire cette suppression.
