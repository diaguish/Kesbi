import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../auth/presentation/auth_status_provider.dart';
import '../domain/compte.dart';
import 'transactions_controller.dart';
import 'widgets/transaction_tile.dart';

enum Periode {
  semaine('7 jours', Duration(days: 7)),
  mois('30 jours', Duration(days: 30)),
  tout('Tout', null);

  const Periode(this.label, this.duree);

  final String label;
  final Duration? duree;
}

/// Historique des transactions avec filtres (E5). Lu en local : fonctionne hors ligne.
class HistoriqueScreen extends ConsumerStatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  ConsumerState<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends ConsumerState<HistoriqueScreen> {
  Compte? _compte;
  // Vue semaine par défaut (décision produit).
  Periode _periode = Periode.semaine;

  /// Instant de référence figé : recalculé à chaque build, il changerait le
  /// filtre (donc le provider) en permanence et relancerait la requête en boucle.
  late DateTime _maintenant = ref.read(clockProvider)();

  void _choisirPeriode(Periode periode) => setState(() {
    _periode = periode;
    _maintenant = ref.read(clockProvider)();
  });

  @override
  Widget build(BuildContext context) {
    final maintenant = _maintenant;
    final filtre = FiltreHistorique(
      compte: _compte,
      depuis: _periode.duree == null
          ? null
          : maintenant.subtract(_periode.duree!),
    );
    final transactions = ref.watch(historiqueProvider(filtre));

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(transactionsControllerProvider.notifier).synchroniser(),
        child: ListView(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  for (final periode in Periode.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(periode.label),
                        selected: _periode == periode,
                        onSelected: (_) => _choisirPeriode(periode),
                      ),
                    ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  for (final compte in <Compte?>[null, ...Compte.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(compte?.label ?? 'Tous les comptes'),
                        selected: _compte == compte,
                        onSelected: (_) => setState(() => _compte = compte),
                      ),
                    ),
                ],
              ),
            ),
            ...switch (transactions) {
              AsyncData(:final value) when value.isEmpty => [
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucune opération sur cette période.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              AsyncData(:final value) => [
                for (final tx in value)
                  TransactionTile(
                    tx,
                    onTap: () => context.push(Routes.transaction(tx.id)),
                  ),
              ],
              AsyncError(:final error) => [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('$error'),
                ),
              ],
              _ => [
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}
