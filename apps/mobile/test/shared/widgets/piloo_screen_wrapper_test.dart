// Tests pour PilooScreenWrapper (#53).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_screen_wrapper.dart';

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  group('PilooScreenWrapper', () {
    testWidgets('rend Scaffold + SafeArea + bg background par défaut',
        (tester) async {
      await tester.pumpWidget(_app(const PilooScreenWrapper(
        child: Text('contenu'),
      )));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, PilooColors.background);

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.bottom, false); // défaut : pas de safe-area bottom

      expect(find.text('contenu'), findsOneWidget);
    });

    testWidgets('safeAreaBottom: true active la SafeArea bottom',
        (tester) async {
      await tester.pumpWidget(_app(const PilooScreenWrapper(
        safeAreaBottom: true,
        child: SizedBox.shrink(),
      )));
      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.bottom, true);
    });

    testWidgets('backgroundColor override appliqué', (tester) async {
      const override = Color(0xFF123456);
      await tester.pumpWidget(_app(const PilooScreenWrapper(
        backgroundColor: override,
        child: SizedBox.shrink(),
      )));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, override);
    });

    testWidgets('statusBarBrightness dark (par défaut) → icônes dark',
        (tester) async {
      await tester.pumpWidget(_app(const PilooScreenWrapper(
        child: SizedBox.shrink(),
      )));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('statusBarBrightness light → icônes light (pour bg sombre)',
        (tester) async {
      await tester.pumpWidget(_app(const PilooScreenWrapper(
        statusBarBrightness: Brightness.light,
        child: SizedBox.shrink(),
      )));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
    });
  });
}
