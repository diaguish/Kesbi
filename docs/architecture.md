# Architecture

## Vue d'ensemble
```
┌──────────────────────────┐        HTTPS + JWT        ┌─────────────────┐
│  App Flutter             │ ────────────────────────▶ │  API Django     │
│  (Android + iOS)         │                           │  (Render)       │
│  - sqflite (offline)     │                           └────────┬────────┘
│  - secure storage (JWT)  │                                    │ SQL
│  - workmanager (sync)    │                                    ▼
└──┬──────────────┬────────┘                           ┌─────────────────┐
   │ Auth OTP     │ Realtime (lecture, RLS)            │  Supabase       │
   └──────────────┴──────────────────────────────────▶ │  Postgres/Auth  │
                                                       └─────────────────┘
   ▲ Push (FCM → APNs pour iOS)          ┌─────────────────┐
   └──────────────────────────────────── │  Firebase FCM   │ ◀── Django
                                         └─────────────────┘
```

## Responsabilités
| Composant | Rôle |
|---|---|
| Flutter | UI, stockage local, file de sync, auth OTP via SDK Supabase |
| Supabase Auth | Inscription/connexion par OTP SMS, émission du JWT |
| Django | **Toute la logique métier et toutes les écritures**, vérification du JWT, PDF, envoi FCM |
| Supabase Postgres | Source de vérité |
| Supabase Realtime | Push des changements vers le dashboard (lecture seule côté client) |
| FCM | Notifications (rappels créances) |

## Sécurité — points critiques
- **Django vérifie le JWT Supabase** à chaque requête (middleware DRF, JWKS / secret du projet).
- Django se connecte à Postgres avec un rôle privilégié → **RLS ne s'applique pas à Django**.
  Chaque queryset DOIT être filtré par `boutique_id` de l'utilisateur authentifié
  (mixin commun obligatoire sur toutes les vues).
- RLS activée sur toutes les tables pour les accès directs client (Realtime).
- Le client n'écrit **jamais** directement dans Supabase (sauf Auth).
- Clés AES-256 : jamais dans l'APK/IPA. À préciser dans un ADR dédié (quelles données, où vit la clé).

## Flux d'écriture (offline-first)
Voir [ADR 0002](decisions/0002-schema-offline-first.md).
1. L'app génère un UUID, écrit en local (sqflite) avec `sync_status = pending`.
2. La file de sync envoie à Django (idempotent sur l'UUID).
3. Django valide, écrit dans Postgres, répond → `sync_status = synced`.
4. Realtime notifie les autres vues.

Déclencheurs de sync : ouverture de l'app, retour au premier plan, retour du réseau,
workmanager (complément — **non garanti sur iOS**).
