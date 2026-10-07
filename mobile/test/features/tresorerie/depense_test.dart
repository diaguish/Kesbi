import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/app.dart';
import 'package:kesbi/core/utils/money.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';
import 'package:kesbi/features/tresorerie/data/transaction_store.dart';
import 'package:kesbi/features/tresorerie/domain/transaction.dart';

import '../../support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late FakeAuthGateway gateway;
  late FakeBackend backend;
  late TransactionStore transactions;

  setUp(() async {
    store = InMemorySecureStore()..values['onboarding_done'] = '1';
    gateway = FakeAuthGateway(hasSession: true);
    // Caisse 200 000, Wave 50 000, Orange Money 0.
    backend = FakeBackend.existant();
    transactions = memoryTransactionStore();
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
  });

  Future<void> ouvrirApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(store: store, gateway: gateway, backend: backend, transactions: transactions),
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
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String soldeTotal(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('solde-total'))).data!;

  Future<void> saisirDepense(
    WidgetTester tester,
    String montant, {
    String categorie = 'Transport',
    String compte = 'Caisse',
  }) async {
    await tap(tester, find.text('Dépense'));
    expect(find.text('Nouvelle dépense'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('montant')), montant);
    await tap(tester, find.text(categorie));
    await tap(tester, find.text(compte).last);
    await tap(tester, find.text('Enregistrer'));
  }

  testWidgets('nouvelle dépense → solde diminué, montant négatif envoyé au serveur', (tester) async {
    await ouvrirApp(tester);
    await saisirDepense(tester, '8000');

    expect(find.text('Dépense de ${formatFcfa(8000)} enregistrée'), findsOneWidget);
    expect(soldeTotal(tester), formatFcfa(242000));
    expect(backend.solde('caisse'), 192000);
    final envoyee = backend.transactions.singleWhere((t) => t['type'] == 'depense');
    expect(envoyee['montant'], -8000);
    expect(envoyee['categorie'], 'Transport');
    // Affichée en sortie dans les opérations récentes.
    expect(find.text(formatFcfaSigned(-8000)), findsOneWidget);
  });

  testWidgets('les catégories proposées sont celles des dépenses', (tester) async {
    await ouvrirApp(tester);
    await tap(tester, find.text('Dépense'));
    expect(find.text('Achat de marchandises'), findsOneWidget);
    expect(find.text('Vente comptant'), findsNothing);
    expect(find.text('Compte débité'), findsOneWidget);
    await tap(tester, find.text('Enregistrer'));
    expect(find.text('Indiquez le montant dépensé.'), findsOneWidget);
  });

  testWidgets('dépense qui rendrait le compte négatif : confirmation demandée', (tester) async {
    await ouvrirApp(tester);
    await saisirDepense(tester, '60000', compte: 'Wave');

    expect(find.text('Solde Wave insuffisant'), findsOneWidget);
    await tap(tester, find.text('Corriger'));
    // Rien n'est enregistré, on reste sur le formulaire.
    expect(find.text('Nouvelle dépense'), findsOneWidget);
    expect(backend.solde('wave'), 50000);

    await tap(tester, find.text('Enregistrer'));
    await tap(tester, find.text('Enregistrer quand même'));
    expect(soldeTotal(tester), formatFcfa(190000));
    expect(backend.solde('wave'), -10000);
  });

  testWidgets('dépense dans les limites du solde : pas de confirmation', (tester) async {
    await ouvrirApp(tester);
    await saisirDepense(tester, '50000', compte: 'Wave');
    expect(find.textContaining('insuffisant'), findsNothing);
    expect(backend.solde('wave'), 0);
  });

  testWidgets('hors ligne puis synchronisation (D2)', (tester) async {
    await ouvrirApp(tester);
    backend.online = false;
    await saisirDepense(tester, '5000');
    expect(find.text('1 opération en attente de synchronisation'), findsOneWidget);
    expect(backend.solde('caisse'), 200000);

    backend.online = true;
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(backend.solde('caisse'), 195000);
  });

  testWidgets('annulation d\'une dépense : le solde remonte', (tester) async {
    await ouvrirApp(tester);
    await saisirDepense(tester, '8000');
    await tap(tester, find.text('Transport'));
    await tap(tester, find.text('Annuler cette opération'));
    await tap(tester, find.text("Annuler l'opération"));
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(soldeTotal(tester), formatFcfa(250000));
    expect(find.text('Annulation : Transport'), findsOneWidget);
    expect(backend.solde('caisse'), 200000);
  });

  testWidgets('historique : filtre Dépenses / Encaissements', (tester) async {
    await ouvrirApp(tester);
    await saisirDepense(tester, '8000');
    await tap(tester, find.text('Encaissement'));
    await tester.enterText(find.byKey(const ValueKey('montant')), '3000');
    await tap(tester, find.text('Vente comptant'));
    await tap(tester, find.text('Enregistrer'));

    await tap(tester, find.text('Voir tout'));
    await tap(tester, find.byKey(const ValueKey('type-depenses')));
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Vente comptant'), findsNothing);

    await tap(tester, find.byKey(const ValueKey('type-encaissements')));
    expect(find.text('Vente comptant'), findsOneWidget);
    expect(find.text('Transport'), findsNothing);
  });

  test('signe selon le type de saisie', () {
    expect(TypeSaisie.depense.montantSigne(8000), -8000);
    expect(TypeSaisie.encaissement.montantSigne(8000), 8000);
  });
}
