import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../domain/transaction.dart';
import 'transaction_store.dart';

enum SyncResultat {
  /// Tout est à jour.
  ok,

  /// Pas de réseau (ou serveur indisponible) : on réessaiera.
  horsLigne,

  /// Une synchronisation tournait déjà.
  dejaEnCours,

  /// Erreur inattendue (réponse illisible…) : journalisée, on réessaiera.
  erreur,
}

/// File de synchronisation (ADR 0002).
///
/// 1. Envoie les écritures en attente, dans l'ordre de création. L'API est
///    idempotente sur l'UUID : renvoyer une écriture déjà reçue est sans effet.
/// 2. Récupère les écritures du serveur (nouvel appareil, réinstallation).
class SyncService {
  SyncService(this._store, this._api);

  final TransactionStore _store;
  final ApiClient _api;
  Future<SyncResultat>? _enCours;

  /// Nombre d'écritures récupérées par synchronisation (historique complet : S10).
  static const taillePage = 200;

  /// Ne lève jamais d'exception : lancée en arrière-plan, elle ne doit pas faire planter l'app.
  Future<SyncResultat> synchroniser() {
    if (_enCours != null) return Future.value(SyncResultat.dejaEnCours);
    return _enCours = _synchroniser()
        .catchError((Object e, StackTrace st) {
          debugPrint('Synchronisation échouée : $e\n$st');
          return SyncResultat.erreur;
        })
        .whenComplete(() => _enCours = null);
  }

  Future<SyncResultat> _synchroniser() async {
    for (final tx in await _store.pending()) {
      try {
        if (tx.annulationDe case final originale?) {
          await _api.postJson('/api/transactions/$originale/annuler/', {
            'id': tx.id,
            'note': tx.note,
            'created_at': tx.createdAt.toUtc().toIso8601String(),
          });
        } else {
          await _api.postJson('/api/transactions/', tx.toApi());
        }
        await _store.markSynced(tx.id);
      } on ApiException catch (e) {
        if (_reessayable(e.statusCode)) return SyncResultat.horsLigne;
        // Refus définitif (donnée invalide) : on garde l'écriture, visible en erreur.
        await _store.markError(tx.id, ApiClient.messageFor(e));
      } on Object catch (e) {
        if (_erreurReseau(e)) return SyncResultat.horsLigne;
        rethrow;
      }
    }

    try {
      final page = await _api.getJson('/api/transactions/?taille=$taillePage');
      final transactions = (page['results'] as List)
          .cast<Map<String, dynamic>>()
          .map(TransactionFinanciere.fromApi)
          .toList();
      await _store.upsertFromServer(transactions);
    } on ApiException catch (e) {
      if (_reessayable(e.statusCode)) return SyncResultat.horsLigne;
      rethrow;
    } on Object catch (e) {
      if (_erreurReseau(e)) return SyncResultat.horsLigne;
      rethrow;
    }
    return SyncResultat.ok;
  }

  /// 401 : jeton à rafraîchir ; 408/429/5xx : passager. On réessaiera plus tard.
  static bool _reessayable(int status) =>
      status == 401 || status == 408 || status == 429 || status >= 500;

  static bool _erreurReseau(Object e) =>
      e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException;
}
