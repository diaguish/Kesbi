import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/app.dart';
import 'package:kesbi/core/utils/money.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';
import 'package:kesbi/features/tresorerie/data/transaction_store.dart';

import '../../support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late FakeAuthGateway gateway;
  late FakeBackend backend;
  late TransactionStore transactions;

  setUp(() async {
    store = InMemorySecureStore()..values['onboarding_done'] = '1';
    gateway = FakeAuthGateway(hasSession: true);
    backend = FakeBackend.existant();
    transactions = memoryTransactionStore();
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
  });

  Future<void> ouvrirApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(
          store: store,
          gateway: gateway,
          backend: backend,
          transactions: transactions,
        ),
        child: const KesBiApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final digit in '482915'.split('')) {
      await tester.tap(find.widgetWithText(InkWell, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // Élément d'une liste pas encore construit (sous la zone visible) : on fait défiler.
    if (finder.evaluate().isEmpty) {
      await tester.dragUntilVisible(finder, find.byType(ListView).last, const Offset(0, -200));
    }
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String soldeTotal(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('solde-total'))).data!;

  Future<void> saisirEncaissement(WidgetTester tester, String montant, {String compte = 'Caisse'}) async {
    await tap(tester, find.text('Encaissement'));
    await tester.enterText(find.byKey(const ValueKey('montant')), montant);
    await tap(tester, find.text('Vente comptant'));
    await tap(tester, find.text(compte).last);
    await tap(tester, find.text('Enregistrer'));
  }

  testWidgets('soldes du serveur récupérés au déverrouillage', (tester) async {
    await ouvrirApp(tester);
    expect(soldeTotal(tester), formatFcfa(250000));
  });

  testWidgets('nouvel encaissement → solde mis à jour et envoyé au serveur', (tester) async {
    await ouvrirApp(tester);
    await saisirEncaissement(tester, '25000', compte: 'Wave');

    expect(find.text('Encaissement de ${formatFcfa(25000)} enregistré'), findsOneWidget);
    expect(soldeTotal(tester), formatFcfa(275000));
    expect(backend.solde('wave'), 75000);
    expect(find.text('Vente comptant'), findsOneWidget); // opérations récentes
  });

  testWidgets('validation : montant et catégorie obligatoires', (tester) async {
    await ouvrirApp(tester);
    await tap(tester, find.text('Encaissement'));
    await tap(tester, find.text('Enregistrer'));
    expect(find.text('Indiquez le montant encaissé.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('montant')), '5000');
    await tap(tester, find.text('Enregistrer'));
    expect(find.text('Choisissez une catégorie.'), findsOneWidget);
  });

  testWidgets('hors ligne : enregistré quand même, envoyé au retour du réseau', (tester) async {
    await ouvrirApp(tester);
    backend.online = false;
    await saisirEncaissement(tester, '10000');

    expect(soldeTotal(tester), formatFcfa(260000));
    expect(find.text('1 opération en attente de synchronisation'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(backend.solde('caisse'), 200000);

    backend.online = true;
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.textContaining('en attente de synchronisation'), findsNothing);
    expect(backend.solde('caisse'), 210000);
  });

  testWidgets('annulation depuis le détail : solde neutralisé, originale conservée', (tester) async {
    await ouvrirApp(tester);
    await saisirEncaissement(tester, '25000');
    expect(soldeTotal(tester), formatFcfa(275000));

    await tap(tester, find.text('Vente comptant'));
    await tap(tester, find.text('Annuler cette opération'));
    await tap(tester, find.text("Annuler l'opération"));
    expect(find.text('Opération annulée'), findsOneWidget);
    expect(find.text("Voir l'annulation"), findsOneWidget);
    expect(find.text('Annuler cette opération'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(soldeTotal(tester), formatFcfa(250000));
    expect(find.text('Annulation : Vente comptant'), findsOneWidget);
    expect(backend.solde('caisse'), 200000);
    expect(backend.transactions.where((t) => t['type'] == 'encaissement').length, 2);
  });

  testWidgets('historique : filtre par compte', (tester) async {
    await ouvrirApp(tester);
    await saisirEncaissement(tester, '1000', compte: 'Wave');
    await saisirEncaissement(tester, '2000');

    await tap(tester, find.text('Voir tout'));
    expect(find.text('Historique'), findsOneWidget);
    await tap(tester, find.widgetWithText(ChoiceChip, 'Depuis le début'));
    expect(find.text('Vente comptant'), findsNWidgets(2));

    await tap(tester, find.widgetWithText(ChoiceChip, 'Wave'));
    expect(find.text('Vente comptant'), findsOneWidget);
    expect(find.text(formatFcfaSigned(1000)), findsOneWidget);
  });

  testWidgets('déconnexion : les opérations sont effacées du téléphone', (tester) async {
    await ouvrirApp(tester);
    await saisirEncaissement(tester, '1000');
    await tap(tester, find.byTooltip('Profil'));
    await tap(tester, find.text('Se déconnecter'));
    await tap(tester, find.widgetWithText(FilledButton, 'Se déconnecter'));

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(await transactions.list(), isEmpty);
  });
}
