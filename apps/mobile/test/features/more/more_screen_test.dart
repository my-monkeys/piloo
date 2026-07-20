// Widget tests pour Plus / Paramètres (#151).
//
// Le profil est maintenant tiré de sessionProvider. On override avec
// une session test pour vérifier que name/email/initiales apparaissent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/features/auth/data/session.dart';
import 'package:piloo/features/auth/data/session_storage.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/more/presentation/more_screen.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';

class _FakeSessionStorage implements SessionStorage {
  _FakeSessionStorage(this._session);

  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

Widget _harness() {
  const session = Session(
    token: 'tok',
    userId: 'u1',
    email: 'alice@test.fr',
    name: 'Alice Doe',
  );
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(_FakeSessionStorage(session)),
      officinesListProvider
          .overrideWith((_) async => const <api.Officine>[]),
    ],
    child: const MaterialApp(home: MoreScreen()),
  );
}

void main() {
  group('MoreScreen', () {
    testWidgets('rendu : header + profil + 3 sections + logout',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Plus'), findsOneWidget);

      // Profil dérivé de la session test
      expect(find.text('AD'), findsOneWidget); // initiales Alice Doe
      expect(find.text('Alice Doe'), findsOneWidget);
      expect(find.text('alice@test.fr'), findsOneWidget);

      // 3 sections
      expect(find.text('MON APP'), findsOneWidget);
      expect(find.text('PRÉFÉRENCES'), findsOneWidget);
      expect(find.text('AIDE & LÉGAL'), findsOneWidget);

      // Rows
      expect(find.text('Mes officines'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Horaires par défaut'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
      expect(find.text("Ce n'est pas un dispositif médical"), findsOneWidget);

      expect(find.text('Se déconnecter'), findsOneWidget);

      // Accès direct à la suppression de compte (#385) — en plus de
      // celui du Profil, pour la découvrabilité (review Apple 5.1.1(v)).
      expect(find.text('Supprimer mon compte'), findsOneWidget);
    });
  });
}
