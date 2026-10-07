import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_store.dart';
import '../domain/pin_rules.dart';

/// Résultat d'une saisie de PIN.
sealed class PinCheck {
  const PinCheck();
}

class PinAccepted extends PinCheck {
  const PinAccepted();
}

class PinRejected extends PinCheck {
  const PinRejected(this.remainingAttempts);
  final int remainingAttempts;
}

/// Trop d'erreurs : le PIN est effacé, l'appelant doit fermer la session.
class PinLockedOut extends PinCheck {
  const PinLockedOut();
}

/// PIN local (ADR 0003) : jamais envoyé au serveur, stocké haché et salé
/// dans le stockage sécurisé. Format : `pbkdf2-sha256$<itérations>$<sel>$<hash>`.
class PinRepository {
  PinRepository(this._store, {this.iterations = defaultIterations, this.runHash});

  /// Calcul ~0,3 s sur un Android d'entrée de gamme, hors du thread UI.
  static const defaultIterations = 60000;

  static const _hashKey = 'pin_hash';
  static const _failuresKey = 'pin_failures';

  final SecureStore _store;
  final int iterations;

  /// Exécute le hachage. Par défaut dans un isolate (hors du thread UI) ;
  /// les tests le remplacent par un appel direct.
  final Future<List<int>> Function(Future<List<int>> Function() computation)? runHash;

  Future<bool> hasPin() async => await _store.read(_hashKey) != null;

  Future<void> setPin(String pin) async {
    assert(PinRules.isComplete(pin));
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _hash(pin, salt, iterations);
    await _store.write(
      _hashKey,
      'pbkdf2-sha256\$$iterations\$${base64Encode(salt)}\$${base64Encode(hash)}',
    );
    await _store.delete(_failuresKey);
  }

  Future<PinCheck> verify(String pin) async {
    final stored = await _store.read(_hashKey);
    if (stored == null) return const PinLockedOut();

    final parts = stored.split(r'$');
    final expected = base64Decode(parts[3]);
    final actual = await _hash(pin, base64Decode(parts[2]), int.parse(parts[1]));

    if (_constantTimeEquals(actual, expected)) {
      await _store.delete(_failuresKey);
      return const PinAccepted();
    }

    final failures = int.parse(await _store.read(_failuresKey) ?? '0') + 1;
    if (failures >= PinRules.maxAttempts) {
      await clear();
      return const PinLockedOut();
    }
    await _store.write(_failuresKey, '$failures');
    return PinRejected(PinRules.maxAttempts - failures);
  }

  Future<void> clear() async {
    await _store.delete(_hashKey);
    await _store.delete(_failuresKey);
  }

  Future<List<int>> _hash(String pin, List<int> salt, int rounds) {
    Future<List<int>> computation() async {
      final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256);
      final key = await pbkdf2.deriveKeyFromPassword(password: pin, nonce: salt);
      return key.extractBytes();
    }

    final run = runHash;
    return run != null ? run(computation) : Isolate.run(computation);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(ref.watch(secureStoreProvider)),
);
