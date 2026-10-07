import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/features/auth/data/auth_gateway.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';
import 'package:kesbi/features/auth/domain/auth_status.dart';
import 'package:kesbi/features/auth/domain/phone_number.dart';
import 'package:kesbi/features/auth/presentation/auth_status_provider.dart';

import '../../support/fakes.dart';

void main() {
  final phone = PhoneNumber.tryParse('770000000')!;
  late InMemorySecureStore store;
  late FakeAuthGateway gateway;
  late FakeClock clock;

  setUp(() {
    store = InMemorySecureStore();
    gateway = FakeAuthGateway();
    clock = FakeClock();
  });

  Future<ProviderContainer> start({FakeBackend? backend, bool apiOnline = true}) async {
    final fake = (backend ?? FakeBackend())..online = apiOnline;
    final container = ProviderContainer(
      overrides: authOverrides(store: store, gateway: gateway, backend: fake, clock: clock),
    );
    addTearDown(container.dispose);
    container.listen(authStatusProvider, (_, _) {});
    await pumpEventQueue();
    return container;
  }

  AuthController ctrl(ProviderContainer c) => c.read(authStatusProvider.notifier);

  test('sans session → OTP', () async {
    final c = await start();
    expect(c.read(authStatusProvider), AuthStatus.signedOut);
  });

  test('inscription : OTP → création PIN → onboarding si aucune boutique', () async {
    final c = await start();
    await ctrl(c).sendOtp(phone);
    expect(gateway.sentTo, [phone]);

    await ctrl(c).verifyOtp(phone, FakeAuthGateway.validCode);
    expect(c.read(authStatusProvider), AuthStatus.pinSetup);

    await ctrl(c).createPin('482915');
    expect(c.read(authStatusProvider), AuthStatus.needsOnboarding);
  });

  test('nouvel appareil d\'un commerçant existant → app directement', () async {
    final c = await start(backend: FakeBackend.existant());
    await ctrl(c).verifyOtp(phone, FakeAuthGateway.validCode);
    await ctrl(c).createPin('482915');
    expect(c.read(authStatusProvider), AuthStatus.ready);
    expect(store.values['onboarding_done'], '1');
  });

  test('mauvais code OTP → erreur, reste déconnecté', () async {
    final c = await start();
    await expectLater(ctrl(c).verifyOtp(phone, '000000'), throwsA(isA<AuthFailure>()));
    expect(c.read(authStatusProvider), AuthStatus.signedOut);
  });

  test('ouverture quotidienne : session + PIN → verrouillé, déverrouillage hors ligne', () async {
    gateway.hasSession = true;
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
    store.values['onboarding_done'] = '1';

    final c = await start(apiOnline: false);
    expect(c.read(authStatusProvider), AuthStatus.locked);

    expect(await ctrl(c).unlock('482915'), isA<PinAccepted>());
    expect(c.read(authStatusProvider), AuthStatus.ready);
  });

  test('session sans PIN (app tuée pendant la création) → création du PIN', () async {
    gateway.hasSession = true;
    final c = await start();
    expect(c.read(authStatusProvider), AuthStatus.pinSetup);
  });

  test('5 PIN faux → session fermée, retour à l\'OTP', () async {
    gateway.hasSession = true;
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
    final c = await start();

    for (var i = 0; i < 4; i++) {
      expect(await ctrl(c).unlock('000001'), isA<PinRejected>());
      expect(c.read(authStatusProvider), AuthStatus.locked);
    }
    expect(await ctrl(c).unlock('000001'), isA<PinLockedOut>());
    expect(c.read(authStatusProvider), AuthStatus.signedOut);
    expect(gateway.hasSession, isFalse);
  });

  test('PIN oublié → OTP, puis nouveau PIN', () async {
    gateway.hasSession = true;
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
    store.values['onboarding_done'] = '1';
    final c = await start();

    await ctrl(c).signOut();
    expect(c.read(authStatusProvider), AuthStatus.signedOut);
    expect(store.values, isEmpty);

    await ctrl(c).verifyOtp(phone, FakeAuthGateway.validCode);
    expect(c.read(authStatusProvider), AuthStatus.pinSetup);
  });

  test('boutique créée mais soldes non saisis → onboarding', () async {
    final c = await start(backend: FakeBackend(boutiqueNom: 'Boutique Awa'));
    await ctrl(c).verifyOtp(phone, FakeAuthGateway.validCode);
    await ctrl(c).createPin('482915');
    expect(c.read(authStatusProvider), AuthStatus.needsOnboarding);
  });

  test('compte supprimé → tout est effacé sur le téléphone', () async {
    gateway.hasSession = true;
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
    store.values['onboarding_done'] = '1';
    store.values['autre_donnee'] = 'x';
    final c = await start();

    await ctrl(c).accountDeleted();
    expect(c.read(authStatusProvider), AuthStatus.signedOut);
    expect(store.values, isEmpty);
    expect(gateway.hasSession, isFalse);
  });

  test('session révoquée par Supabase → OTP', () async {
    gateway.hasSession = true;
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
    final c = await start();

    gateway.revokeSession();
    await pumpEventQueue();
    expect(c.read(authStatusProvider), AuthStatus.signedOut);
  });

  group('verrouillage automatique', () {
    Future<ProviderContainer> unlocked() async {
      gateway.hasSession = true;
      await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
      store.values['onboarding_done'] = '1';
      final c = await start();
      await ctrl(c).unlock('482915');
      return c;
    }

    test('après 3 min en arrière-plan → PIN', () async {
      final c = await unlocked();
      ctrl(c).onAppHidden();
      clock.now = clock.now.add(AuthController.lockAfter);
      ctrl(c).onAppShown();
      expect(c.read(authStatusProvider), AuthStatus.locked);
    });

    test('retour rapide → reste déverrouillé', () async {
      final c = await unlocked();
      ctrl(c).onAppHidden();
      clock.now = clock.now.add(const Duration(minutes: 2));
      ctrl(c).onAppShown();
      expect(c.read(authStatusProvider), AuthStatus.ready);
    });
  });
}
