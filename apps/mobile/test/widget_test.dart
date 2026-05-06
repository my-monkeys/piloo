import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/app.dart';
import 'package:piloo/core/theme/colors.dart';

void main() {
  testWidgets('boots PilooApp avec MaterialApp.router', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PilooApp());
    // settle to flush router redirects + frame setup
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });

  testWidgets('expose les tokens Piloo via le thème', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PilooApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.colorScheme.primary, PilooColors.primary);
    expect(theme.scaffoldBackgroundColor, PilooColors.background);
  });
}
