// Petit checkbox 20×20 — maquette A4 (cgu, id `4hv1W`).
// Coché : fill $primary, icône phosphor `check-bold` blanche.
// Décoché : fill $surface, bord 1 $border.
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

class PilooCheckbox extends StatelessWidget {
  const PilooCheckbox({
    required this.value,
    required this.onChanged,
    this.size = 20,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  // 20 par défaut (CGU A4 inscription), 22 sur l'O2 mentions légales.
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? PilooColors.primary : PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.sm),
          border: value ? null : Border.all(color: PilooColors.border),
        ),
        alignment: Alignment.center,
        child: value
            ? const Icon(
                PhosphorIconsBold.check,
                size: 12,
                color: PilooColors.textOnPrimary,
              )
            : null,
      ),
    );
  }
}
