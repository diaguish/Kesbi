/// Configuration injectée au build : `flutter run --dart-define-from-file=env/dev.json`.
///
/// Aucune de ces valeurs n'est un secret (la clé publishable est faite pour être
/// embarquée dans l'app), mais elles changent selon l'environnement.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// API Django. Émulateur Android → `http://10.0.2.2:8000`, simulateur iOS → `http://localhost:8000`.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static void ensureConfigured() {
    const missing = [
      if (supabaseUrl == '') 'SUPABASE_URL',
      if (supabasePublishableKey == '') 'SUPABASE_PUBLISHABLE_KEY',
      if (apiBaseUrl == '') 'API_BASE_URL',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Configuration manquante : ${missing.join(', ')}. '
        'Lancer avec --dart-define-from-file=env/dev.json (voir env/dev.example.json).',
      );
    }
  }
}
