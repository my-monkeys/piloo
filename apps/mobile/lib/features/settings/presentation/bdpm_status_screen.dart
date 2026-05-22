// Écran Settings → Base médicaments (BDPM).
//
// Montre :
//   - Version locale du SQLite (clé `version` de bdpm_metadata)
//   - Date/heure de génération côté serveur (clé `generated_at`)
//   - Nombre total de médicaments en base locale
//   - Version serveur courante (live via /api/v1/bdpm/version)
//   - Bouton "Forcer la mise à jour" qui re-trigger BdpmSync
//
// Cas "pas encore téléchargé" : on indique clairement que les lookups
// passent par l'API en fallback (perf dégradée mais fonctionnel).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_sync.dart';
import 'package:piloo/shared/bdpm/bdpm_sync_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class BdpmStatusScreen extends ConsumerStatefulWidget {
  const BdpmStatusScreen({super.key});

  @override
  ConsumerState<BdpmStatusScreen> createState() => _BdpmStatusScreenState();
}

class _BdpmStatusScreenState extends ConsumerState<BdpmStatusScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final sync = await ref.read(bdpmSyncProvider.future);
      final result = await sync.ensureUpToDate();
      if (!mounted) return;
      ref.invalidate(bdpmDbProvider);
      PilooToast.success(context, _outcomeLabel(result.outcome));
    } catch (e) {
      if (!mounted) return;
      PilooToast.error(context, 'Échec : $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _outcomeLabel(BdpmSyncOutcome o) => switch (o) {
        BdpmSyncOutcome.initialDownload => 'Base téléchargée.',
        BdpmSyncOutcome.updated => 'Base mise à jour.',
        BdpmSyncOutcome.upToDate => 'Base déjà à jour.',
        BdpmSyncOutcome.offline => 'Réseau indisponible, base inchangée.',
      };

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(bdpmDbProvider);
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  dbAsync.when(
                    loading: _LoadingCard.new,
                    error: (_, _) => const _NoLocalCard(),
                    data: (db) {
                      if (db == null) return const _NoLocalCard();
                      return _LocalCard(
                        version: db.version,
                        generatedAt: db.generatedAt,
                        totalCis: db.totalCis,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  PilooButton(
                    label: _refreshing
                        ? 'Mise à jour…'
                        : 'Forcer la mise à jour',
                    variant: PilooButtonVariant.primary,
                    onPressed: _refreshing ? null : _refresh,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Les médicaments sont identifiés par leur code CIP13 (sur la boîte). '
                    'Sans base locale, les scans utilisent l\'API en ligne — '
                    'plus lent et nécessite Internet à chaque scan.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PilooCircleBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Base médicaments',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Chargement…',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoLocalCard extends StatelessWidget {
  const _NoLocalCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aucune base locale',
            style: GoogleFonts.fraunces(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: PilooColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Les médicaments sont résolus en ligne via l\'API. Tape sur '
            '"Forcer la mise à jour" pour télécharger la base (~4 Mo).',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: PilooColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalCard extends StatelessWidget {
  const _LocalCard({
    required this.version,
    required this.generatedAt,
    required this.totalCis,
  });

  final String? version;
  final String? generatedAt;
  final int totalCis;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Line(label: 'Version', value: version ?? '—'),
          _Line(label: 'Médicaments', value: _formatCount(totalCis)),
          _Line(
            label: 'Dernière maj',
            value: generatedAt != null ? _formatIso(generatedAt!) : '—',
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// `2026-05-15T08:30:00Z` → `15 mai 2026 à 10:30` (TZ locale).
  static String _formatIso(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    const months = [
      'janv.', 'févr.', 'mars', 'avril', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} à $h:$m';
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: PilooColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          // Expanded plutôt que Spacer+Flexible : sans Expanded, le
          // Text garde sa largeur naturelle et `textAlign.right` n'a pas
          // d'espace pour pousser. Avec Expanded le Text prend toute la
          // largeur restante et l'alignement à droite devient visible.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
