/// Comptes du MVP (ADR 0004, 0009). Affichés toujours séparément.
enum Compte {
  caisse('caisse', 'Caisse'),
  wave('wave', 'Wave'),
  orangeMoney('orange_money', 'Orange Money');

  const Compte(this.api, this.label);

  /// Valeur échangée avec l'API.
  final String api;
  final String label;

  static Compte fromApi(String value) => values.firstWhere((c) => c.api == value);
}
