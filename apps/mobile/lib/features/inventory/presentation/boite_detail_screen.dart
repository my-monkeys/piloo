// Écran 08 Détail boîte (#98).
// Maquette : `zzAPm` du fichier docs/design/piloo-mobile.pen.
//
// Structure :
//  - Header centré : back + "Détail boîte" Fraunces 20 + dots-three
//  - Hero card $primary-soft : tile blanche 52 + icône pill-fill
//    + nom Fraunces + DCI · forme galénique
//  - Info grid 2×2 : péremption (Fraunces 20) / stock (Fraunces 20) /
//    n° lot (Manrope 14) / ajoutée le (Manrope 14)
//  - Bouton "Voir la fiche médicament" en card $primary-soft (icône
//    info + label primary + chevron) → push fiche médicament (#99)
//  - Section HISTORIQUE : eyebrow + card avec lignes d'actions
//    (icône sliders-horizontal + label + meta horodatage)
//  - Bottom bar : Modifier (outline) + Marquer vide (warning)
//
// Données mockées (Doliprane 1000 mg, lot LOT42AB7, exp 03/2028).
// Le branchement Drift + provider Riverpod arrive avec l'epic
// Inventory (#11) ; ce ticket couvre l'UI seule.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

class BoiteDetailScreen extends StatelessWidget {
  const BoiteDetailScreen({this.boiteId, super.key});

  final String? boiteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(),
                    const SizedBox(height: 12),
                    _InfoGrid(),
                    const SizedBox(height: 12),
                    _MedicamentLink(
                      onTap: () => Navigator.of(context).pushNamed(
                        RoutePath.medicamentInfo('3400930000019'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HistorySection(),
                  ],
                ),
              ),
            ),
            _BottomActions(),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PilooCircleBackButton(),
          Flexible(
            child: Text(
              'Détail boîte',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {/* menu actions secondaires : déplacer, dupliquer, supprimer */},
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.surfaceSubtle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsRegular.dotsThreeVertical,
                size: 20,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PilooColors.primarySoft,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.pill,
              size: 26,
              color: PilooColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doliprane 1000 mg',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paracétamol · comprimé pelliculé',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                label: 'PÉREMPTION',
                value: '03 / 2028',
                large: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoCard(
                label: 'STOCK',
                value: '8 comprimés',
                large: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoCard(label: 'N° DE LOT', value: 'LOT42AB7'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoCard(label: 'AJOUTÉE LE', value: '15 mars'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    this.large = false,
  });

  final String label;
  final String value;
  // Cards principales (péremption + stock) : valeur Fraunces 20 ;
  // cards secondaires (lot + date) : valeur Manrope 14.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: PilooColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: large
                ? GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  )
                : GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MedicamentLink extends StatelessWidget {
  const _MedicamentLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PilooColors.primarySoft,
          borderRadius: BorderRadius.circular(PilooRadius.md),
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.info,
              size: 18,
              color: PilooColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Voir la fiche médicament',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PilooColors.primary,
                ),
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: PilooColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  static const _entries = [
    (
      icon: PhosphorIconsRegular.slidersHorizontal,
      title: 'Stock ajusté — 8 comprimés',
      sub: 'il y a 2 jours · par Maxime',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'HISTORIQUE',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: PilooColors.textTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(color: PilooColors.border),
          ),
          child: Column(
            children: List.generate(_entries.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Container(height: 1, color: PilooColors.border);
              }
              final e = _entries[i ~/ 2];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(e.icon, size: 16, color: PilooColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: PilooColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.sub,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: PilooColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: PilooColors.background,
        border: Border(
          top: BorderSide(color: PilooColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: PilooButton(
                label: 'Modifier',
                variant: PilooButtonVariant.outline,
                onPressed: () {/* TODO réouvrir le form de boîte (#89) */},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Bouton "Marquer vide" en warning (action destructive
              // douce — sortie du stock actif). Ne supprime pas, pose
              // juste vide_at sur la table boites.
              child: _MarkEmptyButton(
                onPressed: () {/* TODO confirmation + soft */},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkEmptyButton extends StatelessWidget {
  const _MarkEmptyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PilooColors.warning,
      borderRadius: BorderRadius.circular(PilooRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              'Marquer vide',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PilooColors.warningOn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
