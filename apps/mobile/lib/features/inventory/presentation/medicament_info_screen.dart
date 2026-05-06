// Écran 06 Fiche info médicament (#99).
// Maquette : `E5jM1` du fichier docs/design/piloo-mobile.pen.
//
// Données BDPM lues localement (SQLite embarqué — voir
// docs/architecture.md). Le résumé "À QUOI ÇA SERT" est généré côté
// serveur via un appel LLM puis caché en local — ce ticket couvre
// l'UI seule, les valeurs sont mockées.
//
// Le disclaimer "à titre indicatif" est obligatoire (positionnement
// non-MD du produit) — ne pas l'enlever sans accord.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

class MedicamentInfoScreen extends StatelessWidget {
  const MedicamentInfoScreen({this.cip13, super.key});

  final String? cip13;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(),
                    const SizedBox(height: 20),
                    _InfosTable(),
                    const SizedBox(height: 20),
                    _AiSummary(),
                    const SizedBox(height: 20),
                    _NoticeButton(),
                    const SizedBox(height: 20),
                    _Disclaimer(),
                  ],
                ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PilooCircleBackButton(),
          Flexible(
            child: Text(
              'Fiche médicament',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {/* share intent natif */},
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.surfaceSubtle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsRegular.shareNetwork,
                size: 18,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PilooColors.primarySoft,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: PilooColors.surface,
                  borderRadius: BorderRadius.circular(PilooRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  PhosphorIconsFill.pill,
                  size: 28,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comprimé pelliculé',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _Tag(label: 'Non listé', color: PilooColors.textSecondary),
              _Tag(label: 'Remboursé 65%', color: PilooColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _InfosTable extends StatelessWidget {
  static const _rows = [
    (label: 'Principe actif', value: 'Paracétamol', clickable: true),
    (label: 'Laboratoire', value: 'Sanofi', clickable: false),
    (label: 'Forme · dosage', value: 'Comprimé · 1000 mg', clickable: false),
    (label: 'CIP13', value: '3400934857188', clickable: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(_rows.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(height: 1, color: PilooColors.border);
          }
          final r = _rows[i ~/ 2];
          return _InfoRow(
            label: r.label,
            value: r.value,
            clickable: r.clickable,
          );
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.clickable,
  });

  final String label;
  final String value;
  // Principe actif est cliquable : ouvre la liste filtrée des
  // boîtes ayant la même DCI (#?). Pour l'instant no-op.
  final bool clickable;

  @override
  Widget build(BuildContext context) {
    final valueColor = clickable ? PilooColors.primary : PilooColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: clickable ? () {} : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            // Expanded pour laisser la valeur prendre toute la place
            // restante et tronquer proprement si trop long.
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight:
                            clickable ? FontWeight.w600 : FontWeight.w500,
                        color: valueColor,
                      ),
                    ),
                  ),
                  if (clickable) ...[
                    const SizedBox(width: 4),
                    Icon(
                      PhosphorIconsRegular.caretRight,
                      size: 12,
                      color: valueColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  // Bord plus marqué que l'$accent-soft pur pour distinguer la card
  // (la maquette utilise #d9ad9c, qu'on approche avec une teinte
  // assombrie de l'accent-soft).
  static final _border = Color.alphaBlend(
    PilooColors.accent.withValues(alpha: 0.25),
    PilooColors.accentSoft,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PilooColors.accentSoft,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsFill.sparkle,
                size: 16,
                color: PilooColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'À QUOI ÇA SERT',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: PilooColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Le Doliprane est utilisé pour soulager la fièvre et les "
            "douleurs légères à modérées (maux de tête, douleurs "
            "musculaires…). À prendre avec ou sans repas, espacer les "
            "prises d'au moins 4 heures.",
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: PilooColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Résumé généré automatiquement · à vérifier auprès d'un professionnel",
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: PilooColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // No-op : ouvrira l'URL BDPM du PDF notice quand le client OpenAPI
      // sera câblé.
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.arrowSquareOut,
              size: 18,
              color: PilooColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Voir la notice officielle',
                overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Informations à titre indicatif. Pour toute question, consulte '
      'ton médecin ou pharmacien.',
      textAlign: TextAlign.center,
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: PilooColors.textTertiary,
        height: 1.5,
      ),
    );
  }
}
