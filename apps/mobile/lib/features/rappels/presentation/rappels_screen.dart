// Écran "Mes rappels" — liste des rappels de l'officine active (#355).
// Tâches B2 + B3 : route + liste avec pause/suppression.
// L'édition (B5) est hors scope ici — les cartes ne sont pas tappables.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/rappels/data/rappels_provider.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';

class RappelsScreen extends ConsumerWidget {
  const RappelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officineAsync = ref.watch(activeOfficineProvider);
    final officine = officineAsync.valueOrNull;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PilooScreenHeader(title: 'Mes rappels', bellEnabled: false),
            Expanded(
              child: officine == null
                  ? _buildNoOfficine()
                  : _RappelsList(officine: officine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOfficine() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Sélectionne une officine',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: PilooColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste principale
// ---------------------------------------------------------------------------

class _RappelsList extends ConsumerWidget {
  const _RappelsList({required this.officine});

  final Officine officine;

  bool get _canMutate =>
      officine.role == OfficineRoleEnum.owner ||
      officine.role == OfficineRoleEnum.editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rappelsAsync = ref.watch(rappelsProvider(officine.id));

    return rappelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Impossible de charger les rappels.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: PilooColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(rappelsProvider(officine.id)),
                child: Text(
                  'Réessayer',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (rappels) {
        if (rappels.isEmpty) {
          return _buildEmpty();
        }
        // Actifs d'abord, puis par nomTexte
        final sorted = [...rappels]
          ..sort((a, b) {
            if (a.actif && !b.actif) return -1;
            if (!a.actif && b.actif) return 1;
            return a.nomTexte.compareTo(b.nomTexte);
          });
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _RappelCard(
            rappel: sorted[i],
            officine: officine,
            canMutate: _canMutate,
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: PilooColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsRegular.bellSimple,
                size: 26,
                color: PilooColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun rappel',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Crée un rappel depuis une boîte de ton inventaire.",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte rappel
// ---------------------------------------------------------------------------

class _RappelCard extends ConsumerWidget {
  const _RappelCard({
    required this.rappel,
    required this.officine,
    required this.canMutate,
  });

  final Rappel rappel;
  final Officine officine;
  final bool canMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horaires = _horairesSummary(rappel);
    final schedule = horaires.isNotEmpty
        ? '$horaires · ${rappel.unite}'
        : rappel.unite;
    final periode = _formatPeriode(rappel.dateDebut, rappel.dateFin);

    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône médicament
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rappel.actif
                    ? PilooColors.primarySoft
                    : PilooColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsRegular.pill,
                size: 18,
                color: rappel.actif
                    ? PilooColors.primary
                    : PilooColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            // Contenu textuel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rappel.nomTexte,
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    schedule,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    periode,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusPill(actif: rappel.actif),
                ],
              ),
            ),
            // Actions (owner / editor seulement)
            if (canMutate)
              Column(
                children: [
                  Switch(
                    value: rappel.actif,
                    activeThumbColor: PilooColors.primary,
                    activeTrackColor: PilooColors.primarySoft,
                    onChanged: (newValue) async {
                      try {
                        await toggleRappelActif(
                          ref,
                          id: rappel.id,
                          officineId: officine.id,
                          actif: newValue,
                        );
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newValue
                                    ? 'Impossible d\'activer le rappel.'
                                    : 'Impossible de mettre en pause.',
                                style: GoogleFonts.manrope(fontSize: 13),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(
                      PhosphorIconsRegular.trash,
                      size: 18,
                      color: PilooColors.errorOn,
                    ),
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Supprimer ce rappel ?',
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        content: Text(
          'Les prises à venir seront retirées.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: PilooColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PilooColors.errorOn,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await deleteRappel(ref, id: rappel.id, officineId: officine.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de supprimer le rappel.',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
          ),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Pill statut
// ---------------------------------------------------------------------------

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.actif});

  final bool actif;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: actif ? PilooColors.primarySoft : PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.full),
      ),
      child: Text(
        actif ? 'Actif' : 'En pause',
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: actif ? PilooColors.primary : PilooColors.textTertiary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _horairesSummary(Rappel r) {
  final parts = <String>[];
  if (r.quantiteMatin != null) parts.add('Matin ${r.quantiteMatin}');
  if (r.quantiteMidi != null) parts.add('Midi ${r.quantiteMidi}');
  if (r.quantiteSoir != null) parts.add('Soir ${r.quantiteSoir}');
  if (r.quantiteCoucher != null) parts.add('Coucher ${r.quantiteCoucher}');
  return parts.join(' · ');
}

String _formatPeriode(Date debut, Date? fin) {
  final debutStr = _formatDate(debut);
  if (fin == null) return 'Depuis le $debutStr';
  return '$debutStr → ${_formatDate(fin)}';
}

String _formatDate(Date d) {
  const months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];
  final month = months[d.month - 1];
  return '${d.day} $month';
}
