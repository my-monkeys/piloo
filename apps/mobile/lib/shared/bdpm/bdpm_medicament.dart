// Représentation d'un médicament BDPM côté mobile.
//
// Mirroir read-only de la table SQLite générée côté serveur (#77).
// Tous les champs sauf `cis` et `denomination` peuvent être nuls
// (la BDPM est incomplète sur certains médicaments anciens).

class BdpmMedicament {
  const BdpmMedicament({
    required this.cis,
    required this.denomination,
    this.cip13,
    this.cip7,
    this.forme,
    this.dosage,
    this.voieAdministration,
    this.titulaire,
    this.statutAmm,
    this.tauxRemboursement,
    this.aiSummary,
  });

  final String cis;
  final String denomination;
  final String? cip13;
  final String? cip7;
  final String? forme;
  final String? dosage;
  final String? voieAdministration;
  final String? titulaire;
  final String? statutAmm;
  final int? tauxRemboursement;
  /// Résumé IA pré-généré (#167). Null tant que la pipeline LLM
  /// (#165) ne l'a pas rempli — l'UI affiche dans ce cas un
  /// placeholder "résumé bientôt disponible".
  final String? aiSummary;

  @override
  String toString() => 'BdpmMedicament($cis, $denomination)';
}
