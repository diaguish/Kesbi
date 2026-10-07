# 0007 — Backend : vérification du JWT Supabase et isolation par boutique

- Statut : Accepté
- Date : 2026-10-01

## Contexte
Django écrit toutes les données métier dans le Postgres de Supabase (architecture). Il s'y
connecte avec un rôle privilégié : **la RLS ne le protège pas**. Une seule requête oubliant
de filtrer par boutique exposerait les données d'un autre commerçant.
Par ailleurs, Supabase expose automatiquement le schéma `public` par son API REST, avec la
clé `anon` présente dans l'app : toute table créée par Django sans RLS y serait accessible.

## Décision
**Identité**
- L'app envoie le JWT Supabase (`Authorization: Bearer`). Django le vérifie à chaque requête
  (`core.authentication.SupabaseJWTAuthentication`) : signature, `exp`, `aud = authenticated`,
  `iss = <SUPABASE_URL>/auth/v1`, `sub` obligatoire, sessions anonymes refusées.
- Signature asymétrique (ES256/RS256) vérifiée via le **JWKS** public du projet (mis en cache
  5 min) ; HS256 accepté seulement si `SUPABASE_JWT_SECRET` est configuré (projet « legacy »).
  Aucun autre algorithme (`none` compris).
- Pas de table utilisateur Django ni `django.contrib.auth` / admin / sessions : l'utilisateur
  est l'UUID `sub` de Supabase. Moins de tables dans `public`, moins de surface d'attaque.

**Isolation**
- Lien utilisateur ↔ boutique : table `boutique_membre` (rôle `proprietaire`). Prête pour le
  multi-utilisateur (P2) ; au MVP une seule boutique par utilisateur, imposée par l'API.
- Toute vue métier utilise `core.scoping.BoutiqueScopedMixin` : queryset filtré par la boutique
  de l'utilisateur et hors suppressions logiques, `boutique` imposée à la création (jamais lue
  dans le corps de la requête). Les modèles métier héritent de `core.models.BoutiqueScopedModel`.
- Boutique d'un autre utilisateur → **404** (on ne révèle pas son existence).

**RLS**
- Chaque migration qui crée une table appelle `core.db.enable_rls(...)` : RLS activée sans
  politique = accès refusé aux rôles `anon` / `authenticated` via l'API Supabase. Django,
  propriétaire des tables, n'est pas concerné. Les politiques de lecture nécessaires à
  Realtime seront ajoutées table par table (S5).

## Conséquences
- Un test d'isolation (utilisateur A ne voit pas la boutique de B) accompagne chaque nouvelle vue métier.
- Pas d'interface d'administration Django : consultation via le tableau de bord Supabase.
- Si Supabase fait tourner ses clés de signature, le JWKS est relu automatiquement (cache 5 min).
- Render (offre gratuite) n'a pas d'IPv6 : connexion à Postgres par le **Session pooler** Supabase.
