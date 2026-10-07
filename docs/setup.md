# Installation de l'environnement

## Versions de référence
| Outil | Version |
|---|---|
| Flutter | 3.47.5 (stable) — **identique sur Windows et Mac** |
| Python | 3.13 |
| Xcode | dernière stable (Mac uniquement) |

> Si la version Flutter change, mettre à jour ce tableau dans le même commit.

## Windows (dev Android + backend)
- Flutter SDK, Android SDK, un émulateur ou un téléphone Android
- Python 3.13
- `flutter doctor` sans erreur sur la partie Android

## Mac (build et tests iOS)
```bash
xcode-select --install
brew install cocoapods
flutter doctor
```
- Un iPhone physique est nécessaire pour les notifications push et les tests offline réels.
- Ouvrir `mobile/ios/Runner.xcworkspace` (pas `.xcodeproj`) pour la signature.

## Backend
Django 5.2 LTS + DRF, dans `backend/`. Sans `DATABASE_URL`, utilise SQLite en local.
```bash
cd backend
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt   # Mac : .venv/bin/pip
cp .env.example .env                            # puis DJANGO_DEBUG=true pour le local
.venv/Scripts/python manage.py migrate
.venv/Scripts/python manage.py test
.venv/Scripts/python manage.py runserver 0.0.0.0:8000
```
- Émulateur Android → API locale : `http://10.0.2.2:8000`. Simulateur iOS : `http://localhost:8000`.
- Endpoints : `GET /api/health/` (public), `GET /api/me/`, `POST /api/boutiques/`, `GET|PATCH /api/boutique/`,
  `GET /api/comptes/` (soldes calculés), `GET|POST /api/transactions/`, `GET /api/transactions/<id>/`,
  `POST /api/transactions/<id>/annuler/` ([ADR 0009](decisions/0009-modele-transactions.md)),
  `DELETE /api/compte/` (suppression de compte, [ADR 0010](decisions/0010-suppression-de-compte.md) —
  nécessite `SUPABASE_SECRET_KEY` dans `.env`, sinon 503).
- **Sans 4G** (réseau qui bloque le port 5432) : laisser `DATABASE_URL` vide → SQLite local.
  L'API vérifie quand même les vrais JWT Supabase (JWKS en HTTPS) : suffisant pour développer l'app.
- Auth et isolation par boutique : [ADR 0007](decisions/0007-backend-auth-jwt-et-isolation.md).
  Toute nouvelle vue métier utilise `BoutiqueScopedMixin` ; toute nouvelle table, `enable_rls()`.
- Déploiement : `render.yaml` (Blueprint Render, `rootDir: backend`, deploy depuis `main`).
  Variables secrètes à saisir dans Render : `DATABASE_URL` (Supabase **Session pooler**), `SUPABASE_URL`.
- `gunicorn` ne tourne pas sous Windows : en local, utiliser `runserver`.

## Mobile
Voir [mobile/README.md](../mobile/README.md).
```bash
cd mobile
flutter pub get
flutter test
flutter run
```
Sur Mac, avant le premier `flutter run` iOS : ouvrir `mobile/ios/Runner.xcworkspace`
dans Xcode, onglet *Signing & Capabilities*, choisir ton équipe Apple Developer.

## Secrets
Chaque dossier fournit un `.env.example`. Copier en `.env` et remplir.
Les fichiers Firebase (`google-services.json`, `GoogleService-Info.plist`) sont
à récupérer depuis la console Firebase — ils ne sont pas dans le repo.
