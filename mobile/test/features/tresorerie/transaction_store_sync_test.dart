import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kesbi/core/api/api_client.dart';
import 'package:kesbi/features/tresorerie/data/sync_service.dart';
import 'package:kesbi/features/tresorerie/data/transaction_store.dart';
import 'package:kesbi/features/tresorerie/domain/compte.dart';
import 'package:kesbi/features/tresorerie/domain/transaction.dart';

import '../../support/fakes.dart';

TransactionFinanciere encaissement(
  String id,
  int montant, {
  Compte compte = Compte.caisse,
  DateTime? date,
  String? annulationDe,
}) {
  final d = date ?? DateTime.utc(2026, 10, 7, 10);
  return TransactionFinanciere(
    id: id,
    type: TypeTransaction.encaissement,
    compte: compte,
    montant: montant,
    dateOperation: d,
    createdAt: d,
    categorie: 'Vente comptant',
    annulationDe: annulationDe,
  );
}

void main() {
  late TransactionStore store;

  setUp(() => store = memoryTransactionStore());

  group('TransactionStore', () {
    test('soldes calculés par compte, écritures refusées exclues', () async {
      await store.insert(encaissement('a', 25000));
      await store.insert(encaissement('b', 10000, compte: Compte.wave));
      await store.insert(encaissement('c', 5000));
      await store.markError('c', 'refusée');
      expect(await store.soldes(), {Compte.caisse: 25000, Compte.wave: 10000, Compte.orangeMoney: 0});
    });

    test('historique trié, filtré, avec le lien d\'annulation', () async {
      await store.insert(encaissement('ancienne', 1000, date: DateTime.utc(2026, 9, 1)));
      await store.insert(encaissement('recente', 2000, compte: Compte.wave));
      await store.insert(
        encaissement('annul', -2000, compte: Compte.wave, annulationDe: 'recente', date: DateTime.utc(2026, 10, 7, 11)),
      );

      final tout = await store.list();
      expect(tout.map((t) => t.id), ['annul', 'recente', 'ancienne']);
      expect(tout[1].annuleePar, 'annul');
      expect(tout[1].annulable, isFalse);

      expect((await store.list(compte: Compte.caisse)).map((t) => t.id), ['ancienne']);
      expect((await store.list(depuis: DateTime.utc(2026, 10, 1))).length, 2);
      expect((await store.list(limit: 1)).single.id, 'annul');
    });

    test('copie serveur : pas de doublon, passe en synchronisé', () async {
      await store.insert(encaissement('a', 25000));
      expect(await store.countPending(), 1);
      await store.upsertFromServer([encaissement('a', 25000), encaissement('b', 300)]);
      expect(await store.countPending(), 0);
      expect((await store.list()).length, 2);
    });

    test('effacement complet (déconnexion)', () async {
      await store.insert(encaissement('a', 25000));
      await store.clear();
      expect(await store.list(), isEmpty);
    });
  });

  group('SyncService', () {
    late FakeBackend backend;
    late SyncService sync;

    setUp(() {
      backend = FakeBackend.existant();
      final api = ApiClient(
        baseUrl: 'http://api.test',
        token: () async => 'jwt',
        client: MockClient(backend.handle),
      );
      sync = SyncService(store, api);
    });

    test('envoie les écritures en attente puis récupère celles du serveur', () async {
      await store.insert(encaissement('a', 25000));
      expect(await sync.synchroniser(), SyncResultat.ok);
      expect(backend.solde('caisse'), 225000);
      expect(await store.countPending(), 0);
      // Les soldes d'ouverture du serveur sont maintenant sur le téléphone.
      expect((await store.soldes())[Compte.caisse], 225000);
    });

    test('annulation envoyée sur l\'endpoint dédié, après l\'originale', () async {
      await store.insert(encaissement('a', 25000, date: DateTime.utc(2026, 10, 7, 10)));
      await store.insert(encaissement('b', -25000, annulationDe: 'a', date: DateTime.utc(2026, 10, 7, 11)));
      await sync.synchroniser();
      expect(backend.requests, containsAllInOrder(['POST /api/transactions/', 'POST /api/transactions/a/annuler/']));
      expect(backend.solde('caisse'), 200000);
    });

    test('hors ligne : rien n\'est perdu, renvoyé au retour du réseau', () async {
      await store.insert(encaissement('a', 25000));
      backend.online = false;
      expect(await sync.synchroniser(), SyncResultat.horsLigne);
      expect(await store.countPending(), 1);

      backend.online = true;
      expect(await sync.synchroniser(), SyncResultat.ok);
      expect(await store.countPending(), 0);
    });

    test('rejeu sans doublon côté serveur (idempotence)', () async {
      await store.insert(encaissement('a', 25000));
      await sync.synchroniser();
      await store.upsertFromServer([]);
      // Simule une réponse perdue : l'écriture repasse en attente et est renvoyée.
      await store.insert(encaissement('a', 25000));
      await sync.synchroniser();
      expect(backend.transactions.where((t) => t['id'] == 'a').length, 1);
    });

    test('refus définitif du serveur → écriture en erreur, les suivantes passent', () async {
      await store.insert(encaissement('a', 25000, date: DateTime.utc(2026, 10, 7, 10)));
      await store.insert(encaissement('b', 1000, date: DateTime.utc(2026, 10, 7, 11)));
      backend.prochaineErreur = 400;
      expect(await sync.synchroniser(), SyncResultat.ok);
      final a = await store.get('a');
      expect(a!.syncStatus, SyncStatus.error);
      expect(a.syncError, 'Erreur simulée');
      expect((await store.get('b'))!.syncStatus, SyncStatus.synced);
    });

    test('serveur indisponible (503) : on réessaiera', () async {
      await store.insert(encaissement('a', 25000));
      backend.prochaineErreur = 503;
      expect(await sync.synchroniser(), SyncResultat.horsLigne);
      expect((await store.get('a'))!.syncStatus, SyncStatus.pending);
    });

    test('ne lève jamais d\'exception', () async {
      backend.prochaineErreur = 404; // réponse inattendue sur la récupération
      expect(await sync.synchroniser(), SyncResultat.erreur);
    });
  });
}
