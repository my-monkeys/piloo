// Provider Riverpod pour l'OCR ordonnance (#152).
//
// Pick une photo (galerie ou camera) → l'envoie à POST /v1/ocr/ordonnance
// → retourne la structure parsée (prescripteur, date, prescriptions[]).
//
// L'utilisateur valide ensuite ligne par ligne dans
// ordonnance_create_screen avant de POST la création réelle.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/shared/api/api_client_provider.dart';

/// Source de la photo : appareil photo ou galerie.
enum OcrPhotoSource { camera, gallery }

/// Résultat parsé pour pré-remplir le formulaire create ordonnance.
class OcrOrdonnanceResult {
  const OcrOrdonnanceResult({
    required this.prescripteur,
    required this.datePrescription,
    required this.notes,
    required this.prescriptions,
  });

  final String? prescripteur;
  /// YYYY-MM-DD ou null.
  final String? datePrescription;
  final String? notes;
  final List<OcrPrescription> prescriptions;
}

class OcrPrescription {
  const OcrPrescription({
    required this.nomTexte,
    this.unitesParPrise,
    this.unite,
    this.frequence,
    this.dureeJours,
    this.indication,
  });

  final String nomTexte;
  final num? unitesParPrise;
  final String? unite;
  final String? frequence;
  final int? dureeJours;
  final String? indication;
}

/// Pick + upload + parse. Retourne null si l'utilisateur annule le
/// picker.
Future<OcrOrdonnanceResult?> pickAndOcr(
  WidgetRef ref, {
  required OcrPhotoSource source,
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source == OcrPhotoSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    // Compress modéré pour bien rester sous la limite 8 Mo base64 de
    // l'API tout en gardant assez de définition pour le texte.
    imageQuality: 80,
    maxWidth: 2400,
  );
  if (picked == null) return null;

  final bytes = await File(picked.path).readAsBytes();
  final b64 = base64Encode(bytes);
  final mime = _mimeFromPath(picked.path);

  final client = ref.read(pilooApiClientProvider).getOcrApi();
  final builder = api.OcrOrdonnanceInputBuilder()
    ..imageBase64 = b64
    ..mimeType = _mimeToEnum(mime);
  final res = await client.v1OcrOrdonnancePost(
    ocrOrdonnanceInput: builder.build(),
  );
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('OCR : statut ${res.statusCode}');
  }
  final data = res.data!;
  return OcrOrdonnanceResult(
    prescripteur: data.prescripteur,
    datePrescription: _formatDate(data.datePrescription),
    notes: data.notes,
    prescriptions: data.prescriptions
        .map((p) => OcrPrescription(
              nomTexte: p.nomTexte,
              unitesParPrise: p.unitesParPrise,
              unite: p.unite,
              frequence: p.frequence,
              dureeJours: p.dureeJours,
              indication: p.indication,
            ))
        .toList(growable: false),
  );
}

String? _formatDate(api.Date? d) {
  if (d == null) return null;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _mimeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

api.OcrOrdonnanceInputMimeTypeEnum _mimeToEnum(String mime) {
  switch (mime) {
    case 'image/png':
      return api.OcrOrdonnanceInputMimeTypeEnum.imageSlashPng;
    case 'image/webp':
      return api.OcrOrdonnanceInputMimeTypeEnum.imageSlashWebp;
    case 'image/heic':
      return api.OcrOrdonnanceInputMimeTypeEnum.imageSlashHeic;
    default:
      return api.OcrOrdonnanceInputMimeTypeEnum.imageSlashJpeg;
  }
}
