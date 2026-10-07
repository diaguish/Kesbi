import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage chiffré clé/valeur (Keychain iOS, Keystore Android).
/// Interface pour pouvoir le remplacer par une version en mémoire dans les tests.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Le Keychain iOS survit à la désinstallation de l'app. Or une réinstallation
/// doit repasser par l'OTP (ADR 0003) : au premier lancement après installation,
/// on efface le stockage sécurisé. Les SharedPreferences, elles, sont bien
/// supprimées avec l'app et servent de témoin.
Future<void> wipeSecureStoreAfterReinstall(SecureStore store) async {
  const installedFlag = 'kesbi_installed';
  final prefs = SharedPreferencesAsync();
  if (await prefs.getBool(installedFlag) ?? false) return;
  await store.deleteAll();
  await prefs.setBool(installedFlag, true);
}

/// Remplacé dans `main.dart` (instance réelle) et dans les tests (mémoire).
final secureStoreProvider = Provider<SecureStore>((ref) => FlutterSecureStore());
