import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/features/officine/domain/boite_grouping.dart';

class _TestBoite implements GroupableBoite {
  const _TestBoite(this.name, this.dci);
  @override
  final String name;
  @override
  final String dci;
}

void main() {
  const boites = [
    _TestBoite('Doliprane 1000 mg', 'Paracétamol'),
    _TestBoite('Kardegic 75 mg', 'Acide acétylsalicylique'),
    _TestBoite('Doliprane 1000 mg', 'Paracétamol'), // doublon nom
    _TestBoite('Dafalgan 500 mg', 'Paracétamol'), // même DCI, autre nom
    _TestBoite('Metformine 500 mg', 'Metformine'),
  ];

  group('groupBoites', () {
    test('mode plat → 1 section sans header avec tout', () {
      final out = groupBoites(boites, BoiteGrouping.plat);
      expect(out.length, 1);
      expect(out[0].header, isNull);
      expect(out[0].boites.length, 5);
    });

    test('mode médicament → groupe par nom commercial', () {
      final out = groupBoites(boites, BoiteGrouping.medicament);
      expect(out.map((s) => s.header).toList(), [
        'Doliprane 1000 mg',
        'Kardegic 75 mg',
        'Dafalgan 500 mg',
        'Metformine 500 mg',
      ]);
      expect(out.firstWhere((s) => s.header == 'Doliprane 1000 mg').boites.length,
          2);
    });

    test('mode molécule → groupe par DCI', () {
      final out = groupBoites(boites, BoiteGrouping.molecule);
      expect(out.map((s) => s.header).toList(), [
        'Paracétamol',
        'Acide acétylsalicylique',
        'Metformine',
      ]);
      // Doliprane (×2) + Dafalgan dans la section Paracétamol.
      expect(out.firstWhere((s) => s.header == 'Paracétamol').boites.length,
          3);
    });

    test('liste vide → médicament: aucune section', () {
      final out = groupBoites(<_TestBoite>[], BoiteGrouping.medicament);
      expect(out, isEmpty);
    });

    test('liste vide → plat: 1 section vide', () {
      final out = groupBoites(<_TestBoite>[], BoiteGrouping.plat);
      expect(out.length, 1);
      expect(out[0].boites, isEmpty);
    });

    test('ordre des sections suit la première occurrence (stable)', () {
      const inOrder = [
        _TestBoite('B', 'X'),
        _TestBoite('A', 'X'),
        _TestBoite('B', 'X'),
      ];
      final byName = groupBoites(inOrder, BoiteGrouping.medicament);
      expect(byName.map((s) => s.header).toList(), ['B', 'A']);
    });
  });
}
