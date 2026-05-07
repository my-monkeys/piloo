// Wrapper d'écran : Scaffold + bg theme + status bar overlay style +
// SafeArea (#53).
//
// Capture le pattern répété dans tous les écrans de l'app :
//   Scaffold(backgroundColor: PilooColors.background,
//     body: SafeArea(bottom: false, child: ...))
//
// `safeAreaBottom: false` par défaut car l'app a une TabBar qui
// gère son propre safe-area — un padding bottom doublerait l'espace.
// Les écrans sans TabBar (sign-in, scan plein écran) passent
// `safeAreaBottom: true`.
//
// `statusBarBrightness` permet d'imposer une barre claire (icônes
// noires, fond clair) sur les écrans avec un AppBar par-dessus, ou
// l'inverse sur les écrans dark (scan plein écran).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooScreenWrapper extends StatelessWidget {
  const PilooScreenWrapper({
    required this.child,
    this.backgroundColor,
    this.safeAreaBottom = false,
    this.statusBarBrightness = Brightness.dark,
    super.key,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool safeAreaBottom;

  /// `Brightness.dark` = icônes status bar foncées (sur fond clair),
  /// `Brightness.light` = icônes claires (sur fond sombre).
  final Brightness statusBarBrightness;

  @override
  Widget build(BuildContext context) {
    final isDarkIcons = statusBarBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkIcons ? Brightness.dark : Brightness.light,
        statusBarBrightness: isDarkIcons ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor ?? PilooColors.background,
        body: SafeArea(bottom: safeAreaBottom, child: child),
      ),
    );
  }
}
