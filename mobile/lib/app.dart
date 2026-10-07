import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_status_provider.dart';

class KesBiApp extends ConsumerStatefulWidget {
  const KesBiApp({super.key});

  @override
  ConsumerState<KesBiApp> createState() => _KesBiAppState();
}

class _KesBiAppState extends ConsumerState<KesBiApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Verrouillage automatique après un passage en arrière-plan (ADR 0003, A5).
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(authStatusProvider.notifier).onAppHidden(),
      onShow: () => ref.read(authStatusProvider.notifier).onAppShown(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
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
