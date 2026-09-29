import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/app.dart';
import 'package:kesbi/features/auth/domain/auth_status.dart';
import 'package:kesbi/features/auth/presentation/auth_status_provider.dart';

void main() {
  testWidgets('démarre sur l\'Accueil et navigue entre les onglets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KesBiApp()));
    await tester.pumpAndSettle();

    expect(find.text('Accueil — à venir'), findsOneWidget);

    await tester.tap(find.text('Créances'));
    await tester.pumpAndSettle();
    expect(find.text('Créances — à venir'), findsOneWidget);
  });

  testWidgets('verrouiller l\'app redirige vers le PIN', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KesBiApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(KesBiApp)));
    container.read(authStatusProvider.notifier).set(AuthStatus.locked);
    await tester.pumpAndSettle();

    expect(find.text('Code PIN — à venir'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
