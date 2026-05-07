// Wrapper Riverpod autour de `permission_handler` pour la caméra (#80).
//
// 4 états utiles à l'UI :
//   - unknown      : avant le 1er request, on ne sait pas
//   - granted      : caméra utilisable
//   - denied       : refusé une fois, on peut redemander
//   - restricted   : refusé définitivement (toggle iOS Settings) ou
//                    politique parentale → on doit linker vers les
//                    réglages système, le re-prompt ne fera rien
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionStatus { unknown, granted, denied, restricted }

class CameraPermissionController extends StateNotifier<CameraPermissionStatus> {
  CameraPermissionController() : super(CameraPermissionStatus.unknown);

  /// Vérifie le statut courant sans déclencher de prompt système.
  Future<void> refresh() async {
    final s = await Permission.camera.status;
    state = _mapStatus(s);
  }

  /// Demande la permission. Si l'utilisateur a déjà refusé définitivement,
  /// `request()` retourne immédiatement `permanentlyDenied` sans afficher
  /// le prompt — l'UI doit alors linker vers les réglages système.
  Future<void> request() async {
    final s = await Permission.camera.request();
    state = _mapStatus(s);
  }

  /// Ouvre les réglages système — utilisé sur le bouton "Ouvrir réglages"
  /// quand on est en `restricted`.
  Future<bool> openAppSystemSettings() => openAppSettings();

  static CameraPermissionStatus _mapStatus(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return CameraPermissionStatus.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return CameraPermissionStatus.restricted;
    }
    return CameraPermissionStatus.denied;
  }
}

final cameraPermissionProvider =
    StateNotifierProvider<CameraPermissionController, CameraPermissionStatus>(
  (ref) => CameraPermissionController(),
);
