// Bouton de retour 40×40 (maquette A4 Header — id `ipRh1`).
// Cercle $surface-subtle + icône phosphor `arrow-left` $text-primary.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';

class PilooCircleBackButton extends StatelessWidget {
  const PilooCircleBackButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PilooColors.surfaceSubtle,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        // Par défaut : pop si possible, sinon repli sur /today — évite
        // les back qui ne font rien quand l'écran a été atteint via
        // context.go (pas d'historique).
        onTap: onPressed ??
            () => context.canPop()
                ? context.pop()
                : context.go(RoutePath.today),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(
              PhosphorIconsRegular.arrowLeft,
              size: 20,
              color: PilooColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
