import '../../features/auth/domain/auth_status.dart';

/// Chemins de l'app. Toujours utiliser ces constantes, jamais de chaîne en dur.
/// Les notifications FCM et les liens profonds pointent vers ces chemins.
abstract final class Routes {
  static const splash = '/';
  static const otp = '/otp';
  static const otpCode = '/otp/code';
  // Hors de `/pin/…` : un utilisateur verrouillé ne doit pas pouvoir recréer son PIN.
  static const pinSetup = '/creer-pin';
  static const pin = '/pin';
  static const onboarding = '/onboarding';

  static const accueil = '/accueil';
  static const profil = '/accueil/profil';
  static const nouvelEncaissement = '/accueil/encaissement';
  static const historique = '/accueil/transactions';
  static String transaction(String id) => '$historique/$id';
  static const tresorerie = '/tresorerie';
  static const creances = '/creances';
  static const rapport = '/rapport';

  static String creance(String id) => '$creances/$id';
}

/// Règle de garde unique de l'app : décide où envoyer l'utilisateur selon son
/// état d'accès. Retourne `null` si l'écran demandé est autorisé.
///
/// Fonction pure (testée dans test/core/router/routes_test.dart).
String? authRedirect(AuthStatus status, String location) {
  final target = switch (status) {
    AuthStatus.unknown => Routes.splash,
    AuthStatus.signedOut => Routes.otp,
    AuthStatus.pinSetup => Routes.pinSetup,
    AuthStatus.locked => Routes.pin,
    AuthStatus.needsOnboarding => Routes.onboarding,
    AuthStatus.ready => null,
  };

  if (target != null) {
    return location == target || location.startsWith('$target/')
        ? null
        : target;
  }

  // Utilisateur prêt : il ne doit plus voir les écrans d'accès.
  const accessScreens = [
    Routes.splash,
    Routes.otp,
    Routes.pinSetup,
    Routes.pin,
    Routes.onboarding,
  ];
  final onAccessScreen = accessScreens.any(
    (s) => location == s || (s != Routes.splash && location.startsWith('$s/')),
  );
  return onAccessScreen ? Routes.accueil : null;
}
