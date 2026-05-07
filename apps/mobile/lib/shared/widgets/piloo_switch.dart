// Switch on/off — maquette O3 Permissions, ids `p2cSw` / `p3cSw`.
// 36×22 pill, knob blanc 18×18, padding 2.
// On : fill $primary. Off : fill $border.
//
// Accessibilité : Semantics(toggled: value) → VoiceOver annonce
// "activé"/"désactivé" et le rôle "switch".
import 'package:flutter/material.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooSwitch extends StatelessWidget {
  const PilooSwitch({
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 36,
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? PilooColors.primary : PilooColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
