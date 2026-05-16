// Badge "X actions en attente de sync" (#95).
//
// Bandeau fin au top de la coquille principale. Visible UNIQUEMENT quand
// `pendingCountProvider` retourne > 0 — sinon `SizedBox.shrink()` pour
// ne pas réserver de hauteur. AnimatedSize lisse l'apparition/disparition.
//
// AC :
//  - Badge disparaît quand pending = 0 → `SizedBox.shrink()` quand 0.
//  - Visible globalement (mount au shell, pas par écran).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/sync/pending_count_provider.dart';

class SyncPendingBadge extends ConsumerWidget {
  const SyncPendingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCount = ref.watch(pendingCountProvider);
    // En cas d'erreur (ex: provider non overridé en test) on cache —
    // pas critique pour l'UX, c'est juste de l'info de fond.
    final count = asyncCount.maybeWhen(data: (n) => n, orElse: () => 0);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: count > 0
          ? Semantics(
              container: true,
              label: '$count actions en attente de synchronisation',
              child: Container(
                width: double.infinity,
                color: PilooColors.surfaceSubtle,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.cloudArrowUp,
                      size: 14,
                      color: PilooColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      count == 1 ? '1 action en attente' : '$count actions en attente',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
