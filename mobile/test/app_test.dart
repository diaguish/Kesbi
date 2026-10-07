import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/app.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';

import 'support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late FakeAuthGateway gateway;

  setUp(() {
    store = InMemorySecureStore();
    gateway = FakeAuthGateway();
  });

  Future<void> launch(WidgetTester tester, {FakeBackend? backend}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(store: store, gateway: gateway, backend: backend),
        child: const KesBiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.widgetWithText(InkWell, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> existingUser() async {
    gateway.hasSession = true;
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
    store.values['onboarding_done'] = '1';
  }

  testWidgets('inscription : numéro → code SMS → création du PIN → onboarding', (tester) async {
    await launch(tester);
    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Recevoir le code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Numéro invalide'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '77 000 00 00');
    await tester.tap(find.text('Recevoir le code'));
    await tester.pumpAndSettle();
    expect(gateway.sentTo.single.e164, '+221770000000');
    expect(find.text('Code de vérification'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '999999');
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect ou expiré.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), FakeAuthGateway.validCode);
    await tester.pumpAndSettle();
    expect(find.text('Créez votre code PIN'), findsOneWidget);

    await typePin(tester, '123456');
    expect(find.text('Évitez les suites de chiffres.'), findsOneWidget);

    await typePin(tester, '482915');
    expect(find.text('Confirmez votre code PIN'), findsOneWidget);
    await typePin(tester, '482915');

    expect(find.text('Votre boutique'), findsOneWidget);
  });

  testWidgets('ouverture quotidienne : PIN puis navigation dans l\'app', (tester) async {
    await existingUser();
    await launch(tester);
    expect(find.text('Entrez votre code PIN'), findsOneWidget);

    await typePin(tester, '000001');
    expect(find.text('Code incorrect. Il reste 4 essais.'), findsOneWidget);

    await typePin(tester, '482915');
    expect(find.text('Solde total'), findsOneWidget);

    await tester.tap(find.text('Créances'));
    await tester.pumpAndSettle();
    expect(find.text('Créances — à venir'), findsOneWidget);
  });

  testWidgets('PIN oublié → confirmation → retour au numéro', (tester) async {
    await existingUser();
    await launch(tester);

    await tester.ensureVisible(find.text('Code PIN oublié ?'));
    await tester.tap(find.text('Code PIN oublié ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(gateway.hasSession, isFalse);
    expect(await store.read('pin_hash'), isNull);
  });

  testWidgets('verrouillé : aucun onglet de l\'app accessible', (tester) async {
    await existingUser();
    await launch(tester);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
