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

/// Overrides communs : aucun accès réseau, hachage du PIN rapide et synchrone.
List<Override> authOverrides({
  required InMemorySecureStore store,
  required FakeAuthGateway gateway,
  List<Map<String, dynamic>> boutiques = const [],
  bool apiOnline = true,
  FakeClock? clock,
}) {
  final api = ApiClient(
    baseUrl: 'http://api.test',
    token: gateway.accessToken,
    client: MockClient((request) async {
      if (!apiOnline) throw http.ClientException('hors ligne');
      return http.Response(
        jsonEncode({'id': 'u1', 'phone': '221770000000', 'boutiques': boutiques}),
        200,
      );
    }),
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
