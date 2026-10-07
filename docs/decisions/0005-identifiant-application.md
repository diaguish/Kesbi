# 0005 — Identifiant de l'application : `com.kesbi.app`

- Statut : Accepté
- Date : 2026-09-28

## Contexte
Les stores identifient une app par son `applicationId` (Android) et son Bundle ID (iOS).
Cet identifiant est aussi utilisé par Firebase, Supabase (redirections) et les liens profonds.
Il ne peut plus être changé après la première publication : changer = publier une autre app.

## Décision
- `applicationId` Android et Bundle ID iOS : **`com.kesbi.app`**.
- Préfixe `com.` plutôt que `sn.` pour ne pas lier l'app au Sénégal (expansion future).
- Le `namespace` Android (package Kotlin interne, `com.kesbi.kesbi`) est distinct et sans
  impact sur les stores ; il n'est pas modifié.
- Nom affiché : « Kës Bi ».

## Conséquences
- Enregistrer `com.kesbi.app` dans Firebase (apps Android et iOS) et sur le portail Apple Developer.
- Ne jamais modifier ces valeurs après la première publication.
