# 0001 — Plateformes cibles : Android + iOS au MVP

- Statut : Accepté
- Date : 2026-09-28

## Contexte
Le périmètre initial plaçait l'App Store en phase 2. Décision de livrer les deux
plateformes pour le MVP du 1er décembre 2026. Un Mac est disponible pour les builds iOS.

## Décision
- Android (Play Store) et iOS (App Store) publiés au MVP.
- Builds iOS faits sur le Mac de la CTO.
- Chaque feature est testée sur les deux plateformes avant merge dans `dev`.

## Conséquences
- Comptes Apple Developer (99 $/an) et Play Console (25 $) à ouvrir en S2.
- Bundle ID / applicationId figé dès la création du projet Flutter (non modifiable après publication).
- **iOS : les tâches en arrière-plan (workmanager) ne sont pas garanties** → la sync
  doit aussi se déclencher à l'ouverture, au retour au premier plan et au retour réseau.
- FCM sur iOS nécessite une clé APNs (.p8) dans Firebase + capabilities Push et Background Modes.
- Deep link WhatsApp : déclarer `whatsapp` dans `LSApplicationQueriesSchemes` (Info.plist).
- Suppression de compte depuis l'app obligatoire (Apple et Google).
- Privacy Manifest + Privacy Nutrition Labels + URL de politique de confidentialité.
- Review Apple (1-3 j, refus possible) → 1ère soumission prévue en S8.
- Play Store (compte personnel récent) : test fermé 12 testeurs / 14 jours → lancement en S6.
