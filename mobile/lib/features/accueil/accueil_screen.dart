import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../tresorerie/domain/compte.dart';
import '../tresorerie/presentation/transactions_controller.dart';
import '../tresorerie/presentation/widgets/transaction_tile.dart';

/// Accueil : soldes, saisie rapide, dernières opérations. Lu en local (hors ligne).
/// Dashboard complet (vue semaine, graphique, créances) : S5.
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  static const _recentes = FiltreHistorique(limit: 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soldes = ref.watch(soldesLocauxProvider);
    final enAttente = ref.watch(operationsEnAttenteProvider).value ?? 0;
    final recentes = ref.watch(historiqueProvider(_recentes));

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
        onRefresh: () =>
            ref.read(transactionsControllerProvider.notifier).synchroniser(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            switch (soldes) {
              AsyncData(:final value) => _CarteSoldes(value),
              _ => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
            },
            if (enAttente > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      enAttente == 1
                          ? '1 opération en attente de synchronisation'
                          : '$enAttente opérations en attente de synchronisation',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(Routes.nouvelEncaissement),
                    icon: const Icon(Icons.add),
                    label: const Text('Encaissement'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(Routes.nouvelleDepense),
                    icon: const Icon(Icons.remove),
                    label: const Text('Dépense'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Opérations récentes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(Routes.historique),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            ...switch (recentes) {
              AsyncData(:final value) when value.isEmpty => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Aucune opération pour le moment.'),
                ),
              ],
              AsyncData(:final value) => [
                Card(
                  child: Column(
                    children: [
                      for (final tx in value)
                        TransactionTile(
                          tx,
                          onTap: () => context.push(Routes.transaction(tx.id)),
                        ),
                    ],
                  ),
                ),
              ],
              _ => const <Widget>[],
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
              key: const ValueKey('solde-total'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final compte in Compte.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      compte.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      formatFcfa(soldes[compte] ?? 0),
                      key: ValueKey('solde-affiche-${compte.api}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
