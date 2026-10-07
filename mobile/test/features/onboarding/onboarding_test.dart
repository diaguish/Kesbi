import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/app.dart';
import 'package:kesbi/core/utils/money.dart';
import 'package:kesbi/features/auth/data/pin_repository.dart';

import '../../support/fakes.dart';

void main() {
  late InMemorySecureStore store;
  late FakeAuthGateway gateway;

  setUp(() async {
    store = InMemorySecureStore();
    // Utilisateur connecté (OTP fait) avec un PIN, onboarding pas terminé.
    gateway = FakeAuthGateway(hasSession: true);
    await PinRepository(store, iterations: 10, runHash: (c) => c()).setPin('482915');
  });

  Future<void> launch(WidgetTester tester, FakeBackend backend) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(store: store, gateway: gateway, backend: backend),
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

  Future<void> tap(WidgetTester tester, String texte) async {
    await tester.ensureVisible(find.text(texte));
    await tester.tap(find.text(texte));
    await tester.pumpAndSettle();
  }

  const titreSoldes = "Combien avez-vous aujourd'hui ?";

  testWidgets("création de la boutique puis soldes d'ouverture → Accueil", (tester) async {
    final backend = FakeBackend();
    await launch(tester, backend);
    expect(find.text('Votre boutique'), findsOneWidget);

    await tap(tester, 'Continuer');
    expect(find.text('Indiquez le nom de votre boutique.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nom de la boutique'), 'Boutique Awa');
    await tap(tester, 'Alimentation');
    await tap(tester, 'Continuer');
    expect(backend.boutiqueNom, 'Boutique Awa');
    expect(find.text(titreSoldes), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('solde-caisse')), '200000');
    await tester.enterText(find.byKey(const ValueKey('solde-wave')), '50000');
    await tester.pump();
    expect(find.text('Total : ${formatFcfa(250000)}'), findsOneWidget);

    await tap(tester, 'Valider');
    expect(backend.ouvertures, {'caisse': 200000, 'wave': 50000, 'orange_money': 0});
    expect(find.text('Solde total'), findsOneWidget);
    expect(find.text(formatFcfa(250000)), findsOneWidget);
    expect(store.values['onboarding_done'], '1');
  });

  testWidgets('« Ignorer » enregistre 0 sur chaque compte', (tester) async {
    final backend = FakeBackend(boutiqueNom: 'Boutique Awa');
    await launch(tester, backend);
    // Boutique déjà créée : reprise directement à l'étape des soldes.
    expect(find.text(titreSoldes), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('solde-caisse')), '1000');
    await tap(tester, 'Ignorer (tout à 0)');
    expect(backend.ouvertures, {'caisse': 0, 'wave': 0, 'orange_money': 0});
    expect(find.text('Solde total'), findsOneWidget);
  });

  testWidgets('reprise après une coupure : les soldes déjà envoyés ne bloquent pas', (tester) async {
    final backend = FakeBackend(boutiqueNom: 'Boutique Awa', ouvertures: {'caisse': 5000});
    await launch(tester, backend);
    await tap(tester, 'Valider');
    expect(backend.ouvertures.length, 3);
    expect(find.text('Solde total'), findsOneWidget);
  });

  testWidgets('hors ligne : message clair et bouton Réessayer', (tester) async {
    final backend = FakeBackend()..online = false;
    await launch(tester, backend);
    expect(find.text('Connexion nécessaire'), findsOneWidget);
    expect(find.textContaining('Pas de connexion internet'), findsOneWidget);

    backend.online = true;
    await tap(tester, 'Réessayer');
    expect(find.text('Votre boutique'), findsOneWidget);
  });

  testWidgets("erreur serveur à la création : message affiché, on reste sur l'étape", (tester) async {
    final backend = FakeBackend();
    await launch(tester, backend);
    await tester.enterText(find.widgetWithText(TextField, 'Nom de la boutique'), 'Boutique Awa');
    backend.prochaineErreur = 400;
    await tap(tester, 'Continuer');
    expect(find.text('Erreur simulée'), findsOneWidget);
    expect(find.text('Votre boutique'), findsOneWidget);
  });

  group('profil', () {
    setUp(() => store.values['onboarding_done'] = '1');

    Future<void> ouvrirProfil(WidgetTester tester, FakeBackend backend) async {
      await launch(tester, backend);
      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
    }

    Future<void> confirmerSuppression(WidgetTester tester, String saisie) async {
      await tap(tester, 'Supprimer mon compte');
      await tester.enterText(find.byType(TextField), saisie);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
    }

    testWidgets('affiche la boutique et le numéro', (tester) async {
      await ouvrirProfil(tester, FakeBackend.existant());
      expect(find.text('Boutique Awa'), findsOneWidget);
      expect(find.text('+221 77 000 00 00'), findsOneWidget);
    });

    testWidgets('bouton Supprimer inactif tant que SUPPRIMER n\'est pas tapé', (tester) async {
      await ouvrirProfil(tester, FakeBackend.existant());
      await tap(tester, 'Supprimer mon compte');
      final bouton = find.widgetWithText(FilledButton, 'Supprimer');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'supprim');
      await tester.pump();
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
    });

    testWidgets("suppression de compte → tout est effacé, retour à l'inscription", (tester) async {
      final backend = FakeBackend.existant();
      await ouvrirProfil(tester, backend);
      await confirmerSuppression(tester, 'supprimer');

      expect(backend.compteSupprime, isTrue);
      expect(store.values, isEmpty);
      expect(gateway.hasSession, isFalse);
      expect(find.text('Bienvenue'), findsOneWidget);
    });

    testWidgets("suppression hors ligne : rien n'est effacé sur le téléphone", (tester) async {
      final backend = FakeBackend.existant();
      await ouvrirProfil(tester, backend);
      backend.online = false;
      await confirmerSuppression(tester, 'SUPPRIMER');

      expect(find.textContaining('Pas de connexion internet'), findsOneWidget);
      expect(store.values['pin_hash'], isNotNull);
      expect(gateway.hasSession, isTrue);
    });

    testWidgets('annuler la suppression ne fait rien', (tester) async {
      final backend = FakeBackend.existant();
      await ouvrirProfil(tester, backend);
      await tap(tester, 'Supprimer mon compte');
      await tap(tester, 'Annuler');
      expect(backend.compteSupprime, isFalse);
      expect(find.text('Profil'), findsOneWidget);
    });
  });
}
