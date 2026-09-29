# 0006 — Gestion d'état Riverpod et navigation go_router

- Statut : Accepté
- Date : 2026-09-29

## Contexte
Plusieurs écrans affichent les mêmes données (soldes, transactions) et doivent se
mettre à jour ensemble, y compris quand la synchronisation offline arrive. La navigation
doit imposer les écrans d'accès (OTP, PIN, onboarding), gérer 4 onglets et ouvrir un écran
précis depuis une notification FCM. La stack initiale ne tranchait pas ces choix.

## Décision
- **flutter_riverpod** (v3) pour la gestion d'état, **sans génération de code**
  (pas de `riverpod_generator` / `build_runner`) : moins d'outillage, plus simple à reprendre.
- **go_router** pour la navigation.
- **Une seule règle de garde** : la fonction pure `authRedirect()` dans
  `lib/core/router/routes.dart`, testée unitairement. Elle lit `authStatusProvider`.
- Les 4 onglets utilisent `StatefulShellRoute.indexedStack` : chaque onglet garde sa pile.
- Tous les chemins sont des constantes dans `Routes`. Les notifications FCM envoient un
  chemin (ex. `/creances/<uuid>`).

## Conséquences
- Tout nouvel écran d'accès ou protégé passe par `authRedirect()` + un test.
- Riverpod est le point de passage pour les données : les écrans ne lisent jamais
  sqflite ou l'API directement, ils passent par un provider → repository (`data/`).
- Alternatives écartées : Bloc (trop de code par écran pour une dev seule),
  GetX (maintenance incertaine, encourage un code peu structuré).
