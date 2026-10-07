import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../domain/transaction.dart';
import 'transactions_controller.dart';

/// Détail d'une opération et annulation (E4).
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _annuler(
    BuildContext context,
    WidgetRef ref,
    TransactionFinanciere tx,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette opération ?'),
        content: Text(
          'Une opération de ${formatFcfaSigned(-tx.montant)} sera ajoutée pour la neutraliser. '
          "L'opération d'origine reste visible dans l'historique.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Annuler l'opération"),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await ref.read(transactionsControllerProvider.notifier).annuler(tx);
    if (context.mounted) {
      (ScaffoldMessenger.of(context)..clearSnackBars()).showSnackBar(
        const SnackBar(content: Text('Opération annulée')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Opération')),
      body: switch (transaction) {
        AsyncData(value: final tx?) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Text(
                formatFcfaSigned(tx.montant),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: tx.montant >= 0
                      ? AppColors.incoming
                      : AppColors.outgoing,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _Ligne(
                    'Type',
                    tx.estAnnulation
                        ? 'Annulation (${tx.type.label})'
                        : tx.type.label,
                  ),
                  if (tx.categorie.isNotEmpty)
                    _Ligne('Catégorie', tx.categorie),
                  _Ligne('Compte', tx.compte.label),
                  _Ligne('Date', formatDateHeure(tx.dateOperation)),
                  if (tx.note.isNotEmpty) _Ligne('Note', tx.note),
                  _Ligne('Synchronisation', switch (tx.syncStatus) {
                    SyncStatus.pending =>
                      'En attente (sera envoyée dès que possible)',
                    SyncStatus.synced => 'Enregistrée sur le serveur',
                    SyncStatus.error => 'Refusée : ${tx.syncError ?? ''}',
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (tx.estAnnulee)
              OutlinedButton(
                onPressed: () =>
                    context.push(Routes.transaction(tx.annuleePar!)),
                child: const Text("Voir l'annulation"),
              ),
            if (tx.estAnnulation)
              OutlinedButton(
                onPressed: () =>
                    context.push(Routes.transaction(tx.annulationDe!)),
                child: const Text("Voir l'opération annulée"),
              ),
            if (tx.annulable)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _annuler(context, ref, tx),
                icon: const Icon(Icons.undo),
                label: const Text('Annuler cette opération'),
              ),
          ],
        ),
        AsyncData() => const Center(child: Text('Opération introuvable.')),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Text(
        valeur,
        textAlign: TextAlign.end,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
