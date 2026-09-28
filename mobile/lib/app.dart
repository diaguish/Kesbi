import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

class KesBiApp extends StatelessWidget {
  const KesBiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kës Bi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _SetupCheckScreen(),
    );
  }
}

/// Écran temporaire pour vérifier le thème sur Android et iOS.
/// Remplacé par le parcours d'authentification (feature/auth-otp-pin).
class _SetupCheckScreen extends StatelessWidget {
  const _SetupCheckScreen();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kës Bi',
                style: text.displaySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('La caisse digitale', style: text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
