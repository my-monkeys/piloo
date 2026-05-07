// Radio générique 20×20 (#55).
//
// Pattern : cercle bordé $border ; quand sélectionné, anneau extérieur
// $primary + dot intérieur $primary.
//
// API "groupValue/value" classique Flutter — quand l'utilisateur tape,
// on déclenche `onChanged(value)` (jamais null). C'est à l'appelant de
// stocker `groupValue` et de mettre à jour son state.
//
// Accessibilité : Semantics(checked: value == groupValue) → VoiceOver
// annonce sélectionné/non sélectionné.
import 'package:flutter/material.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooRadio<T> extends StatelessWidget {
  const PilooRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.size = 20,
    this.semanticsLabel,
    super.key,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final dotSize = size * 0.45;
    return Semantics(
      label: semanticsLabel,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.surface,
            border: Border.all(
              color: selected ? PilooColors.primary : PilooColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
