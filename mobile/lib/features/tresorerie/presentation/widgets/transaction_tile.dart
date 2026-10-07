import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../domain/transaction.dart';

/// Ligne d'historique : libellé, compte, date, montant signé et état de sync.
class TransactionTile extends StatelessWidget {
  const TransactionTile(this.tx, {super.key, this.onTap});

  final TransactionFinanciere tx;
  final VoidCallback? onTap;

  String get _libelle {
    final base = tx.categorie.isNotEmpty ? tx.categorie : tx.type.label;
    return tx.estAnnulation ? 'Annulation : $base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final entree = tx.montant >= 0;
    final barre = tx.estAnnulee || tx.syncStatus == SyncStatus.error;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: (entree ? AppColors.incoming : AppColors.outgoing)
            .withValues(alpha: 0.12),
        child: Icon(
          tx.estAnnulation
              ? Icons.undo
              : (entree ? Icons.south_west : Icons.north_east),
          color: entree ? AppColors.incoming : AppColors.outgoing,
        ),
      ),
      title: Text(
        _libelle,
        style: TextStyle(decoration: barre ? TextDecoration.lineThrough : null),
      ),
      subtitle: Text(
        '${tx.compte.label} · ${formatDateHeure(tx.dateOperation)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatFcfaSigned(tx.montant),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: entree ? AppColors.incoming : AppColors.outgoing,
              decoration: barre ? TextDecoration.lineThrough : null,
            ),
          ),
          _Badge(tx),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.tx);

  final TransactionFinanciere tx;

  @override
  Widget build(BuildContext context) {
    final (texte, couleur) = switch (tx) {
      TransactionFinanciere(syncStatus: SyncStatus.error) => (
        'Refusée',
        AppColors.error,
      ),
      TransactionFinanciere(syncStatus: SyncStatus.pending) => (
        'En attente',
        AppColors.textDark,
      ),
      TransactionFinanciere(estAnnulee: true) => (
        'Annulée',
        AppColors.textDark,
      ),
      _ => (null, null),
    };
    if (texte == null) return const SizedBox.shrink();
    return Text(
      texte,
      style: TextStyle(
        fontSize: 12,
        color: couleur,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
