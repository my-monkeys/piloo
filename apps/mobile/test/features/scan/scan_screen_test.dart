// Widget tests pour Scan (#82 #80).
//
// Le viewfinder + caméra (état `granted`) ne sont pas testables en
// widget test pur — `MobileScanner` requiert le plugin camera natif.
// On couvre donc :
//  - état `unknown` : loader pendant le check permission
//  - état `denied` : message + bouton "Activer la caméra"
//  - état `restricted` : message + bouton "Ouvrir les réglages"
//  - bouton "Saisie manuelle" toujours visible
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piloo/features/scan/data/camera_permission.dart';
import 'package:piloo/features/scan/presentation/scan_screen.dart';

class _StubController extends StateNotifier<CameraPermissionStatus>
    implements CameraPermissionController {
  _StubController(super.state);

  @override
  Future<void> refresh() async {}
  @override
  Future<void> request() async {}
  @override
  Future<bool> openAppSystemSettings() async => true;
}

Widget _harness(CameraPermissionStatus initial) {
  return ProviderScope(
    overrides: [
      cameraPermissionProvider.overrideWith((ref) => _StubController(initial)),
    ],
    child: const MaterialApp(home: ScanScreen()),
  );
}

void main() {
  group('ScanScreen', () {
    testWidgets('état unknown : loader visible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(CameraPermissionStatus.unknown));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saisie manuelle'), findsOneWidget);
    });

    testWidgets('état denied : message + bouton Activer la caméra',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(CameraPermissionStatus.denied));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Caméra non autorisée'), findsOneWidget);
      expect(find.text('Activer la caméra'), findsOneWidget);
      expect(find.text('Saisie manuelle'), findsOneWidget);
    });

    testWidgets('état restricted : message + bouton Ouvrir les réglages',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(CameraPermissionStatus.restricted));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Caméra bloquée'), findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
      expect(find.text('Saisie manuelle'), findsOneWidget);
    });
  });
}
