// Wrapper read-only autour du fichier SQLite BDPM (#83).
//
// Le fichier est généré côté serveur (#77) et téléchargé au 1er
// lancement (#78) ou à chaque update (#79). Il vit dans le dossier
// documents de l'app et reste verrouillé en read-only au runtime.
//
// Le lookup par CIP13 est le chemin critique post-scan : doit rester
// sous 50 ms (AC #83). Avec l'index `idx_cip13` côté serveur,
// la requête prend < 1 ms en pratique.
import 'package:sqlite3/sqlite3.dart';

import 'bdpm_medicament.dart';

class BdpmDb {
  BdpmDb._(this._db);

  final Database _db;

  /// Ouvre le fichier `.sqlite` BDPM en read-only. Lève si le fichier
  /// est absent — la couche au-dessus (BdpmSync) gère ce cas en
  /// déclenchant un téléchargement.
  factory BdpmDb.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    return BdpmDb._(db);
  }

  /// Pour les tests : ouvre un Database fourni (in-memory ou temp file).
  factory BdpmDb.forTesting(Database db) => BdpmDb._(db);

  /// Version du dump BDPM intégré à ce fichier (YYYY-MM-DD).
  /// Retourne null si la table metadata est absente (vieux fichier).
  String? get version {
    final result = _db
        .select("SELECT value FROM bdpm_metadata WHERE key = 'version' LIMIT 1");
    if (result.isEmpty) return null;
    final v = result.first['value'] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  /// ISO timestamp de la génération du SQLite côté serveur (`generated_at`).
  /// Retourne null si la table metadata est absente ou la clé manquante.
  String? get generatedAt {
    final result = _db.select(
      "SELECT value FROM bdpm_metadata WHERE key = 'generated_at' LIMIT 1",
    );
    if (result.isEmpty) return null;
    final v = result.first['value'] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Nombre total de CIS en base.
  int get totalCis {
    final result = _db.select(
      "SELECT value FROM bdpm_metadata WHERE key = 'total_cis' LIMIT 1",
    );
    if (result.isEmpty) return 0;
    return int.tryParse(result.first['value'] as String? ?? '') ?? 0;
  }

  /// Lookup principal post-scan. Retourne null si le CIP13 est absent
  /// (médicament hors BDPM, scan partiel, code falsifié…).
  BdpmMedicament? findByCip13(String cip13) {
    final result = _db.select(
      'SELECT * FROM medicaments WHERE cip13 = ? LIMIT 1',
      [cip13],
    );
    if (result.isEmpty) return null;
    return _rowToMedicament(result.first);
  }

  /// Recherche fuzzy par nom commercial (LIKE COLLATE NOCASE).
  /// Limité à 20 résultats pour rester réactif sur les requêtes
  /// génériques type "para".
  List<BdpmMedicament> searchByDenomination(String query, {int limit = 20}) {
    if (query.trim().isEmpty) return const [];
    final pattern = '%${query.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final result = _db.select(
      'SELECT * FROM medicaments '
      "WHERE denomination LIKE ? ESCAPE '\\' "
      'ORDER BY denomination COLLATE NOCASE LIMIT ?',
      [pattern, limit],
    );
    return result.map(_rowToMedicament).toList(growable: false);
  }

  void close() => _db.dispose();

  static BdpmMedicament _rowToMedicament(Row row) {
    // `ai_summary` peut ne pas exister dans les vieux SQLite (avant
    // distribution #167) — on tolère via columnNames check.
    final hasAi = row.keys.contains('ai_summary');
    return BdpmMedicament(
      cis: row['cis'] as String,
      denomination: row['denomination'] as String,
      cip13: row['cip13'] as String?,
      cip7: row['cip7'] as String?,
      forme: row['forme'] as String?,
      dosage: row['dosage'] as String?,
      voieAdministration: row['voie_administration'] as String?,
      titulaire: row['titulaire'] as String?,
      statutAmm: row['statut_amm'] as String?,
      tauxRemboursement: row['taux_remboursement'] as int?,
      aiSummary: hasAi ? row['ai_summary'] as String? : null,
    );
  }
}
