import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/storage/secure_store.dart';
import 'features/auth/data/auth_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.ensureConfigured();

  final store = FlutterSecureStore();
  await wipeSecureStoreAfterReinstall(store);

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(
      // Session (refresh token) dans le Keychain / Keystore (ADR 0003).
      localStorage: SecureSessionStorage(store),
      // Connexion par OTP SMS uniquement : pas de lien magique à intercepter.
      detectSessionInUri: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(store)],
      child: const KesBiApp(),
    ),
  );
}
