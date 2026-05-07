// Interface d'upload des opérations en attente (#91).
//
// L'implémentation réelle (Dio + endpoint /sync/push) viendra dans un
// ticket dédié à #92. Ici on définit juste le contrat pour que le
// worker (#91) soit testable indépendamment de la couche réseau.
//
// Sémantique de retour :
//   - `accepted` : le serveur a appliqué l'op → marquer `acked`
//   - `rejected` : refus définitif (ex: payload invalide) → marquer
//     `rejected`, ne pas retenter
//   - `transient` : panne temporaire (5xx, timeout) → laisser `pending`,
//     incrémenter retry_count
import 'package:piloo/shared/db/local_db.dart';

enum OpsUploadOutcome { accepted, rejected, transient }

class OpsUploadResult {
  const OpsUploadResult(this.outcome, {this.error});
  final OpsUploadOutcome outcome;
  final String? error;
}

abstract class OpsUploader {
  Future<OpsUploadResult> upload(PendingOperationRow op);
}
