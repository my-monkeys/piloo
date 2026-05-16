// Tests SyncPendingBadge (#95).
//
// Override le `pendingCountProvider` pour piloter le compteur sans
// monter de DB. AC : badge invisible quand count == 0, visible quand > 0,
// label correct (singulier/pluriel).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/shared/sync/pending_count_provider.dart';
import 'package:piloo/shared/widgets/sync_pending_badge.dart';

Widget _withCount(AsyncValue<int> value) {
  return ProviderScope(
    overrides: [
      pendingCountProvider.overrideWith((_) => Stream.value(switch (value) {
            AsyncData(:final value) => value,
            _ => 0,
          })),
    ],
    child: const MaterialApp(home: Scaffold(body: SyncPendingBadge())),
  );
}

void main() {
  group('SyncPendingBadge', () {
    testWidgets('count == 0 : pas de bandeau visible', (tester) async {
      await tester.pumpWidget(_withCount(const AsyncData(0)));
      await tester.pumpAndSettle();

      // Aucun texte du badge n'est visible.
      expect(find.textContaining('en attente'), findsNothing);
    });

    testWidgets('count == 1 : singulier "1 action en attente"', (tester) async {
      await tester.pumpWidget(_withCount(const AsyncData(1)));
      await tester.pumpAndSettle();
      expect(find.text('1 action en attente'), findsOneWidget);
    });

    testWidgets('count > 1 : pluriel "N actions en attente"', (tester) async {
      await tester.pumpWidget(_withCount(const AsyncData(3)));
      await tester.pumpAndSettle();
      expect(find.text('3 actions en attente'), findsOneWidget);
    });

    testWidgets('AsyncLoading / AsyncError : badge masqué (orElse → 0)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingCountProvider.overrideWith((_) => const Stream.empty()),
          ],
          child: const MaterialApp(home: Scaffold(body: SyncPendingBadge())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('en attente'), findsNothing);
    });
  });
}
