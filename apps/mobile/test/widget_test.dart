import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/main.dart';

void main() {
  testWidgets('renders Piloo home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PilooApp());

    expect(find.text('Piloo'), findsOneWidget);
    expect(find.text('Carnet médicaments'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('home screen exposes Piloo theme tokens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PilooApp());

    final BuildContext context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);

    expect(theme.colorScheme.primary, PilooColors.primary);
    expect(theme.scaffoldBackgroundColor, PilooColors.background);
  });
}
