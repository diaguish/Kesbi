/// État d'accès de l'utilisateur à l'app (voir ADR 0003).
enum AuthStatus {
  /// Au démarrage, avant la lecture de la session dans le stockage sécurisé.
  unknown,

  /// Aucune session : parcours numéro → OTP.
  signedOut,

  /// OTP validé, aucun PIN sur cet appareil : création du PIN.
  pinSetup,

  /// Session présente mais app verrouillée : saisie du PIN.
  locked,

  /// Connecté, boutique ou soldes d'ouverture pas encore créés.
  needsOnboarding,

  /// Accès complet à l'app.
  ready,
}
