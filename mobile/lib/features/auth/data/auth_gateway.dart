import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/secure_store.dart';
import '../domain/phone_number.dart';

/// Erreur d'authentification avec un message prêt à afficher.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Accès à Supabase Auth. Interface pour tester l'app sans réseau.
abstract interface class AuthGateway {
  bool get hasSession;

  /// Émet quand Supabase ferme la session (jeton révoqué, déconnexion…).
  Stream<void> get signedOut;

  Future<void> sendOtp(PhoneNumber phone);
  Future<void> verifyOtp(PhoneNumber phone, String code);

  /// JWT valide pour appeler l'API Django (rafraîchi si expiré).
  Future<String?> accessToken();

  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._auth);

  final GoTrueClient _auth;

  @override
  bool get hasSession => _auth.currentSession != null;

  @override
  Stream<void> get signedOut =>
      _auth.onAuthStateChange.where((s) => s.event == AuthChangeEvent.signedOut);

  @override
  Future<void> sendOtp(PhoneNumber phone) =>
      _guard(() => _auth.signInWithOtp(phone: phone.e164, shouldCreateUser: true));

  @override
  Future<void> verifyOtp(PhoneNumber phone, String code) =>
      _guard(() => _auth.verifyOTP(phone: phone.e164, token: code, type: OtpType.sms));

  @override
  Future<String?> accessToken() async {
    final session = _auth.currentSession;
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;
    final refreshed = await _guard(_auth.refreshSession);
    return refreshed.session?.accessToken;
  }

  @override
  Future<void> signOut() async {
    try {
      // Portée locale : ferme la session de cet appareil uniquement.
      await _auth.signOut();
    } catch (_) {
      // Hors ligne : la session locale est quand même effacée par le client.
    }
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } on AuthRetryableFetchException {
      throw const AuthFailure('Pas de connexion internet. Réessayez.');
    } on AuthException catch (e) {
      throw AuthFailure(messageFor(e.code));
    } on SocketException {
      throw const AuthFailure('Pas de connexion internet. Réessayez.');
    } on TimeoutException {
      throw const AuthFailure('Le réseau est trop lent. Réessayez.');
    }
  }

  /// Codes d'erreur Supabase Auth → message pour le commerçant.
  static String messageFor(String? code) => switch (code) {
        'otp_expired' => 'Code incorrect ou expiré.',
        'over_sms_send_rate_limit' ||
        'over_request_rate_limit' =>
          'Trop de tentatives. Réessayez dans quelques minutes.',
        'sms_send_failed' => "L'envoi du SMS a échoué. Réessayez plus tard.",
        'phone_provider_disabled' || 'signup_disabled' =>
          "L'inscription est momentanément indisponible.",
        'session_not_found' || 'refresh_token_not_found' =>
          'Votre session a expiré. Reconnectez-vous.',
        _ => 'Une erreur est survenue. Réessayez.',
      };
}

/// Stockage de la session Supabase (refresh token) dans le stockage sécurisé
/// plutôt que dans les SharedPreferences par défaut (ADR 0003).
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this._store);

  static const _key = 'supabase_session';
  final SecureStore _store;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await _store.read(_key) != null;

  @override
  Future<String?> accessToken() => _store.read(_key);

  @override
  Future<void> removePersistedSession() => _store.delete(_key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(_key, persistSessionString);
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(Supabase.instance.client.auth),
);
