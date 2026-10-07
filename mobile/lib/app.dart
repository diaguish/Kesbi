import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_status.dart';
import 'features/auth/presentation/auth_status_provider.dart';
import 'features/tresorerie/presentation/transactions_controller.dart';

/// Changements de réseau (remplacé dans les tests).
final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

class KesBiApp extends ConsumerStatefulWidget {
  const KesBiApp({super.key});

  @override
  ConsumerState<KesBiApp> createState() => _KesBiAppState();
}

class _KesBiAppState extends ConsumerState<KesBiApp> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<List<ConnectivityResult>>? _reseau;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Verrouillage automatique après un passage en arrière-plan (ADR 0003, A5).
      onHide: () => ref.read(authStatusProvider.notifier).onAppHidden(),
      onShow: () {
        ref.read(authStatusProvider.notifier).onAppShown();
        _synchroniser();
      },
    );
    // Déclencheurs de synchronisation (ADR 0002) : déverrouillage, retour au
    // premier plan, retour du réseau. workmanager en complément : S10.
    ref.listenManual(authStatusProvider, (_, status) {
      if (status == AuthStatus.ready) _synchroniser();
    });
    _reseau = ref.read(connectivityChangesProvider).listen((resultats) {
      if (resultats.any((r) => r != ConnectivityResult.none)) _synchroniser();
    });
  }

  void _synchroniser() {
    if (ref.read(authStatusProvider) == AuthStatus.ready) {
      unawaited(
        ref.read(transactionsControllerProvider.notifier).synchroniser(),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _reseau?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kës Bi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
