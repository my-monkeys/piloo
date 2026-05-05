import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/main.dart';

void main() {
  testWidgets('renders Piloo home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PilooApp());

    expect(find.text('Piloo'), findsOneWidget);
    expect(find.text('Carnet médicaments'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
