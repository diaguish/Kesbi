# 0008 — Auth mobile : stockage de session, hachage du PIN, verrouillage

- Statut : Accepté
- Date : 2026-10-07

## Contexte
L'ADR 0003 fixe le parcours (OTP SMS puis PIN local à 6 chiffres). Il reste à décider comment
l'implémenter dans l'app Flutter, sur des téléphones d'entrée de gamme, souvent hors ligne.

## Décision
**Session Supabase**
- `supabase_flutter` stocke par défaut la session (refresh token) dans les SharedPreferences,
  non chiffrées. On la place dans `flutter_secure_storage` (Keychain iOS / Keystore Android)
  via `SecureSessionStorage`.
- Le Keychain iOS survit à la désinstallation. Au premier lancement après installation
  (témoin dans les SharedPreferences, elles effacées avec l'app), le stockage sécurisé est vidé :
  une réinstallation repasse par l'OTP, comme le prévoit l'ADR 0003.
- Android : `allowBackup="false"` (une sauvegarde restaurée ne pourrait pas être déchiffrée).

**PIN**
- PBKDF2-HMAC-SHA256, sel aléatoire de 16 octets, **60 000 itérations**, calculé dans un isolate
  (≈ 0,3 s sur un Android d'entrée de gamme). Comparaison en temps constant.
- PIN refusés : chiffres tous identiques et suites (`123456`, `654321`…).
- 5 erreurs d'affilée → PIN et session effacés → retour à l'OTP.
- Un OTP validé efface toujours l'ancien PIN (nouvel appareil, PIN oublié).

**Verrouillage automatique** : après **3 minutes** en arrière-plan.

**Après le PIN** : `GET /api/me/` indique si la boutique existe (onboarding ou app). Le résultat
est mémorisé localement : les ouvertures suivantes fonctionnent hors ligne.

**Configuration** : URL Supabase, clé *publishable* et URL de l'API passées au build par
`--dart-define-from-file=env/<env>.json` (fichier ignoré par git, modèle `env/dev.example.json`).
En debug seulement, HTTP est autorisé vers `10.0.2.2` / `localhost` (API locale).

## Conséquences
- Le PIN protège l'accès à l'app, pas les données au repos : sa vraie protection est le stockage
  sécurisé du système. Un attaquant qui extrait le hash peut tester le million de PIN hors ligne ;
  les 60 000 itérations ne font que ralentir l'attaque. Acceptable au MVP (données sur le téléphone
  du commerçant ; chiffrement AES-256 des données locales à traiter dans un ADR dédié).
- Pas de délai croissant entre les essais : la limite de 5 essais suffit.
- Le parcours d'accès est entièrement testable sans réseau (fausses implémentations `AuthGateway`,
  `SecureStore`, `ApiClient`).
