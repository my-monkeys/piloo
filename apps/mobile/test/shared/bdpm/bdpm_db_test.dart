// Tests BdpmDb (#83).
//
// On crée à la volée un fichier SQLite mimant exactement le format
// produit par le générateur côté serveur (#77), pour vérifier que
// la lookup mobile fonctionne sans devoir embarquer le vrai dump.
import 'package:flutter_test/flutter_test.dart';
import 'package:piloo/shared/bdpm/bdpm_db.dart';
import 'package:sqlite3/sqlite3.dart';

Database _buildFixtureDb() {
  final db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE bdpm_metadata (
      key TEXT PRIMARY KEY,
      value TEXT
    ) WITHOUT ROWID;

    CREATE TABLE medicaments (
      cis TEXT PRIMARY KEY,
      cip13 TEXT,
      cip7 TEXT,
      denomination TEXT NOT NULL,
      forme TEXT,
      dosage TEXT,
      voie_administration TEXT,
      titulaire TEXT,
      statut_amm TEXT,
      taux_remboursement INTEGER,
      version_bdpm TEXT NOT NULL
    ) WITHOUT ROWID;

    CREATE INDEX idx_cip13 ON medicaments(cip13) WHERE cip13 IS NOT NULL;
    CREATE INDEX idx_denomination ON medicaments(denomination COLLATE NOCASE);
  ''');

  db.execute(
    "INSERT INTO bdpm_metadata (key, value) VALUES ('version', '2026-05-01')",
  );
  db.execute(
    "INSERT INTO bdpm_metadata (key, value) VALUES ('total_cis', '4')",
  );

  // Fixtures réalistes : Doliprane, Dafalgan (même DCI), Kardegic, Humex.
  final stmt = db.prepare(
    'INSERT INTO medicaments VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  );
  for (final row in const [
    [
      '60002283',
      '3400934567890',
      '3400934567',
      'DOLIPRANE 1000 mg, comprimé pelliculé',
      'comprimé pelliculé',
      '1000 mg',
      'orale',
      'SANOFI AVENTIS FRANCE',
      'Autorisation active',
      65,
      '2026-05-01',
    ],
    [
      '64014219',
      '3400935123456',
      null,
      'DAFALGAN 500 mg, gélule',
      'gélule',
      '500 mg',
      'orale',
      'UPSA',
      'Autorisation active',
      65,
      '2026-05-01',
    ],
    [
      '60404439',
      '3400938765432',
      null,
      'KARDEGIC 75 mg, poudre pour solution buvable en sachet-dose',
      'poudre',
      '75 mg',
      'orale',
      'SANOFI AVENTIS FRANCE',
      'Autorisation active',
      30,
      '2026-05-01',
    ],
    [
      '69603847',
      null,
      null,
      'HUMEX RHUME, comprimé et solution buvable',
      'comprimé',
      null,
      'orale',
      'URGO HEALTHCARE',
      'Autorisation active',
      null,
      '2026-05-01',
    ],
  ]) {
    stmt.execute(row);
  }
  stmt.dispose();
  return db;
}

void main() {
  group('BdpmDb', () {
    test('expose la version et le total CIS depuis bdpm_metadata', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      expect(db.version, '2026-05-01');
      expect(db.totalCis, 4);
      db.close();
    });

    test('findByCip13 retourne le médicament correspondant', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      final med = db.findByCip13('3400934567890')!;
      expect(med.cis, '60002283');
      expect(med.denomination, 'DOLIPRANE 1000 mg, comprimé pelliculé');
      expect(med.dosage, '1000 mg');
      expect(med.tauxRemboursement, 65);
      expect(med.titulaire, 'SANOFI AVENTIS FRANCE');
      db.close();
    });

    test('findByCip13 retourne null si CIP13 absent (cas AC #83)', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      expect(db.findByCip13('9999999999999'), isNull);
      db.close();
    });

    test('searchByDenomination est case-insensitive et trouve plusieurs résultats', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      final hits = db.searchByDenomination('rhume');
      expect(hits, hasLength(1));
      expect(hits.first.cis, '69603847');

      final upperCase = db.searchByDenomination('DOLIPRANE');
      final lowerCase = db.searchByDenomination('doliprane');
      expect(upperCase.first.cis, lowerCase.first.cis);
      db.close();
    });

    test('searchByDenomination échappe les wildcards SQL pour éviter les injections', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      // "%" ne doit pas matcher tous les médicaments — il doit être traité
      // comme un caractère littéral.
      final hits = db.searchByDenomination('%');
      expect(hits, isEmpty);
      db.close();
    });

    test('searchByDenomination respecte le limit', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      final hits = db.searchByDenomination('e', limit: 2);
      expect(hits.length, lessThanOrEqualTo(2));
      db.close();
    });

    test('perf : lookup par CIP13 < 50 ms (AC #83)', () {
      final db = BdpmDb.forTesting(_buildFixtureDb());
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        db.findByCip13('3400934567890');
      }
      stopwatch.stop();
      final avgMs = stopwatch.elapsedMicroseconds / 100 / 1000;
      expect(avgMs, lessThan(50));
      db.close();
    });
  });
}
