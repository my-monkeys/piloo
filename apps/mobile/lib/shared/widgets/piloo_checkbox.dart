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
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        width: 20,
        height: 20,
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
