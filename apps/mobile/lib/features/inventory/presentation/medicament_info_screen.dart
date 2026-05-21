// Écran 06 Fiche info médicament (#99).
//
// Données BDPM résolues via `bdpmLookupProvider` (SQLite local d'abord,
// fallback API si miss). Le résumé IA (#22) n'est pas encore intégré
// — cache l'écran "À QUOI ÇA SERT" pour ne pas afficher de placeholder
// non-data-driven.
//
// Le disclaimer "à titre indicatif" est obligatoire (positionnement
// non-MD du produit) — ne pas l'enlever sans accord.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_medicament.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class MedicamentInfoScreen extends ConsumerWidget {
  const MedicamentInfoScreen({this.cip13, super.key});

  final String? cip13;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(child: _Body(cip13: cip13)),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.cip13});

  final String? cip13;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cip13 == null || cip13!.isEmpty) {
      return _MissingCipState();
    }
    final lookupAsync = ref.watch(bdpmLookupProvider(cip13!));
    return lookupAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(cip13: cip13!, error: e),
      data: (med) {
        if (med == null) return _NotFoundState(cip13: cip13!);
        return _LoadedView(med: med);
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.med});

  final BdpmMedicament med;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(med: med),
          if (med.aiSummary != null && med.aiSummary!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            _AiSummary(text: med.aiSummary!),
          ],
          const SizedBox(height: 16),
          // Notice officielle ANSM — c'est LA source autoritative pour
          // posologie + effets secondaires + interactions. Mise en CTA
          // primary parce que Piloo ne porte délibérément pas ces données
          // (positionnement non-MDR, cf. CLAUDE.md).
          _NoticeButton(cis: med.cis),
          const SizedBox(height: 20),
          _InfosTable(med: med),
          const SizedBox(height: 16),
          _Disclaimer(),
        ],
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.text});

  final String text;

  /// Bord plus marqué que l'accentSoft pur pour distinguer la card —
  /// approche la teinte #d9ad9c en assombrissant accent-soft.
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
            text,
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

class _Hero extends StatelessWidget {
  const _Hero({required this.med});

  final BdpmMedicament med;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PilooColors.primarySoft,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
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
                  med.denomination,
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (med.forme != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    med.forme!,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: PilooColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfosTable extends StatelessWidget {
  const _InfosTable({required this.med});

  final BdpmMedicament med;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      if (med.titulaire != null)
        (label: 'Laboratoire', value: med.titulaire!),
      if (med.dosage != null) (label: 'Dosage', value: med.dosage!),
      if (med.voieAdministration != null)
        (label: 'Voie', value: med.voieAdministration!),
      if (med.tauxRemboursement != null)
        (label: 'Remboursement', value: '${med.tauxRemboursement}%'),
      if (med.statutAmm != null) (label: 'Statut AMM', value: med.statutAmm!),
      (label: 'CIP13', value: med.cip13 ?? '—'),
      (label: 'CIS', value: med.cis),
    ];
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(rows.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(height: 1, color: PilooColors.border);
          }
          final r = rows[i ~/ 2];
          return _InfoRow(label: r.label, value: r.value);
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
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

class _NoticeButton extends StatelessWidget {
  const _NoticeButton({required this.cis});

  final String cis;

  /// URL du RCP officiel ANSM via la base de données publique des
  /// médicaments. Le `specid` est le CIS. C'est la seule source légale
  /// pour la posologie, les effets indésirables et les interactions —
  /// Piloo ne porte pas ces données directement (cf. positionnement
  /// non-dispositif-médical).
  Uri get _noticeUrl =>
      Uri.parse('https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=$cis');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final ok = await launchUrl(_noticeUrl, mode: LaunchMode.externalApplication);
        if (ok || !context.mounted) return;
        await Clipboard.setData(ClipboardData(text: _noticeUrl.toString()));
        if (!context.mounted) return;
        PilooToast.info(context, 'Lien copié — colle-le dans ton navigateur.');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PilooColors.primary,
          borderRadius: BorderRadius.circular(PilooRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsFill.fileText,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir la notice officielle',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'posologie · effets · interactions',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              PhosphorIconsRegular.arrowSquareOut,
              size: 16,
              color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsRegular.info,
            size: 16,
            color: PilooColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Piloo est un carnet de suivi personnel, pas un substitut au médecin. "
              "Pour la posologie, les effets secondaires et les interactions, "
              "consulte la notice officielle ci-dessus ou ton pharmacien.",
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingCipState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Aucun CIP13 fourni.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.cip13});

  final String cip13;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.warningCircle,
              size: 48,
              color: PilooColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Médicament inconnu',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'CIP13 $cip13 absent de la base BDPM. C\'est peut-être un '
              'dispositif médical, un complément alimentaire ou un '
              'produit non listé.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.cip13, required this.error});

  final String cip13;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Erreur lors du chargement de $cip13.\n$error',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textSecondary,
          ),
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
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
