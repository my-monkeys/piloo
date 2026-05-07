// Carte structurelle réutilisable (#53).
//
// Pattern omniprésent dans la maquette : container surface avec border
// fine et radius md ou lg, padding réglable, optionnellement tappable.
//
// Le wrapping Material+InkWell n'est ajouté que si onTap est non null —
// sinon on reste sur un simple Container, qui est moins coûteux à
// rebuild dans les listes longues (Officine, Today).
import 'package:flutter/material.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/core/theme/spacing.dart';

class PilooCard extends StatelessWidget {
  const PilooCard({
    required this.child,
    this.padding = const EdgeInsets.all(PilooSpacing.lg),
    this.radius = PilooRadius.lg,
    this.color,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? PilooColors.surface;
    final effectiveBorder = borderColor ?? PilooColors.border;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: effectiveBorder),
    );

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: effectiveBorder),
        ),
        child: child,
      );
    }

    return Material(
      color: effectiveColor,
      shape: shape,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
