import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Logo texte Kës Bi (en attendant le logo définitif).
class KesbiLogo extends StatelessWidget {
  const KesbiLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Kës Bi',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        // Pas d'or en texte sur fond crème (contraste, docs/design/README.md).
        Text(
          'La caisse digitale',
          style: TextStyle(fontSize: 15, color: AppColors.textDark),
        ),
      ],
    );
  }
}

/// Mise en page commune aux écrans d'accès : logo, titre, sous-titre, contenu.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showLogo = true,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showLogo;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: leading == null ? null : AppBar(leading: leading),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showLogo) ...[const KesbiLogo(), const SizedBox(height: 32)],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: AppColors.textDark),
                    ),
                  ],
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Message d'erreur sous un formulaire.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        message!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
      ),
    );
  }
}
