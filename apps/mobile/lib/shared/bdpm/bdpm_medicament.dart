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
    this.libellePresentation,
    this.container,
    this.totalDoses,
    this.doseUnit,
    this.doseUnitPlural,
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
  /// Présentation brute BDPM ("plaquette PVC-aluminium de 8 comprimés").
  /// Sert de fallback affichage si les champs parsés sont null.
  final String? libellePresentation;
  /// Contenant user-friendly ("boîte", "flacon", "tube", "ampoule"…).
  /// Drive le label "Boîte de N comprimés" sur la fiche.
  final String? container;
  /// Quantité totale dans le conditionnement complet — auto-fill pour
  /// `unitesInitiales` à la création de boîte.
  final int? totalDoses;
  /// Unité singulier ("comprimé", "ml", "g", "ampoule"…). Drive le
  /// wording UI : "Comprimés restants" vs "ml restants".
  final String? doseUnit;
  /// Pluriel ("comprimés", "ml", "g", "ampoules"…) — calculé côté
  /// serveur pour éviter une lib de pluralisation côté mobile.
  final String? doseUnitPlural;

  /// Helper d'affichage : "Boîte de 8 comprimés", "Flacon de 200 ml",
  /// ou fallback `libellePresentation` brut, ou null si rien.
  String? get prettyPresentation {
    final c = container;
    final n = totalDoses;
    final u = (n != null && n > 1 ? doseUnitPlural : doseUnit);
    if (c != null && n != null && u != null) {
      // Évite la redondance "Boîte de 1 boîte" quand on n'a que le contenant.
      if (c == u) return '${_capitalize(c)} unique';
      return '${_capitalize(c)} de $n $u';
    }
    return libellePresentation;
  }

  @override
  String toString() => 'BdpmMedicament($cis, $denomination)';
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
