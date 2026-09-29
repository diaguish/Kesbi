import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_status_provider.dart';
import '../widgets/main_shell.dart';
import '../widgets/placeholder_screen.dart';
import 'routes.dart';

/// Routeur de l'app. Réévalue [authRedirect] à chaque changement d'état d'accès.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier(ref.read(authStatusProvider));
  ref.listen(authStatusProvider, (_, next) => authChanges.value = next);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: Routes.accueil,
    refreshListenable: authChanges,
    redirect: (context, state) =>
        authRedirect(authChanges.value, state.matchedLocation),
    routes: [
      // Écrans d'accès (remplacés par la feature auth).
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const PlaceholderScreen('Chargement'),
      ),
      GoRoute(
        path: Routes.otp,
        builder: (_, _) => const PlaceholderScreen('Connexion OTP'),
      ),
      GoRoute(
        path: Routes.pin,
        builder: (_, _) => const PlaceholderScreen('Code PIN'),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const PlaceholderScreen('Création boutique'),
      ),

      // App principale : 4 onglets, chacun garde sa propre pile d'écrans.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.accueil,
              builder: (_, _) => const PlaceholderScreen('Accueil'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.tresorerie,
              builder: (_, _) => const PlaceholderScreen('Trésorerie'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.creances,
              builder: (_, _) => const PlaceholderScreen('Créances'),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => PlaceholderScreen(
                    'Créance ${state.pathParameters['id']}',
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.rapport,
              builder: (_, _) => const PlaceholderScreen('Rapport'),
            ),
          ]),
        ],
      ),
    ],
  );
});
