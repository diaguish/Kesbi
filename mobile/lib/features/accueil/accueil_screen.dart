import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../tresorerie/domain/compte.dart';

/// Soldes calculés par l'API (en ligne). Remplacé par le dashboard hors ligne en S5.
final soldesProvider = FutureProvider.autoDispose<Map<Compte, int>>((ref) async {
  final data = await ref.watch(apiClientProvider).getJson('/api/comptes/');
  return {
    for (final c in (data['comptes'] as List).cast<Map<String, dynamic>>())
      Compte.fromApi(c['compte'] as String): c['solde'] as int,
  };
});

/// Accueil provisoire : soldes par compte et accès au profil (dashboard complet en S5).
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soldes = ref.watch(soldesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.profil),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(soldesProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            switch (soldes) {
              AsyncData(:final value) => _CarteSoldes(value),
              AsyncError(:final error) => Card(
                  child: ListTile(
                    title: Text(ApiClient.messageFor(error)),
                    trailing: IconButton(
                      tooltip: 'Réessayer',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(soldesProvider),
                    ),
                  ),
                ),
              _ => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _CarteSoldes extends StatelessWidget {
  const _CarteSoldes(this.soldes);

  final Map<Compte, int> soldes;

  @override
  Widget build(BuildContext context) {
    final total = soldes.values.fold(0, (a, b) => a + b);
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Solde total', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              formatFcfa(total),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final compte in Compte.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(compte.label, style: const TextStyle(color: Colors.white)),
                    const Spacer(),
                    Text(
                      formatFcfa(soldes[compte] ?? 0),
                      key: ValueKey('solde-affiche-${compte.api}'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
