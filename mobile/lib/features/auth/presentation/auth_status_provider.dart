import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_gateway.dart';
import '../data/pin_repository.dart';
import '../domain/auth_status.dart';
import '../domain/phone_number.dart';

/// Horloge injectable (verrouillage automatique testable).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// État d'accès courant. Le routeur l'écoute pour rediriger (voir app_router.dart).
final authStatusProvider = NotifierProvider<AuthController, AuthStatus>(AuthController.new);

/// Parcours d'accès (ADR 0003) :
/// numéro → OTP → création du PIN → (onboarding) → app ; ensuite PIN à chaque ouverture.
class AuthController extends Notifier<AuthStatus> {
  /// Verrouillage après ce délai en arrière-plan (A5).
  static const lockAfter = Duration(minutes: 3);

  static const _onboardedKey = 'onboarding_done';

  late AuthGateway _gateway;
  late PinRepository _pins;
  late SecureStore _store;
  DateTime? _hiddenAt;

  @override
  AuthStatus build() {
    _gateway = ref.watch(authGatewayProvider);
    _pins = ref.watch(pinRepositoryProvider);
    _store = ref.watch(secureStoreProvider);

    // Session fermée côté Supabase (jeton révoqué, refresh impossible) → OTP.
    final sub = _gateway.signedOut.listen((_) {
      if (state != AuthStatus.signedOut) unawaited(_reset());
    });
    ref.onDispose(sub.cancel);

    // Après le retour de build() : l'état n'est lisible qu'une fois initialisé.
    Future.microtask(_restore);
    return AuthStatus.unknown;
  }

  /// Au démarrage : fonctionne hors ligne (session et PIN sont locaux).
  Future<void> _restore() async {
    final next = !_gateway.hasSession
        ? AuthStatus.signedOut
        : await _pins.hasPin()
            ? AuthStatus.locked
            : AuthStatus.pinSetup;
    if (ref.mounted && state == AuthStatus.unknown) state = next;
  }

  Future<void> sendOtp(PhoneNumber phone) => _gateway.sendOtp(phone);

  /// OTP validé = nouvel appareil, réinstallation ou PIN oublié : on (re)crée le PIN.
  Future<void> verifyOtp(PhoneNumber phone, String code) async {
    await _gateway.verifyOtp(phone, code);
    await _pins.clear();
    await _store.delete(_onboardedKey);
    state = AuthStatus.pinSetup;
  }

  Future<void> createPin(String pin) async {
    await _pins.setPin(pin);
    await _unlocked();
  }

  /// Vérification locale, sans réseau (A3). 5 erreurs → retour à l'OTP (A4).
  Future<PinCheck> unlock(String pin) async {
    final result = await _pins.verify(pin);
    switch (result) {
      case PinAccepted():
        await _unlocked();
      case PinLockedOut():
        await _reset();
      case PinRejected():
        break;
    }
    return result;
  }

  /// « Code PIN oublié » ou déconnexion : on repasse par l'OTP.
  Future<void> signOut() => _reset();

  /// Appelé par l'onboarding quand la boutique est créée.
  Future<void> markOnboarded() async {
    await _store.write(_onboardedKey, '1');
    state = AuthStatus.ready;
  }

  void onAppHidden() => _hiddenAt = ref.read(clockProvider)();

  void onAppShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    final unlockedStates = {AuthStatus.ready, AuthStatus.needsOnboarding};
    if (unlockedStates.contains(state) &&
        ref.read(clockProvider)().difference(hiddenAt) >= lockAfter) {
      state = AuthStatus.locked;
    }
  }

  Future<void> _unlocked() async {
    state = await _isOnboarded() ? AuthStatus.ready : AuthStatus.needsOnboarding;
  }

  /// Mémorisé localement une fois la boutique connue, pour rester utilisable hors ligne.
  Future<bool> _isOnboarded() async {
    if (await _store.read(_onboardedKey) == '1') return true;
    try {
      final me = await ref.read(apiClientProvider).getJson('/api/me/');
      final hasBoutique = (me['boutiques'] as List).isNotEmpty;
      if (hasBoutique) await _store.write(_onboardedKey, '1');
      return hasBoutique;
    } catch (_) {
      // Hors ligne ou API injoignable : l'onboarding revérifiera.
      return false;
    }
  }

  Future<void> _reset() async {
    await _pins.clear();
    await _store.delete(_onboardedKey);
    await _gateway.signOut();
    if (ref.mounted) state = AuthStatus.signedOut;
  }
}
