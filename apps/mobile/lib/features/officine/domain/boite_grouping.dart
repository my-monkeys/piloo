// Modes de regroupement de l'inventaire (#88).
//
// 3 modes proposés à l'utilisateur (cf. dossier-cadrage : "il faut
// pouvoir voir ses médicaments soit par boîte, soit par molécule,
// soit regroupés par nom commercial") :
//
//   - médicament : regroupe les boîtes du même nom commercial (ex.
//     plusieurs Doliprane 1000 mg dans une seule section)
//   - molécule  : regroupe les boîtes de même DCI (ex. Doliprane +
//     Dafalgan apparaissent ensemble sous "Paracétamol")
//   - plat      : pas de regroupement, liste continue (utile pour
//     scanner rapidement la quantité totale de boîtes)
//
// Le module est volontairement séparé de la couche presentation pour
// être testable sans Flutter (cf. AC du ticket : "tests > 95%").

enum BoiteGrouping { medicament, molecule, plat }

/// Une boîte minimale pour le regroupement (nom commercial + DCI).
/// Les écrans peuvent fournir leur propre type tant qu'il expose
/// `name` et `dci`.
abstract class GroupableBoite {
  String get name;
  String get dci;
}

/// Section affichée dans la liste regroupée. `header == null` signale
/// le mode "plat" (aucun titre intermédiaire).
class BoiteSection<T extends GroupableBoite> {
  const BoiteSection({required this.header, required this.boites});
  final String? header;
  final List<T> boites;
}

/// Découpe `all` en sections selon le mode. Préserve l'ordre relatif
/// des boîtes au sein de chaque section (stable). En modes médicament
/// et molécule, l'ordre des sections suit la première occurrence de
/// chaque clé pour éviter de sauter de section quand on filtre.
List<BoiteSection<T>> groupBoites<T extends GroupableBoite>(
  List<T> all,
  BoiteGrouping mode,
) {
  if (mode == BoiteGrouping.plat) {
    return [BoiteSection(header: null, boites: List.unmodifiable(all))];
  }
  String key(T b) =>
      mode == BoiteGrouping.medicament ? b.name : b.dci;

  // LinkedHashMap garde l'ordre d'insertion → ordre des sections
  // = première apparition de la clé.
  final groups = <String, List<T>>{};
  for (final b in all) {
    groups.putIfAbsent(key(b), () => <T>[]).add(b);
  }
  return [
    for (final entry in groups.entries)
      BoiteSection(
        header: entry.key,
        boites: List.unmodifiable(entry.value),
      ),
  ];
}
