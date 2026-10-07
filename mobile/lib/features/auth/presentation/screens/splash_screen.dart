import 'package:flutter/material.dart';

import '../widgets/auth_scaffold.dart';

/// Affiché le temps de lire la session dans le stockage sécurisé.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KesbiLogo(),
            SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
