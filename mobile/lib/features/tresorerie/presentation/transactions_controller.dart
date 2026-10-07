import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_status_provider.dart';
import '../data/sync_service.dart';
import '../data/transaction_store.dart';
import '../domain/compte.dart';
import '../domain/transaction.dart';

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(transactionStoreProvider),
    ref.watch(apiClientProvider),
  ),
);

/// Point d'entrée des écrans pour les transactions.
///
/// L'état est un numéro de version, incrémenté à chaque changement local :
/// les providers de lecture le surveillent pour se rafraîchir.
final transactionsControllerProvider =
    NotifierProvider<TransactionsController, int>(TransactionsController.new);

class TransactionsController extends Notifier<int> {
  static const _uuid = Uuid();

  TransactionStore get _store => ref.read(transactionStoreProvider);

  @override
  int build() => 0;

  void _changed() => state++;

  /// Nouvel encaissement (E1) ou nouvelle dépense (D1). Enregistré localement
  /// d'abord : fonctionne hors ligne (E3, D2). [montant] est saisi en positif.
  Future<TransactionFinanciere> enregistrer({
    required TypeSaisie saisie,
    required int montant,
    required Compte compte,
    required String categorie,
    required DateTime dateOperation,
    String note = '',
  }) async {
    assert(montant > 0);
    final now = ref.read(clockProvider)().toUtc();
    final tx = TransactionFinanciere(
      id: _uuid.v4(),
      type: saisie.type,
      compte: compte,
      montant: saisie.montantSigne(montant),
      dateOperation: dateOperation.toUtc(),
      createdAt: now,
      categorie: categorie,
      note: note.trim(),
    );
    await _store.insert(tx);
    _changed();
    unawaited(synchroniser());
    return tx;
  }

  /// Correction (E4) : écriture opposée, l'originale reste intacte (ADR 0009).
  Future<void> annuler(TransactionFinanciere originale) async {
    if (!originale.annulable) {
      throw StateError('Cette opération ne peut pas être annulée.');
    }
    await _store.insert(
      TransactionFinanciere(
        id: _uuid.v4(),
        type: originale.type,
        compte: originale.compte,
        montant: -originale.montant,
        dateOperation: ref.read(clockProvider)().toUtc(),
        createdAt: ref.read(clockProvider)().toUtc(),
        categorie: originale.categorie,
        annulationDe: originale.id,
      ),
    );
    _changed();
    unawaited(synchroniser());
  }

  Future<SyncResultat> synchroniser() async {
    final resultat = await ref.read(syncServiceProvider).synchroniser();
    if (ref.mounted) _changed();
    return resultat;
  }

  /// Déconnexion / suppression de compte.
  Future<void> effacerDonneesLocales() async {
    await _store.clear();
    _changed();
  }
}

/// Soldes calculés localement : disponibles hors ligne.
final soldesLocauxProvider = FutureProvider.autoDispose<Map<Compte, int>>((
  ref,
) {
  ref.watch(transactionsControllerProvider);
  return ref.read(transactionStoreProvider).soldes();
});

final operationsEnAttenteProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(transactionsControllerProvider);
  return ref.read(transactionStoreProvider).countPending();
});

/// Filtre de l'historique (E5).
class FiltreHistorique {
  const FiltreHistorique({this.compte, this.types, this.depuis, this.limit});

  final Compte? compte;
  final Set<TypeTransaction>? types;
  final DateTime? depuis;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is FiltreHistorique &&
      other.compte == compte &&
      setEquals(other.types, types) &&
      other.depuis == depuis &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(compte, types == null ? null : Object.hashAllUnordered(types!), depuis, limit);
}

final historiqueProvider = FutureProvider.autoDispose
    .family<List<TransactionFinanciere>, FiltreHistorique>((ref, filtre) {
      ref.watch(transactionsControllerProvider);
      return ref
          .read(transactionStoreProvider)
          .list(compte: filtre.compte, types: filtre.types, depuis: filtre.depuis, limit: filtre.limit);
    });

final transactionProvider = FutureProvider.autoDispose
    .family<TransactionFinanciere?, String>((ref, id) {
      ref.watch(transactionsControllerProvider);
      return ref.read(transactionStoreProvider).get(id);
    });
