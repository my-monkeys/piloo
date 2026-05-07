// Persistence du choix de regroupement (#88).
//
// Stockage SharedPreferences (key non-sensible, pas besoin de chiffrer
// via flutter_secure_storage). Si la clé est absente ou corrompue, on
// retombe sur `BoiteGrouping.medicament` (défaut produit).
import 'package:shared_preferences/shared_preferences.dart';

import 'package:piloo/features/officine/domain/boite_grouping.dart';

const _kPrefKey = 'officine.grouping';

/// Lit le mode de regroupement persisté. Retourne le défaut si absent.
Future<BoiteGrouping> readBoiteGrouping() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kPrefKey);
  return _parseOrDefault(raw);
}

/// Persiste le mode choisi. Best-effort : on n'attend pas le résultat
/// dans l'UI puisqu'une erreur d'écriture n'est pas bloquante (le
/// défaut sera réappliqué au prochain lancement).
Future<void> writeBoiteGrouping(BoiteGrouping mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kPrefKey, mode.name);
}

BoiteGrouping _parseOrDefault(String? raw) {
  if (raw == null) return BoiteGrouping.medicament;
  for (final v in BoiteGrouping.values) {
    if (v.name == raw) return v;
  }
  return BoiteGrouping.medicament;
}
