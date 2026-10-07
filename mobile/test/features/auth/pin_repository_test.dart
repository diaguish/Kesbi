import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';

import '../../support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late PinRepository pins;

  setUp(() {
    store = InMemorySecureStore();
    pins = PinRepository(store, iterations: 10, runHash: (c) => c());
  });

  test('le PIN n\'est jamais stocké en clair', () async {
    await pins.setPin('482915');
    expect(await pins.hasPin(), isTrue);
    expect(store.values.values.join(), isNot(contains('482915')));
    expect(store.values['pin_hash'], startsWith(r'pbkdf2-sha256$10$'));
  });

  test('deux PIN identiques donnent des hash différents (sel aléatoire)', () async {
    await pins.setPin('482915');
    final first = store.values['pin_hash'];
    await pins.setPin('482915');
    expect(store.values['pin_hash'], isNot(first));
  });

  test('bon PIN accepté, mauvais PIN refusé avec le nombre d\'essais restants', () async {
    await pins.setPin('482915');
    expect(await pins.verify('482915'), isA<PinAccepted>());
    final rejected = await pins.verify('000001');
    expect(rejected, isA<PinRejected>());
    expect((rejected as PinRejected).remainingAttempts, 4);
  });

  test('5 erreurs d\'affilée effacent le PIN', () async {
    await pins.setPin('482915');
    for (var i = 0; i < 4; i++) {
      expect(await pins.verify('000001'), isA<PinRejected>());
    }
    expect(await pins.verify('000001'), isA<PinLockedOut>());
    expect(await pins.hasPin(), isFalse);
  });

  test('un succès remet le compteur d\'erreurs à zéro', () async {
    await pins.setPin('482915');
    for (var i = 0; i < 4; i++) {
      await pins.verify('000001');
    }
    await pins.verify('482915');
    final rejected = await pins.verify('000001') as PinRejected;
    expect(rejected.remainingAttempts, 4);
  });

  test('itérations par défaut suffisantes', () {
    expect(PinRepository.defaultIterations, greaterThanOrEqualTo(50000));
  });
}
