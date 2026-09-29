import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/core/router/routes.dart';
import 'package:kesbi/features/auth/domain/auth_status.dart';

void main() {
  group('authRedirect', () {
    test('non connecté → OTP, quel que soit l\'écran demandé', () {
      expect(authRedirect(AuthStatus.signedOut, Routes.accueil), Routes.otp);
      expect(authRedirect(AuthStatus.signedOut, Routes.creance('abc')), Routes.otp);
      expect(authRedirect(AuthStatus.signedOut, Routes.otp), isNull);
    });

    test('verrouillé → PIN, aucun écran de l\'app accessible', () {
      expect(authRedirect(AuthStatus.locked, Routes.accueil), Routes.pin);
      expect(authRedirect(AuthStatus.locked, Routes.tresorerie), Routes.pin);
      expect(authRedirect(AuthStatus.locked, Routes.otp), Routes.pin);
      expect(authRedirect(AuthStatus.locked, Routes.pin), isNull);
    });

    test('onboarding → création boutique, sous-écrans autorisés', () {
      expect(authRedirect(AuthStatus.needsOnboarding, Routes.accueil), Routes.onboarding);
      expect(authRedirect(AuthStatus.needsOnboarding, '/onboarding/soldes'), isNull);
    });

    test('démarrage → écran de chargement', () {
      expect(authRedirect(AuthStatus.unknown, Routes.accueil), Routes.splash);
      expect(authRedirect(AuthStatus.unknown, Routes.splash), isNull);
    });

    test('prêt → accès à l\'app, écrans d\'accès renvoient à l\'accueil', () {
      expect(authRedirect(AuthStatus.ready, Routes.accueil), isNull);
      expect(authRedirect(AuthStatus.ready, Routes.creance('abc')), isNull);
      expect(authRedirect(AuthStatus.ready, Routes.pin), Routes.accueil);
      expect(authRedirect(AuthStatus.ready, Routes.otp), Routes.accueil);
      expect(authRedirect(AuthStatus.ready, Routes.splash), Routes.accueil);
    });
  });
}
