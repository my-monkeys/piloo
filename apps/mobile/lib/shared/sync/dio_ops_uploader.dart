// Implémentation réelle de OpsUploader via Dio + POST /api/v1/sync/push.
//
// Pourquoi pas le client OpenAPI généré : le schéma SyncOperation est
// une `oneOf` à 3 variantes (create/update/soft_delete boîte) — la
// génération built_value enveloppe ça dans un `OneOf` non-trivial à
// construire depuis nos lignes Drift. Comme la payload locale est déjà
// du JSON sérialisé, on POST le tout au format wire directement avec
// Dio — plus simple et plus robuste aux ajouts de variantes côté
// schéma.
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:piloo/shared/db/local_db.dart';
import 'package:piloo/shared/sync/ops_uploader.dart';

class DioOpsUploader implements OpsUploader {
  DioOpsUploader({
    required Dio dio,
    required String clientId,
  })  : _dio = dio,
        _clientId = clientId;

  final Dio _dio;
  /// `client_id` = identifiant stable du device qui pousse les ops.
  /// Permet au serveur de dédupliquer si le même device retente après
  /// un crash (idempotence). Devrait être stocké en SharedPreferences.
  final String _clientId;

  @override
  Future<OpsUploadResult> upload(PendingOperationRow op) async {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(op.payload) as Map<String, dynamic>;
    } catch (e) {
      // Payload corrompu en local : on rejette définitivement, sinon
      // l'op reste pending éternellement.
      return OpsUploadResult(
        OpsUploadOutcome.rejected,
        error: 'Payload JSON invalide : $e',
      );
    }

    final operation = {
      'id': op.id,
      'type': op.type,
      'entity_type': op.entityType,
      'entity_id': op.entityId,
      'payload': payload,
      'timestamp_local': op.timestampLocal,
    };

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync/push',
        data: {
          'client_id': _clientId,
          'operations': [operation],
        },
        options: Options(
          // Le worker veut savoir transient vs rejected — on intercepte
          // tous les codes ici plutôt que via une exception Dio.
          validateStatus: (_) => true,
        ),
      );
      final status = res.statusCode ?? 0;
      if (status >= 500) {
        return OpsUploadResult(
          OpsUploadOutcome.transient,
          error: 'HTTP $status',
        );
      }
      if (status == 401 || status == 403) {
        // Auth expirée : transient le temps que la session se rafraîchisse.
        return OpsUploadResult(
          OpsUploadOutcome.transient,
          error: 'HTTP $status (auth)',
        );
      }
      if (status != 200) {
        return OpsUploadResult(
          OpsUploadOutcome.rejected,
          error: 'HTTP $status',
        );
      }
      final acks = (res.data?['acks'] as List?) ?? const [];
      if (acks.isEmpty) {
        return const OpsUploadResult(
          OpsUploadOutcome.rejected,
          error: 'Réponse sans ack.',
        );
      }
      final ack = acks.first as Map<String, dynamic>;
      final ackStatus = ack['status'] as String?;
      switch (ackStatus) {
        case 'accepted':
        case 'noop':
        case 'conflict_resolved':
          // `noop` = le serveur avait déjà cette op (replay côté client).
          // `conflict_resolved` = le serveur a appliqué LWW, on garde
          //   l'op comme acceptée et la prochaine pull resynchronisera.
          return const OpsUploadResult(OpsUploadOutcome.accepted);
        case 'rejected':
          return OpsUploadResult(
            OpsUploadOutcome.rejected,
            error: ack['reason'] as String? ?? 'Refusé sans raison.',
          );
        default:
          // Statut inconnu = on considère transient pour ne pas perdre
          // l'op silencieusement.
          return OpsUploadResult(
            OpsUploadOutcome.transient,
            error: 'Statut ack inconnu : $ackStatus',
          );
      }
    } on DioException catch (e) {
      // Timeout, no internet, DNS, etc. → transient.
      return OpsUploadResult(
        OpsUploadOutcome.transient,
        error: e.message ?? e.type.name,
      );
    }
  }
}
