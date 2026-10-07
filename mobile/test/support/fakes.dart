import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kesbi/core/api/api_client.dart';
import 'package:kesbi/core/storage/secure_store.dart';
import 'package:kesbi/features/auth/data/auth_gateway.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';
import 'package:kesbi/features/auth/domain/phone_number.dart';
import 'package:kesbi/features/auth/presentation/auth_status_provider.dart';

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

/// Faux backend Django avec état : boutique, soldes d'ouverture, suppression de compte.
class FakeBackend {
  FakeBackend({this.boutiqueNom, Map<String, int>? ouvertures})
      : ouvertures = ouvertures ?? {};

  /// Commerçant existant, onboarding terminé.
  FakeBackend.existant()
      : boutiqueNom = 'Boutique Awa',
        ouvertures = {'caisse': 200000, 'wave': 50000, 'orange_money': 0};

  String? boutiqueNom;
  final Map<String, int> ouvertures;
  bool online = true;
  bool compteSupprime = false;

  /// Code HTTP à renvoyer pour la prochaine requête (simulation de panne).
  int? prochaineErreur;
  final requests = <String>[];

  Future<http.Response> handle(http.Request request) async {
    if (!online) throw http.ClientException('hors ligne');
    final route = '${request.method} ${request.url.path}';
    requests.add(route);
    if (prochaineErreur case final code?) {
      prochaineErreur = null;
      return http.Response(jsonEncode({'detail': 'Erreur simulée'}), code);
    }
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
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
        final compte = body['compte'] as String;
        if (body['type'] == 'ouverture' && ouvertures.containsKey(compte)) {
          return _json({'detail': 'Ouverture déjà saisie.'}, 409);
        }
        ouvertures[compte] = body['montant'] as int;
        return _json(body, 201);
      case 'GET /api/comptes/':
        final comptes = [
          for (final c in ['caisse', 'wave', 'orange_money']) {'compte': c, 'solde': ouvertures[c] ?? 0},
        ];
        return _json({'comptes': comptes, 'total': ouvertures.values.fold(0, (a, b) => a + b)});
      case 'DELETE /api/compte/':
        boutiqueNom = null;
        ouvertures.clear();
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
    if (clock != null) clockProvider.overrideWithValue(clock.call),
  ];
}
