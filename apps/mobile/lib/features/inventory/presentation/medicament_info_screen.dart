// Écran Fiche médicament — refondu (#99 + remontée user).
//
// Layout :
//   1. Hero : nom + forme + dosage
//   2. Résumé IA (carte accent)
//   3. Sections de la NOTICE OFFICIELLE ANSM (indications, posologie,
//      contre-indications, effets indésirables, etc.) — scrapées par
//      le backend (/v1/bdpm/{cis}/notice). Affichées en cards repliables.
//   4. Bouton "Voir la notice complète sur ANSM" (lien externe)
//   5. Section repliée par défaut "Infos techniques" : CIS/CIP/lot/
//      laboratoire/voie/statut AMM/remboursement
//
// Important non-MDR :
//   - Le texte ANSM est affiché TEL QUEL, sans résumé ni reformulation.
//   - Attribution explicite "Source : notice officielle ANSM, scrapée le X"
//   - Pas de personnalisation (pas de croisement avec les ordonnances
//     de l'user).
// → On reste un relais d'information publique, pas un dispositif médical.
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
import 'package:piloo/shared/bdpm/bdpm_notice_provider.dart';
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

class _LoadedView extends ConsumerWidget {
  const _LoadedView({required this.med});

  final BdpmMedicament med;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeAsync = ref.watch(bdpmNoticeProvider(med.cis));
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
          const SizedBox(height: 20),
          _NoticeSections(asyncNotice: noticeAsync),
          const SizedBox(height: 16),
          _NoticeFullLink(cis: med.cis),
          const SizedBox(height: 16),
          _Disclaimer(),
          const SizedBox(height: 20),
          _TechInfosCollapsible(med: med),
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
    final subtitle = [med.dosage, med.forme]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
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
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.text});

  final String text;

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
              const Icon(PhosphorIconsFill.sparkle, size: 16, color: PilooColors.accent),
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
            "Résumé généré automatiquement — à vérifier auprès d'un professionnel.",
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

/// Affiche les sections RCP scrapées depuis l'ANSM (indications,
/// posologie, etc.) — chacune dans une card repliable.
class _NoticeSections extends StatelessWidget {
  const _NoticeSections({required this.asyncNotice});

  final AsyncValue<BdpmNotice> asyncNotice;

  /// Mapping numéro section → label court + icône pour le header.
  /// Final plutôt que const : les icônes Phosphor ne sont pas const-able
  /// car résolues dynamiquement par la lib.
  static final _meta = <String, ({String label, IconData icon})>{
    '4.1': (label: 'Indications', icon: PhosphorIconsFill.target),
    '4.2': (label: 'Posologie', icon: PhosphorIconsFill.clock),
    '4.3': (label: 'Contre-indications', icon: PhosphorIconsFill.prohibitInset),
    '4.4': (label: 'Mises en garde', icon: PhosphorIconsFill.warning),
    '4.5': (label: 'Interactions', icon: PhosphorIconsFill.linkBreak),
    '4.6': (label: 'Grossesse & allaitement', icon: PhosphorIconsFill.baby),
    '4.7': (label: 'Conduite & machines', icon: PhosphorIconsFill.car),
    '4.8': (label: 'Effets indésirables', icon: PhosphorIconsFill.bandaids),
    '4.9': (label: 'Surdosage', icon: PhosphorIconsFill.pill),
  };

  @override
  Widget build(BuildContext context) {
    return asyncNotice.when(
      loading: () => _SectionPlaceholder(text: 'Chargement de la notice ANSM…'),
      error: (_, _) =>
          _SectionPlaceholder(text: "Notice ANSM indisponible pour l'instant. Réessayez plus tard."),
      data: (notice) {
        if (notice.isEmpty) {
          return _SectionPlaceholder(
            text: 'Aucune section de notice trouvée sur la base ANSM pour ce médicament.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in notice.sections) ...[
              _NoticeSectionCard(
                section: s,
                meta: _meta[s.number],
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          color: PilooColors.textSecondary,
        ),
      ),
    );
  }
}

class _NoticeSectionCard extends StatefulWidget {
  const _NoticeSectionCard({required this.section, this.meta});

  final NoticeSection section;
  final ({String label, IconData icon})? meta;

  @override
  State<_NoticeSectionCard> createState() => _NoticeSectionCardState();
}

class _NoticeSectionCardState extends State<_NoticeSectionCard> {
  // Sections les plus utiles dépliées par défaut : indications + posologie.
  // Le reste replié pour ne pas overwhelm la fiche.
  late bool _expanded = const {'4.1', '4.2'}.contains(widget.section.number);

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final label = meta?.label ?? widget.section.title;
    final icon = meta?.icon ?? PhosphorIconsRegular.fileText;
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: PilooColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? PhosphorIconsRegular.caretUp
                        : PhosphorIconsRegular.caretDown,
                    size: 16,
                    color: PilooColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: PilooColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                widget.section.text,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: PilooColors.textPrimary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeFullLink extends StatelessWidget {
  const _NoticeFullLink({required this.cis});
  final String cis;

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsRegular.arrowSquareOut, size: 16, color: PilooColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Voir la notice complète sur ansm.sante.fr',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsRegular.info, size: 14, color: PilooColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Source : notice officielle ANSM, relayée sans modification. "
              "Piloo est un carnet de suivi personnel, pas un substitut au médecin.",
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: PilooColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section "Infos techniques" repliée par défaut — CIS/CIP/laboratoire/
/// voie/statut AMM/remboursement. Utile pour les pros ou les curieux,
/// mais pas l'info prioritaire d'un usage perso.
class _TechInfosCollapsible extends StatefulWidget {
  const _TechInfosCollapsible({required this.med});
  final BdpmMedicament med;

  @override
  State<_TechInfosCollapsible> createState() => _TechInfosCollapsibleState();
}

class _TechInfosCollapsibleState extends State<_TechInfosCollapsible> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    final rows = <({String label, String value})>[
      if (med.titulaire != null) (label: 'Laboratoire', value: med.titulaire!),
      if (med.voieAdministration != null) (label: 'Voie', value: med.voieAdministration!),
      if (med.tauxRemboursement != null)
        (label: 'Remboursement', value: '${med.tauxRemboursement}%'),
      if (med.statutAmm != null) (label: 'Statut AMM', value: med.statutAmm!),
      (label: 'CIP13', value: med.cip13 ?? '—'),
      (label: 'CIS', value: med.cis),
    ];
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.gear,
                    size: 16,
                    color: PilooColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Infos techniques',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? PhosphorIconsRegular.caretUp
                        : PhosphorIconsRegular.caretDown,
                    size: 14,
                    color: PilooColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: PilooColors.border),
            ...List.generate(rows.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Container(height: 1, color: PilooColors.border);
              }
              final r = rows[i ~/ 2];
              return _InfoRow(label: r.label, value: r.value);
            }),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: PilooColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(
                fontSize: 12,
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

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        children: [
          PilooCircleBackButton(),
          const SizedBox(width: 8),
          Text(
            'Fiche médicament',
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: PilooColors.textPrimary,
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
            Text(
              'Médicament inconnu',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 18,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aucune correspondance BDPM pour le CIP13 $cip13. '
              'Le médicament est peut-être trop récent ou retiré du marché.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
                height: 1.5,
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
          'Impossible de charger les informations pour $cip13.\n$error',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: PilooColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
