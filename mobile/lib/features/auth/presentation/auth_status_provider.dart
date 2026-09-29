import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_status.dart';

/// État d'accès courant. Le routeur l'écoute pour rediriger (voir app_router.dart).
final authStatusProvider = NotifierProvider<AuthStatusNotifier, AuthStatus>(
  AuthStatusNotifier.new,
);

class AuthStatusNotifier extends Notifier<AuthStatus> {
  // TODO(feature/auth-otp-pin): lire la session Supabase et l'état du PIN dans
  // flutter_secure_storage. En attendant l'auth, l'app démarre déverrouillée
  // pour pouvoir tester la navigation.
  @override
  AuthStatus build() => AuthStatus.ready;

  void set(AuthStatus status) => state = status;
}
