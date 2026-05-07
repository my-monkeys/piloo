import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/shared/gs1/gs1_parser.dart';

void main() {
  group('parseGs1 — cas standards FR (#81)', () {
    test('AI 01 + 17 (ordre fabricant)', () {
      const input = '01034009345678901727083100';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.expiry, DateTime(2027, 8, 31));
      expect(r.lot, isNull);
      expect(r.serial, isNull);
    });

    test('AI 01 + 17 + 10 (lot termine la chaîne)', () {
      const input = '01034009345678901727083110LOT123';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.expiry, DateTime(2027, 8, 31));
      expect(r.lot, 'LOT123');
      expect(r.serial, isNull);
    });

    test('AI 01 + 17 + 10 + 21 avec FNC1 réel (0x1D) entre variables', () {
      const input = '01034009345678901727083110LOT123\x1d21SER42';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.expiry, DateTime(2027, 8, 31));
      expect(r.lot, 'LOT123');
      expect(r.serial, 'SER42');
    });

    test('cip13 dérivé du GTIN-14 (drop leading zero)', () {
      const input = '01034009345678901727083100';
      final r = parseGs1(input);
      expect(r.cip13, '3400934567890');
    });

    test('jour 00 → dernier jour du mois', () {
      const input = '01034009345678901727020010ABC';
      final r = parseGs1(input);
      // Février 2027 a 28 jours.
      expect(r.expiry, DateTime(2027, 2, 28));
    });

    test('jour 00 février année bissextile', () {
      // 2028 est bissextile.
      const input = '01034009345678901728020010ABC';
      final r = parseGs1(input);
      expect(r.expiry, DateTime(2028, 2, 29));
    });
  });

  group('parseGs1 — tolérance FNC1 / préfixes', () {
    test('symbology identifier ]d2 retiré', () {
      const input = ']d201034009345678901727083110LOT123';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.lot, 'LOT123');
    });

    test('symbology identifier ]C1 retiré', () {
      const input = ']C101034009345678901727083110LOT123';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.lot, 'LOT123');
    });

    test('FNC1 textuel <GS> traité comme séparateur', () {
      const input = '01034009345678901727083110LOT123<GS>21SER42';
      final r = parseGs1(input);
      expect(r.lot, 'LOT123');
      expect(r.serial, 'SER42');
    });

    test('FNC1 textuel ~F traité comme séparateur', () {
      const input = '01034009345678901727083110LOT123~F21SER42';
      final r = parseGs1(input);
      expect(r.lot, 'LOT123');
      expect(r.serial, 'SER42');
    });

    test('séparateur RS 0x1E traité comme FNC1', () {
      const input = '01034009345678901727083110LOT123\x1e21SER42';
      final r = parseGs1(input);
      expect(r.lot, 'LOT123');
      expect(r.serial, 'SER42');
    });

    test('espaces résiduels en fin de champ variable trimmés', () {
      const input = '01034009345678901727083110LOT123  \x1d21SER42';
      final r = parseGs1(input);
      expect(r.lot, 'LOT123');
      expect(r.serial, 'SER42');
    });
  });

  group('parseGs1 — robustesse', () {
    test('chaîne vide → résultat vide', () {
      final r = parseGs1('');
      expect(r.isEmpty, isTrue);
    });

    test('AI 17 mois invalide → expiry null mais autres champs lus', () {
      const input = '01034009345678901727131510LOT';
      final r = parseGs1(input);
      // Le parseur consomme les 6 chars de l'AI 17 même si la date est
      // invalide ; ça évite de désynchroniser le pointeur.
      expect(r.gtin, '03400934567890');
      expect(r.expiry, isNull);
      expect(r.lot, 'LOT');
    });

    test('AI 17 jour invalide (32) → expiry null', () {
      const input = '01034009345678901727013210LOT';
      final r = parseGs1(input);
      expect(r.expiry, isNull);
      expect(r.lot, 'LOT');
    });

    test('AI 17 lettres au lieu de chiffres → expiry null', () {
      const input = '0103400934567890172708AB10LOT';
      final r = parseGs1(input);
      expect(r.expiry, isNull);
      expect(r.lot, 'LOT');
    });

    test('AI inconnue variable remontée dans unknownAis', () {
      // AI 91 = données privées variable (hors périmètre).
      const input = '01034009345678901727083191HELLO\x1d21SER42';
      final r = parseGs1(input);
      expect(r.unknownAis, contains('91'));
      expect(r.serial, 'SER42');
    });

    test('AI fixe inconnue dans la table → consommée silencieusement', () {
      // AI 11 (date production, 6 chars fixe) — on saute.
      const input = '0103400934567890112501011727083110LOT';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.expiry, DateTime(2027, 8, 31));
      expect(r.lot, 'LOT');
    });

    test('GTIN ne commence pas par 0 → cip13 null', () {
      const input = '0112345678901234';
      final r = parseGs1(input);
      expect(r.gtin, '12345678901234');
      expect(r.cip13, isNull);
    });

    test('AI 10 longue (lot 20 chars max) sans FNC1 → tout pris', () {
      const input = '01034009345678901727083110ABCDEFGHIJKLMNOPQRST';
      final r = parseGs1(input);
      expect(r.lot, 'ABCDEFGHIJKLMNOPQRST');
    });

    test('chaîne tronquée au milieu d\'un AI fixe → arrêt propre', () {
      // AI 17 incomplet (4 chars au lieu de 6).
      const input = '010340093456789017270';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.expiry, isNull);
    });

    test('AI non numérique en cours de parsing → arrêt propre', () {
      // Après GTIN + AI 17 valide, du texte parasite "XX" (pas un AI).
      const input = '010340093456789017270831XX';
      final r = parseGs1(input);
      expect(r.gtin, '03400934567890');
      expect(r.expiry, DateTime(2027, 8, 31));
      expect(r.lot, isNull);
    });
  });
}
