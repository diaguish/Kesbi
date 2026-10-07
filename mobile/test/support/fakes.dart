import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kesbi/app.dart';
import 'package:kesbi/core/api/api_client.dart';
import 'package:kesbi/core/storage/secure_store.dart';
import 'package:kesbi/features/auth/data/auth_gateway.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';
import 'package:kesbi/features/auth/domain/phone_number.dart';
import 'package:kesbi/features/auth/presentation/auth_status_provider.dart';
import 'package:kesbi/features/tresorerie/data/transaction_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base SQLite en mémoire, neuve pour chaque test.
TransactionStore memoryTransactionStore() {
  sqfliteFfiInit();
  return TransactionStore(
    () => databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, _) => TransactionStore.createSchema(db),
      ),
    ),
  );
}

class InMemorySecureStore implements SecureStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// Supabase Auth simulé. Code OTP valide : [validCode].
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.hasSession = false});

  static const validCode = '123456';

  @override
  bool hasSession;
  final sentTo = <PhoneNumber>[];
  AuthFailure? sendError;
  final _signedOut = StreamController<void>.broadcast();

  /// Simule une session révoquée par Supabase.
  void revokeSession() {
    hasSession = false;
    _signedOut.add(null);
  }

  @override
  Stream<void> get signedOut => _signedOut.stream;

  @override
  Future<void> sendOtp(PhoneNumber phone) async {
    if (sendError != null) throw sendError!;
    sentTo.add(phone);
  }

  @override
  Future<void> verifyOtp(PhoneNumber phone, String code) async {
    if (code != validCode) throw const AuthFailure('Code incorrect ou expiré.');
    hasSession = true;
  }

  @override
  Future<String?> accessToken() async => hasSession ? 'jwt-de-test' : null;

  @override
  Future<void> signOut() async => hasSession = false;
}

/// Horloge contrôlable.
class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 7, 9);
  DateTime call() => now;
}

/// Faux backend Django avec état : boutique, transactions, suppression de compte.
class FakeBackend {
  FakeBackend({this.boutiqueNom, Map<String, int>? ouvertures}) {
    ouvertures?.forEach(_ajouterOuverture);
  }

  /// Commerçant existant, onboarding terminé.
  FakeBackend.existant() : boutiqueNom = 'Boutique Awa' {
    const soldes = {'caisse': 200000, 'wave': 50000, 'orange_money': 0};
    soldes.forEach(_ajouterOuverture);
  }

  String? boutiqueNom;

  /// Transactions côté serveur, au format de l'API.
  final transactions = <Map<String, dynamic>>[];
  bool online = true;
  bool compteSupprime = false;

  /// Code HTTP à renvoyer pour la prochaine requête (simulation de panne).
  int? prochaineErreur;
  final requests = <String>[];

  Map<String, int> get ouvertures => {
        for (final t in transactions.where((t) => t['type'] == 'ouverture'))
          t['compte'] as String: t['montant'] as int,
      };

  int solde(String compte) => transactions
      .where((t) => t['compte'] == compte)
      .fold(0, (sum, t) => sum + (t['montant'] as int));

  void _ajouterOuverture(String compte, int montant) => transactions.add({
        'id': 'ouv-$compte',
        'type': 'ouverture',
        'compte': compte,
        'montant': montant,
        'date_operation': '2026-10-01T08:00:00Z',
        'created_at': '2026-10-01T08:00:00Z',
        'categorie': '',
        'note': '',
        'annulation_de': null,
        'annulee_par': null,
      });

  Future<http.Response> handle(http.Request request) async {
    if (!online) throw http.ClientException('hors ligne');
    final route = '${request.method} ${request.url.path}';
    requests.add(route);
    if (prochaineErreur case final code?) {
      prochaineErreur = null;
      return http.Response(jsonEncode({'detail': 'Erreur simulée'}), code);
    }
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
    final annulation = RegExp(r'^POST /api/transactions/([^/]+)/annuler/$').firstMatch(route);
    if (annulation != null) {
      final originale = transactions.firstWhere((t) => t['id'] == annulation.group(1));
      if (transactions.any((t) => t['id'] == body['id'])) return _json({'id': body['id']});
      final copie = {
        ...originale,
        'id': body['id'],
        'montant': -(originale['montant'] as int),
        'annulation_de': originale['id'],
        'created_at': body['created_at'],
      };
      originale['annulee_par'] = body['id'];
      transactions.add(copie);
      return _json(copie, 201);
    }
    switch (route) {
      case 'GET /api/me/':
        return _json({
          'id': 'u1',
          'phone': '221770000000',
          'boutiques': [
            if (boutiqueNom != null)
              {'id': 'b1', 'nom': boutiqueNom, 'ouverture_faite': ouvertures.length == 3},
          ],
        });
      case 'POST /api/boutiques/':
        if (boutiqueNom != null) return _json({'detail': 'Déjà une boutique.'}, 409);
        boutiqueNom = body['nom'] as String;
        return _json({'id': body['id'], 'nom': boutiqueNom}, 201);
      case 'POST /api/transactions/':
        if (transactions.any((t) => t['id'] == body['id'])) return _json(body);
        if (body['type'] == 'ouverture' && ouvertures.containsKey(body['compte'])) {
          return _json({'detail': 'Ouverture déjà saisie.'}, 409);
        }
        // Comme l'API : date_operation par défaut = maintenant, champs texte toujours présents.
        final tx = {
          'date_operation': body['created_at'] ?? '2026-10-07T09:00:00Z',
          'categorie': '',
          'note': '',
          ...body,
          'annulation_de': null,
          'annulee_par': null,
        };
        transactions.add(tx);
        return _json(tx, 201);
      case 'GET /api/transactions/':
        return _json({'next': null, 'previous': null, 'results': transactions.reversed.toList()});
      case 'GET /api/comptes/':
        final comptes = [
          for (final c in ['caisse', 'wave', 'orange_money']) {'compte': c, 'solde': solde(c)},
        ];
        return _json({'comptes': comptes});
      case 'DELETE /api/compte/':
        boutiqueNom = null;
        transactions.clear();
        compteSupprime = true;
        return http.Response('', 204);
    }
    return _json({'detail': 'Route inconnue : $route'}, 404);
  }

  static http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

/// Overrides communs : aucun accès réseau, hachage du PIN rapide et synchrone.
List<Override> authOverrides({
  required InMemorySecureStore store,
  required FakeAuthGateway gateway,
  FakeBackend? backend,
  FakeClock? clock,
  TransactionStore? transactions,
}) {
  final fake = backend ?? FakeBackend();
  final api = ApiClient(
    baseUrl: 'http://api.test',
    token: gateway.accessToken,
    client: MockClient(fake.handle),
  );
  return [
    secureStoreProvider.overrideWithValue(store),
    authGatewayProvider.overrideWithValue(gateway),
    pinRepositoryProvider.overrideWithValue(
      PinRepository(store, iterations: 10, runHash: (computation) => computation()),
    ),
    apiClientProvider.overrideWithValue(api),
    transactionStoreProvider.overrideWithValue(transactions ?? memoryTransactionStore()),
    connectivityChangesProvider.overrideWithValue(const Stream.empty()),
    if (clock != null) clockProvider.overrideWithValue(clock.call),
  ];
}
