// Tab bar Pill5 — maquette `AtFMv` (TabBar5).
// 4 onglets disposés dans un container pilule blanc avec un slot
// vide au milieu pour laisser passer le ScanFAB. L'onglet actif est
// rempli en $primary avec icône + label blancs.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooTabItem {
  const PilooTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class PilooTabBar extends StatelessWidget {
  const PilooTabBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// 4 items attendus (les 2 premiers à gauche du slot scan, les 2
  /// derniers à droite).
  final List<PilooTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'PilooTabBar attend exactement 4 items');
    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 12, 21, 21),
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: PilooColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _Tab(item: items[0], selected: currentIndex == 0, onTap: () => onTap(0))),
            Expanded(child: _Tab(item: items[1], selected: currentIndex == 1, onTap: () => onTap(1))),
            const Expanded(child: SizedBox.shrink()),
            Expanded(child: _Tab(item: items[2], selected: currentIndex == 2, onTap: () => onTap(2))),
            Expanded(child: _Tab(item: items[3], selected: currentIndex == 3, onTap: () => onTap(3))),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PilooTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? PilooColors.textOnPrimary : PilooColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? PilooColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 16, color: fg),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
