# 0003 — Authentification : OTP SMS + code PIN local

- Statut : Accepté
- Date : 2026-09-28

## Contexte
Les commerçants ne gèrent pas bien les mots de passe, et chaque SMS OTP a un coût.
Première idée : utiliser le PIN à 6 chiffres comme mot de passe Supabase. **Rejetée** :
un PIN à 6 chiffres = 1 million de combinaisons, et l'endpoint de connexion par mot de
passe de Supabase est public. Quelqu'un qui connaît le numéro d'un commerçant pourrait
tenter les PIN à distance.

## Décision
- **Identité côté serveur = numéro de téléphone + OTP SMS** (Supabase Auth, phone OTP).
  La connexion par mot de passe est **désactivée** dans Supabase.
- **Le PIN ne quitte jamais le téléphone.** Il sert uniquement à déverrouiller l'app.
  Stocké haché (avec sel) dans `flutter_secure_storage` (Keychain iOS / Keystore Android).
- La session Supabase (refresh token) est conservée dans `flutter_secure_storage`.

| Situation | Parcours | SMS ? |
|---|---|---|
| Inscription | Numéro → OTP → création PIN → création boutique → soldes d'ouverture | Oui |
| Ouverture de l'app (usage quotidien) | Saisie PIN (fonctionne hors ligne) | Non |
| Nouvel appareil / session expirée / réinstallation | Numéro → OTP → création PIN | Oui |
| PIN oublié | Numéro → OTP → nouveau PIN | Oui |
| 5 PIN faux d'affilée | Session effacée localement → retour à l'OTP | Oui |

## Conséquences
- Le PIN fonctionne hors ligne (vérification locale).
- Un vol de téléphone déverrouillé reste un risque : verrouillage automatique de l'app
  après quelques minutes en arrière-plan.
- Biométrie (empreinte / Face ID) possible plus tard en complément du PIN, sans changer ce modèle.
- Fournisseur SMS à choisir et tester sur Orange, Free, Expresso (+221) — coût par SMS à budgéter.
- Rate limiting OTP à configurer dans Supabase (anti-abus / coût SMS).
