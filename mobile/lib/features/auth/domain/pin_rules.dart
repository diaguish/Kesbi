/// Règles du code PIN à 6 chiffres (ADR 0003).
abstract final class PinRules {
  static const length = 6;

  /// Après ce nombre d'erreurs d'affilée, la session est effacée → retour à l'OTP.
  static const maxAttempts = 5;

  static bool isComplete(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  /// Refuse les PIN devinables en premier : `000000`, `123456`, `654321`…
  static String? weaknessOf(String pin) {
    if (pin.split('').toSet().length == 1) {
      return 'Évitez les chiffres tous identiques.';
    }
    const ascending = '0123456789';
    const descending = '9876543210';
    if (ascending.contains(pin) || descending.contains(pin)) {
      return 'Évitez les suites de chiffres.';
    }
    return null;
  }
}
