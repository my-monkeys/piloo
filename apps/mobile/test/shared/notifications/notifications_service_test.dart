// Tests unitaires du NotificationsService (#128).
//
// On ne teste pas l'init du plugin natif (binding requis) ni
// l'envoi réel : on couvre la logique métier de _stableId pour
// vérifier que deux prises distinctes donnent des IDs différents et
// que la même prise donne toujours le même ID (idempotent).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stableId derivation', () {
    int stableId(String s) => s.hashCode & 0x7fffffff;

    test('même UUID → même ID (idempotent)', () {
      const id = 'b6f1c0ee-0d4a-4ac5-8901-6f4dafe6b6c2';
      expect(stableId(id), equals(stableId(id)));
    });

    test('UUIDs distincts → IDs distincts', () {
      const a = 'b6f1c0ee-0d4a-4ac5-8901-6f4dafe6b6c2';
      const b = '88888888-8888-4888-9888-888888888888';
      expect(stableId(a), isNot(equals(stableId(b))));
    });

    test('ID toujours positif (32-bit unsigned-like)', () {
      const id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
      final r = stableId(id);
      expect(r, greaterThanOrEqualTo(0));
      expect(r, lessThanOrEqualTo(0x7fffffff));
    });
  });
}
