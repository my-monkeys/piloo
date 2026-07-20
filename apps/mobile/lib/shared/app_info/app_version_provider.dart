// Version applicative lue à runtime (CFBundleShortVersionString /
// versionName). Source de vérité = pubspec.yaml, dont la CI iOS réécrit
// le build number au tag ios-v*. Remplace la constante hardcodée du
// footer « Plus » qui divergeait de la version réellement shippée (#385).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
