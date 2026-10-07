import 'package:flutter/material.dart';

/// Écran temporaire en attendant l'implémentation d'un module.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title — à venir', style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
