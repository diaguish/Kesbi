# Validation de `feature/setup-backend`

Deux parties : **A. ce que Diago doit faire** (hors code), puis **B. le protocole de test**
à dérouler avant d'ouvrir la PR vers `dev`. Cocher au fur et à mesure.

Projet Supabase de dev : ref `ubpvgafdhjnsimffybnd` — `https://ubpvgafdhjnsimffybnd.supabase.co`.

---

## A. Actions à faire (dans l'ordre)

### A1. Autoriser le MCP Supabase
- [ ] Ouvrir un terminal dans `C:\dev\Kesbi`, lancer `claude`, taper `/mcp`, choisir `supabase` → se connecter.
- [ ] (Recommandé) Ajouter `&read_only=true` à l'URL dans `.mcp.json` tant que le projet n'est pas
      strictement réservé au dev (voir risques dans `suivi-projet.md`).
- [ ] Relancer la session Claude Code.

### A2. Supabase — réglages du projet
- [ ] **Région** : Project Settings → General → noter la région (à reporter dans `suivi-projet.md`).
      Si elle n'est pas en Europe (`eu-central-1`, `eu-west-*`), le dire : la région Render
      (`frankfurt` dans `render.yaml`) devra suivre.
- [ ] **Clés JWT** : Project Settings → JWT Keys.
  - Clé courante **ECC (P-256)** ou **RSA** → rien à faire, `SUPABASE_JWT_SECRET` reste vide.
  - Seulement « Legacy JWT secret (HS256) » → de préférence migrer vers les clés asymétriques ;
    sinon copier le secret dans `SUPABASE_JWT_SECRET` du `.env` (jamais commité).
- [ ] **Auth → Sign In / Providers → Phone** : activer. Si un fournisseur SMS est exigé pour
      enregistrer, utiliser un compte d'essai (ex. Twilio) en attendant le choix définitif.
