import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/app.dart';
import 'package:piloo/core/router/router.dart';
import 'package:piloo/core/storage/secure_storage.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/onboarding/data/demo_mode_provider.dart';

Widget _harness() {
  final inMemory = InMemorySecureStorage();
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        SessionStorage(inMemory),
      ),
      secureStorageProvider.overrideWithValue(inMemory),
      routerProvider.overrideWithValue(buildRouter()),
    ],
    child: const PilooApp(),
  );
}

void main() {
  testWidgets('boots PilooApp avec MaterialApp.router', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness());
    // pump quelques frames sans pumpAndSettle (le splash a une
    // animation infinie de loader dots).
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

    // Drain le redirect timer du splash (1.2s) avant la fin du test.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('expose les tokens Piloo via le thème', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 50));

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.colorScheme.primary, PilooColors.primary);
    expect(theme.scaffoldBackgroundColor, PilooColors.background);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });
}
