// État partagé du dernier scan réussi (#84).
//
// Le scan_screen pousse un `ScanResult` ici quand il détecte un
// DataMatrix valide. L'écran cible (BoiteAddScreen ou bottom sheet
// "boîte connue") lit l'état pour pré-remplir le form.
//
// Pourquoi pas seulement les query params de la route :
//  - le DataMatrix contient lot + numéro de série + péremption en
//    plus du CIP13 (4 champs vs 1) ; passer tout en URL serait
//    laborieux et exposerait la péremption dans les logs de routage
//  - on veut pouvoir invalider après consommation pour ne pas
//    re-pré-remplir un form si l'utilisateur revient sur l'écran
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/shared/gs1/gs1_parser.dart';

class ScanResult {
  const ScanResult({
    required this.cip13,
    this.lot,
    this.serial,
    this.expiry,
  });

  /// Convertit un `Gs1Parsed` en ScanResult. Retourne null si le
  /// scan n'a pas extrait de CIP13 (DataMatrix incomplet).
  static ScanResult? fromGs1(Gs1Parsed parsed) {
    final cip = parsed.cip13;
    if (cip == null) return null;
    return ScanResult(
      cip13: cip,
      lot: parsed.lot,
      serial: parsed.serial,
      expiry: parsed.expiry,
    );
  }

  final String cip13;
  final String? lot;
  final String? serial;
  final DateTime? expiry;
}

class ScanResultController extends StateNotifier<ScanResult?> {
  ScanResultController() : super(null);

  void set(ScanResult result) => state = result;

  /// À appeler quand l'écran consommateur a fini de pré-remplir, pour
  /// éviter qu'un retour-arrière sur le scan_screen ne re-prefill
  /// avec un ancien scan.
  void clear() => state = null;
}

final scanResultProvider =
    StateNotifierProvider<ScanResultController, ScanResult?>(
  (ref) => ScanResultController(),
);