- [ ] **Numéros de test** (même écran, « Test phone numbers ») : ajouter
      `221770000000=123456` et `221770000001=123456` (2 utilisateurs pour tester l'isolation).
- [ ] **Désactiver la connexion par mot de passe / e-mail** (ADR 0003), sauf plan B du test B3.
- [ ] **Clé publique de l'app** : Project Settings → API Keys → copier la clé *publishable*
      (`sb_publishable_…`) ou *anon*. Elle sert aux tests B3/B6 (pas un secret, mais ne pas la commiter).

### A3. Connexion à la base
- [ ] Project Settings → Database → récupérer (ou réinitialiser) le **mot de passe** de la base.
- [ ] Bouton **Connect** → onglet *Connection string* → mode **Session pooler** → copier l'URI
      (`postgresql://postgres.ubpvgafdhjnsimffybnd:[PASSWORD]@aws-0-<region>.pooler.supabase.com:5432/postgres`).
      Ne pas prendre « Direct connection » : IPv6 seulement, incompatible Render.

### A4. Fichier `.env` local
- [ ] `cp backend/.env.example backend/.env` puis remplir :
  `DJANGO_DEBUG=true`, `DATABASE_URL=<URI Session pooler>?sslmode=require`,
  `SUPABASE_URL=https://ubpvgafdhjnsimffybnd.supabase.co`, et `SUPABASE_JWT_SECRET` seulement si A2 l'exige.
- [ ] Vérifier que `git status` **n'affiche pas** `backend/.env`.

### A5. Render (après le merge dans `main`)
`render.yaml` déploie depuis `main` : le service ne pourra tourner qu'après la release `dev → main`.
- [ ] Créer le compte Render.
- [ ] New → **Blueprint** → repo `diaguish/Kesbi` → renseigner `DATABASE_URL` et `SUPABASE_URL`.
- [ ] Dérouler le test B8.

### A6. Divers
- [ ] Me dire si je peux pousser `feature/setup-backend` et `dev` sur GitHub.
- [ ] Quand B1 à B7 sont verts : ouvrir la PR `feature/setup-backend → dev`.

---

## B. Protocole de test

Toutes les commandes se tapent **dans un même terminal Git Bash** (les variables doivent persister),
depuis `C:\dev\Kesbi\backend`. Résultat attendu à droite ; si un résultat diffère → s'arrêter et me
copier la sortie.

### B1. Tests automatiques (SQLite, sans Supabase)
```bash
DJANGO_DEBUG=true DATABASE_URL= .venv/Scripts/python manage.py test
```
- [ ] `Ran 23 tests` … `OK`

### B2. Contrôles de configuration
```bash
DJANGO_DEBUG=false DJANGO_SECRET_KEY=$(.venv/Scripts/python -c "import secrets;print(secrets.token_urlsafe(50))") .venv/Scripts/python manage.py check --deploy
```
- [ ] `System check identified no issues (3 silenced).`
```bash
git -C .. status --short
```
- [ ] Aucun `.env`, `db.sqlite3` ou `.venv` dans la liste.

### B3. Obtenir un vrai JWT Supabase
```bash
SUPABASE_URL=https://ubpvgafdhjnsimffybnd.supabase.co
ANON_KEY=colle-ici-la-cle-publishable-ou-anon
curl -s -X POST "$SUPABASE_URL/auth/v1/otp" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{"phone":"+221770000000"}'
```
- [ ] Réponse `{}` (aucun SMS envoyé : numéro de test).
```bash
TOKEN_A=$(curl -s -X POST "$SUPABASE_URL/auth/v1/verify" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{"type":"sms","phone":"+221770000000","token":"123456"}' | .venv/Scripts/python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
.venv/Scripts/python -c "import jwt,sys;print(jwt.get_unverified_header(sys.argv[1]))" "$TOKEN_A"
```
- [ ] Un en-tête s'affiche avec `'alg': 'ES256'` (ou `RS256`). Si `HS256` → `SUPABASE_JWT_SECRET` requis (A2).

Recommencer pour le 2ᵉ utilisateur (`+221770000001`) en stockant dans `TOKEN_B`.

> **Plan B** si le provider Phone ne peut pas être activé : activer temporairement Email,
> créer un utilisateur dans Authentication → Users (« Auto confirm »), puis
> `curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{"email":"…","password":"…"}'`
> et lire `access_token`. **Désactiver Email ensuite** (ADR 0003).

### B4. Migration sur Supabase
```bash
.venv/Scripts/python manage.py migrate
```
- [ ] `Applying boutiques.0001_initial... OK` et `Applying core.0001_enable_rls_django_migrations... OK`

Dans Supabase → SQL Editor :
```sql
select relname, relrowsecurity from pg_class
where relname in ('boutique', 'boutique_membre', 'django_migrations');
```
- [ ] 3 lignes, `relrowsecurity = true` partout.

### B5. API locale branchée sur Supabase
Dans un **second** terminal : `cd /c/dev/Kesbi/backend && .venv/Scripts/python manage.py runserver 0.0.0.0:8000`.
Puis, dans le premier :
```bash
API=http://localhost:8000
BOUTIQUE_ID=$(.venv/Scripts/python -c "import uuid;print(uuid.uuid4())")
```

| # | Commande | Attendu | OK |
|---|---|---|---|
| 1 | `curl -s $API/api/health/` | `{"status":"ok"}` | [ ] |
| 2 | `curl -s -o /dev/null -w "%{http_code}\n" $API/api/me/` | `401` | [ ] |
| 3 | `curl -s $API/api/me/ -H "Authorization: Bearer $TOKEN_A"` | `id` = UUID de l'utilisateur (Authentication → Users), `boutiques: []` | [ ] |
| 4 | `curl -s -o /dev/null -w "%{http_code}\n" $API/api/me/ -H "Authorization: Bearer ${TOKEN_A}x"` | `401` (jeton altéré) | [ ] |
| 5 | `curl -s -w "\n%{http_code}\n" -X POST $API/api/boutiques/ -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -d "{\"id\":\"$BOUTIQUE_ID\",\"nom\":\"Boutique Test A\",\"activite\":\"Alimentation\"}"` | la boutique, puis `201` | [ ] |
| 6 | même commande que 5 (rejeu) | même boutique, puis `200` | [ ] |
| 7 | commande 5 avec un autre UUID (`$(…uuid4())`) | `409` (une seule boutique) | [ ] |
| 8 | `curl -s $API/api/boutique/ -H "Authorization: Bearer $TOKEN_A"` | `Boutique Test A` | [ ] |
| 9 | `curl -s -X PATCH $API/api/boutique/ -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -d '{"nom":"Boutique A renommée"}'` | nom modifié, même `id` | [ ] |

Dans Supabase → Table Editor :
- [ ] 1 ligne dans `boutique` (id = `$BOUTIQUE_ID`), 1 ligne dans `boutique_membre` (`user_id` = utilisateur A, rôle `proprietaire`).
- [ ] `created_at` / `updated_at` en UTC (`+00`).

### B6. Isolation et exposition des données
| # | Commande | Attendu | OK |
|---|---|---|---|
| 1 | `curl -s -o /dev/null -w "%{http_code}\n" $API/api/boutique/ -H "Authorization: Bearer $TOKEN_B"` | `404` (B n'a pas de boutique) | [ ] |
| 2 | même chose avec `-H "X-Boutique-Id: $BOUTIQUE_ID"` | `404` (ne voit pas celle de A) | [ ] |
| 3 | commande B5-5 avec `$TOKEN_B` (même UUID que A) | `409` | [ ] |
| 4 | `curl -s "$SUPABASE_URL/rest/v1/boutique?select=*" -H "apikey: $ANON_KEY"` | `[]` ou erreur de permission — **jamais la boutique** | [ ] |
| 5 | même chose avec en plus `-H "Authorization: Bearer $TOKEN_A"` | `[]` ou erreur — **jamais la boutique** | [ ] |
| 6 | `curl -s -X POST "$SUPABASE_URL/rest/v1/boutique" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{"id":"00000000-0000-0000-0000-000000000001","nom":"pirate"}'` | erreur (`42501` / row-level security) | [ ] |

Les tests 4 à 6 vérifient que le contenu des tables Django n'est pas accessible par l'API publique de Supabase.

### B7. Depuis l'émulateur Android
- [ ] Ouvrir Chrome dans l'émulateur → `http://10.0.2.2:8000/api/health/` → `{"status":"ok"}`.
      (L'app n'appelle pas encore l'API : branchement dans `feature/auth-otp-pin`.)

### B8. Sur Render (après déploiement depuis `main`)
```bash
API=https://kesbi-api.onrender.com
```
(adapter au nom affiché par Render)
- [ ] Le déploiement est vert ; les logs du build montrent `migrate` sans erreur.
- [ ] `curl -s $API/api/health/` → `{"status":"ok"}` (premier appel jusqu'à ~50 s : mise en veille du plan gratuit).
- [ ] `http://…` redirige vers `https://…` (sauf `/api/health/`).
- [ ] `/api/me/` → `401` sans jeton, `200` avec `$TOKEN_A` (régénérer s'il a plus d'une heure).

### B9. Nettoyage
- [ ] Supabase → SQL Editor (les membres d'abord : la cascade est gérée par Django, pas par Postgres) :
  ```sql
  delete from boutique_membre where boutique_id in (select id from boutique where nom like 'Boutique%');
  delete from boutique where nom like 'Boutique%';
  ```
- [ ] Si le plan B a été utilisé : désactiver Email et supprimer l'utilisateur de test.
- [ ] Fermer les terminaux (les jetons ne doivent pas traîner dans un fichier).

### Critère de passage
**B1 à B7 tous cochés** → PR `feature/setup-backend → dev`. B8 se fait à la première release vers `main`.
La règle « testé sur Android ET iOS » ne s'applique pas ici (aucun changement dans l'app) ; B7 suffit.
