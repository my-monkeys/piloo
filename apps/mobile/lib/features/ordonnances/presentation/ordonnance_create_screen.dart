// Écran 10 Création ordonnance, 3 étapes (#110, #111, #112).
// Maquette : `PdrZU` du fichier docs/design/piloo-mobile.pen (l'image
// montre l'étape 2 ; les étapes 1 et 3 sont inférées de la spec).
//
// Flow :
//  - Étape 1 (Infos) : date + prescripteur (champ libre + autocomplete
//    sur historique perso, simulé en local pour l'instant)
//  - Étape 2 (Prescriptions) : pour chaque ligne, médicament + posologie
//    inline ("Je prends N comprimé M fois par jour") + moments de
//    prise + avec repas + durée. Bouton "Ajouter une autre
//    prescription" pour empiler.
//  - Étape 3 (Récap) : résumé en lecture seule + bouton Terminer.
//
// Pour le POC, données saisies maintenues en state local. La création
// serveur (transaction unique) sera câblée avec le client OpenAPI
// quand il sera généré.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';

class OrdonnanceCreateScreen extends StatefulWidget {
  const OrdonnanceCreateScreen({super.key});

  @override
  State<OrdonnanceCreateScreen> createState() =>
      _OrdonnanceCreateScreenState();
}

enum _Moment { matin, midi, soir, coucher }

class _Prescription {
  // Constructeur par défaut : pré-rempli pour la review (Ramipril
  // = exemple de la maquette). En vrai, on partira d'un médoc choisi
  // via scan ou recherche BDPM avant d'arriver sur la sheet.
  _Prescription()
      : medName = 'Ramipril 5 mg',
        medForm = 'Comprimé',
        unitsPerTake = 1,
        takesPerDay = 2,
        moments = {_Moment.matin},
        withMeal = true,
        duration = 'À vie';

  String medName;
  String medForm;
  int unitsPerTake;
  int takesPerDay;
  Set<_Moment> moments;
  bool withMeal;
  String duration;
}

class _OrdonnanceCreateScreenState extends State<OrdonnanceCreateScreen> {
  int _step = 1; // 1, 2, 3
  // Étape 1
  DateTime _date = DateTime(2026, 4, 23);
  final _prescripteurCtrl = TextEditingController();
  // Étape 2
  final List<_Prescription> _prescriptions = [_Prescription()];

  @override
  void dispose() {
    _prescripteurCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      // Terminer : POST /ordonnances + ses prescriptions en 1 tx.
      context.canPop() ? context.pop() : context.go(RoutePath.ordonnances);
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      context.canPop() ? context.pop() : context.go(RoutePath.ordonnances);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClose: () => context.canPop() ? context.pop() : context.go(RoutePath.ordonnances)),
            _Stepper(currentStep: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: switch (_step) {
                  1 => _StepInfos(
                      date: _date,
                      onPickDate: (d) => setState(() => _date = d),
                      prescripteurCtrl: _prescripteurCtrl,
                    ),
                  2 => _StepPrescriptions(
                      prescriptions: _prescriptions,
                      onChanged: () => setState(() {}),
                      onAdd: () => setState(
                        () => _prescriptions.add(_Prescription()),
                      ),
                    ),
                  _ => _StepRecap(
                      date: _date,
                      prescripteur: _prescripteurCtrl.text.isEmpty
                          ? 'Dr Sophie Laurent'
                          : _prescripteurCtrl.text,
                      prescriptions: _prescriptions,
                    ),
                },
              ),
            ),
            _Bottom(
              currentStep: _step,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Header + Stepper + Bottom
// ============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // back ghost (le back est géré par le bouton Précédent du
          // bottom — on garde un cercle X à droite pour close).
          Container(width: 40),
          Flexible(
            child: Text(
              'Nouvelle ordonnance',
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
            onTap: onClose,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.surfaceSubtle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsRegular.x,
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

class _Stepper extends StatelessWidget {
  const _Stepper({required this.currentStep});

  final int currentStep;

  static const _labels = ['Infos', 'Prescriptions', 'Récap'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            _StepDot(index: i + 1, label: _labels[i], current: currentStep),
            if (i < _labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: currentStep > i + 1
                        ? PilooColors.primarySoft
                        : PilooColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.current,
  });

  final int index;
  final String label;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDone = current > index;
    final isActive = current == index;

    final ({Color bg, Color fg, Widget child}) dot;
    if (isDone) {
      dot = (
        bg: PilooColors.primarySoft,
        fg: PilooColors.primary,
        child: const Icon(
          PhosphorIconsBold.check,
          size: 12,
          color: PilooColors.primary,
        ),
      );
    } else if (isActive) {
      dot = (
        bg: PilooColors.primary,
        fg: Colors.white,
        child: Text(
          '$index',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    } else {
      dot = (
        bg: PilooColors.surface,
        fg: PilooColors.textTertiary,
        child: Text(
          '$index',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PilooColors.textTertiary,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot.bg,
            border: !isActive && !isDone
                ? Border.all(color: PilooColors.border)
                : null,
          ),
          alignment: Alignment.center,
          child: dot.child,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive || isDone
                ? PilooColors.textPrimary
                : PilooColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.currentStep,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: PilooColors.background,
        border: Border(top: BorderSide(color: PilooColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PilooButton(
              label: currentStep == 1 ? 'Annuler' : 'Précédent',
              variant: PilooButtonVariant.outline,
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PilooButton(
              label: currentStep == 3 ? 'Terminer' : 'Suivant',
              variant: PilooButtonVariant.primary,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Étape 1 : Infos
// ============================================================================

class _StepInfos extends StatelessWidget {
  const _StepInfos({
    required this.date,
    required this.onPickDate,
    required this.prescripteurCtrl,
  });

  final DateTime date;
  final ValueChanged<DateTime> onPickDate;
  final TextEditingController prescripteurCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('DATE DE L\'ORDONNANCE'),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onPickDate(picked);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(PilooRadius.md),
              border: Border.all(color: PilooColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.calendar,
                  size: 16,
                  color: PilooColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _format(date),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  PhosphorIconsRegular.caretDown,
                  size: 14,
                  color: PilooColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('PRESCRIPTEUR'),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border: Border.all(color: PilooColors.border),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: prescripteurCtrl,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: 'Dr Sophie Laurent',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                color: PilooColors.textTertiary,
              ),
            ),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  static String _format(DateTime d) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: PilooColors.textTertiary,
        ),
      );
}

// ============================================================================
// Étape 2 : Prescriptions
// ============================================================================

class _StepPrescriptions extends StatelessWidget {
  const _StepPrescriptions({
    required this.prescriptions,
    required this.onChanged,
    required this.onAdd,
  });

  final List<_Prescription> prescriptions;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  Future<void> _edit(BuildContext context, _Prescription p) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PilooColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _PrescriptionEditorSheet(
        prescription: p,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('PRESCRIPTIONS · ${prescriptions.length}'),
        const SizedBox(height: 8),
        // Liste compacte : 1 row par prescription, tap → bottom sheet
        // d'édition. Garde la liste visible et lisible quand il y a
        // 5+ médocs.
        for (var i = 0; i < prescriptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PrescriptionRow(
            prescription: prescriptions[i],
            onTap: () => _edit(context, prescriptions[i]),
            onRemove: prescriptions.length > 1
                ? () {
                    prescriptions.removeAt(i);
                    onChanged();
                  }
                : null,
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Ajoute + ouvre directement la sheet d'édition pour
          // configurer la nouvelle prescription dans la foulée.
          onTap: () {
            onAdd();
            // Le widget rebuild après onAdd ; on attend un frame
            // pour avoir la nouvelle prescription dans la liste.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                _edit(context, prescriptions.last);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: PilooColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIconsRegular.plusCircle,
                  size: 18,
                  color: PilooColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ajouter une autre prescription',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne compacte affichée dans la liste de l'étape 2 : nom du
/// médicament + posologie en phrase naturelle (avec nombres en primary
/// gras pour mimer les pills de l'éditeur). Tap = ouvre la sheet
/// d'édition. Bouton trash si > 1 prescription.
class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({
    required this.prescription,
    required this.onTap,
    required this.onRemove,
  });

  final _Prescription prescription;
  final VoidCallback onTap;
  // null quand c'est la dernière prescription (au moins 1 obligatoire).
  final VoidCallback? onRemove;

  /// Ligne 1 : "1 comprimé pris 2 fois par jour" (avec nombres
  /// primary gras).
  List<TextSpan> _buildPosologieSpans(TextStyle base, TextStyle accent) {
    final unit = prescription.medForm.toLowerCase();
    final unitPlural =
        prescription.unitsPerTake > 1 ? '${unit}s' : unit;
    final spans = <TextSpan>[
      TextSpan(text: '${prescription.unitsPerTake} ', style: accent),
      TextSpan(text: unitPlural, style: base),
    ];

    if (prescription.takesPerDay > 1) {
      spans.addAll([
        TextSpan(text: ' pris ', style: base),
        TextSpan(text: '${prescription.takesPerDay} ', style: accent),
        TextSpan(text: 'fois par jour', style: base),
      ]);
    } else {
      spans.add(TextSpan(text: ' une fois par jour', style: base));
    }
    return spans;
  }

  /// Ligne 2 : "matin et midi · à vie", ou juste la durée si aucun
  /// moment sélectionné.
  String _buildMomentsLine() {
    final parts = <String>[];

    if (prescription.moments.isNotEmpty) {
      final order = [
        _Moment.matin,
        _Moment.midi,
        _Moment.soir,
        _Moment.coucher,
      ];
      final selected = order.where(prescription.moments.contains).toList();
      final names = selected
          .map((m) => switch (m) {
                _Moment.matin => 'matin',
                _Moment.midi => 'midi',
                _Moment.soir => 'soir',
                _Moment.coucher => 'au coucher',
              })
          .toList();
      final String joined;
      if (names.length == 1) {
        joined = names.first;
      } else {
        joined = '${names.sublist(0, names.length - 1).join(', ')} '
            'et ${names.last}';
      }
      parts.add(joined);
    }

    parts.add(prescription.duration);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.manrope(
      fontSize: 12,
      color: PilooColors.textSecondary,
      height: 1.45,
    );
    final accent = GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: PilooColors.primary,
      height: 1.45,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: PilooColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsFill.pill,
                size: 18,
                color: PilooColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prescription.medName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: _buildPosologieSpans(base, accent),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _buildMomentsLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: PilooColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onRemove != null) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    PhosphorIconsRegular.trash,
                    size: 16,
                    color: PilooColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(
              PhosphorIconsRegular.pencilSimple,
              size: 16,
              color: PilooColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet d'édition d'une prescription. Reprend tous les
/// contrôles précédemment inline (médicament + posologie + moments
/// + repas + durée), affichés un à la fois.
class _PrescriptionEditorSheet extends StatefulWidget {
  const _PrescriptionEditorSheet({
    required this.prescription,
    required this.onChanged,
  });

  final _Prescription prescription;
  final VoidCallback onChanged;

  @override
  State<_PrescriptionEditorSheet> createState() =>
      _PrescriptionEditorSheetState();
}

class _PrescriptionEditorSheetState extends State<_PrescriptionEditorSheet> {
  void _bumpParent() {
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: PilooColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Text(
                  widget.prescription.medName,
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: _PrescriptionEditor(
                    prescription: widget.prescription,
                    onChanged: _bumpParent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PilooButton(
                label: 'Terminé',
                variant: PilooButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionEditor extends StatelessWidget {
  const _PrescriptionEditor({
    required this.prescription,
    required this.onChanged,
  });

  final _Prescription prescription;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('MÉDICAMENT'),
        const SizedBox(height: 8),
        _MedSelected(prescription: prescription),
        const SizedBox(height: 18),
        _SectionLabel('POSOLOGIE'),
        const SizedBox(height: 8),
        _PosologieCard(
          prescription: prescription,
          onChanged: onChanged,
        ),
        const SizedBox(height: 18),
        // Compteur (N/M) pour signaler à l'utilisateur qu'il doit
        // sélectionner autant de moments que de prises par jour.
        // Couleur primary quand complet, accent (rouge) quand
        // incomplet pour attirer l'œil.
        Builder(builder: (_) {
          final total = prescription.takesPerDay;
          final filled = prescription.moments.length;
          final isComplete = filled == total;
          return Row(
            children: [
              _SectionLabel('MOMENTS DE PRISE'),
              const SizedBox(width: 6),
              Text(
                '($filled/$total)',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isComplete
                      ? PilooColors.successOn
                      : PilooColors.accent,
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        _MomentsRow(
          selected: prescription.moments,
          // Plafond = takesPerDay : on bloque la sélection au-delà
          // pour rester cohérent ("2 fois par jour" ne peut pas avoir
          // 3 moments).
          maxSelected: prescription.takesPerDay,
          onToggle: (m) {
            if (prescription.moments.contains(m)) {
              prescription.moments = {...prescription.moments}..remove(m);
            } else if (prescription.moments.length <
                prescription.takesPerDay) {
              prescription.moments = {...prescription.moments, m};
            }
            // Au-delà : no-op, le chip est rendu disabled visuellement.
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SwitchRow(
                label: 'Avec repas',
                value: prescription.withMeal,
                onChanged: (v) {
                  prescription.withMeal = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DurationRow(
                value: prescription.duration,
                onChanged: (v) {
                  prescription.duration = v;
                  onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MedSelected extends StatelessWidget {
  const _MedSelected({required this.prescription});

  final _Prescription prescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PilooColors.primarySoft,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.pill,
              size: 18,
              color: PilooColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prescription.medName,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  prescription.medForm,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {/* TODO sheet recherche médoc / scan */},
            child: Text(
              'Changer',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PilooColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosologieCard extends StatelessWidget {
  const _PosologieCard({
    required this.prescription,
    required this.onChanged,
  });

  final _Prescription prescription;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Je prends',
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  color: PilooColors.textPrimary,
                ),
              ),
              _NumberPill(
                value: prescription.unitsPerTake,
                onChanged: (v) {
                  prescription.unitsPerTake = v;
                  onChanged();
                },
              ),
              Text(
                'comprimé',
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  color: PilooColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _NumberPill(
                value: prescription.takesPerDay,
                onChanged: (v) {
                  prescription.takesPerDay = v;
                  // Si on réduit takesPerDay sous le nombre de
                  // moments sélectionnés, on coupe les surplus
                  // pour rester cohérent (matin/midi/soir/coucher
                  // dans cet ordre, on garde les premiers).
                  if (prescription.moments.length > v) {
                    const order = [
                      _Moment.matin,
                      _Moment.midi,
                      _Moment.soir,
                      _Moment.coucher,
                    ];
                    final keep = order
                        .where(prescription.moments.contains)
                        .take(v)
                        .toSet();
                    prescription.moments = keep;
                  }
                  onChanged();
                },
              ),
              Text(
                'fois par jour',
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  color: PilooColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberPill extends StatelessWidget {
  const _NumberPill({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showModalBottomSheet<int>(
          context: context,
          backgroundColor: PilooColors.background,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: PilooColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  for (var i = 1; i <= 6; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(i),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PilooColors.surface,
                            borderRadius:
                                BorderRadius.circular(PilooRadius.md),
                            border: Border.all(
                              color: i == value
                                  ? PilooColors.primary
                                  : PilooColors.border,
                              width: i == value ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            '$i',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: PilooColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: PilooColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PilooColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PilooColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              PhosphorIconsRegular.caretDown,
              size: 10,
              color: PilooColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentsRow extends StatelessWidget {
  const _MomentsRow({
    required this.selected,
    required this.maxSelected,
    required this.onToggle,
  });

  final Set<_Moment> selected;
  final int maxSelected;
  final ValueChanged<_Moment> onToggle;

  static const _items = [
    (m: _Moment.matin, label: 'Matin'),
    (m: _Moment.midi, label: 'Midi'),
    (m: _Moment.soir, label: 'Soir'),
    (m: _Moment.coucher, label: 'Coucher'),
  ];

  @override
  Widget build(BuildContext context) {
    final atCapacity = selected.length >= maxSelected;
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MomentChip(
              label: _items[i].label,
              selected: selected.contains(_items[i].m),
              // Disabled si on est au plafond ET que ce chip n'est
              // pas déjà sélectionné (sinon on pourrait pas
              // décocher les sélectionnés).
              disabled:
                  atCapacity && !selected.contains(_items[i].m),
              onTap: () => onToggle(_items[i].m),
            ),
          ),
        ],
      ],
    );
  }
}

class _MomentChip extends StatelessWidget {
  const _MomentChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: selected ? PilooColors.primary : PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border:
                selected ? null : Border.all(color: PilooColors.border),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  PhosphorIconsBold.check,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: label.length > 5 ? 11 : 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? PilooColors.textOnPrimary
                        : PilooColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 32,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? PilooColors.primary : PilooColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _presets = [
    'À vie',
    '7 jours',
    '14 jours',
    '1 mois',
    '3 mois',
    '6 mois',
  ];

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PilooColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // Si la valeur courante est custom (pas dans les presets),
        // pré-remplir le champ texte avec elle pour que l'user voie
        // sa saisie précédente.
        final isCustom = !_presets.contains(value);
        final customCtrl = TextEditingController(
          text: isCustom ? value : '',
        );

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: PilooColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Durée du traitement',
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final p in _presets) ...[
                  _PresetTile(
                    label: p,
                    selected: value == p,
                    onTap: () => Navigator.of(context).pop(p),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Text(
                  'PERSONNALISÉE',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: PilooColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: PilooColors.surface,
                    borderRadius: BorderRadius.circular(PilooRadius.md),
                    border: Border.all(
                      color: isCustom
                          ? PilooColors.primary
                          : PilooColors.border,
                      width: isCustom ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: customCtrl,
                    autofocus: false,
                    onSubmitted: (v) {
                      final t = v.trim();
                      if (t.isNotEmpty) Navigator.of(context).pop(t);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: 'ex: 10 jours, jusqu\'au 15 mai…',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 14,
                        color: PilooColors.textTertiary,
                      ),
                    ),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PilooButton(
                  label: 'Confirmer',
                  variant: PilooButtonVariant.primary,
                  onPressed: () {
                    final t = customCtrl.text.trim();
                    Navigator.of(context).pop(t.isEmpty ? value : t);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          children: [
            Text(
              'Durée',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              PhosphorIconsRegular.caretDown,
              size: 12,
              color: PilooColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(selected ? 13 : 14),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(
            color: selected ? PilooColors.primary : PilooColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(
                PhosphorIconsBold.check,
                size: 16,
                color: PilooColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Étape 3 : Récap
// ============================================================================

class _StepRecap extends StatelessWidget {
  const _StepRecap({
    required this.date,
    required this.prescripteur,
    required this.prescriptions,
  });

  final DateTime date;
  final String prescripteur;
  final List<_Prescription> prescriptions;

  static String _format(DateTime d) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('PRESCRIPTEUR'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border: Border.all(color: PilooColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prescripteur,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PilooColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _format(date),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: PilooColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('PRESCRIPTIONS · ${prescriptions.length}'),
        const SizedBox(height: 6),
        for (var i = 0; i < prescriptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _RecapPrescription(prescription: prescriptions[i]),
        ],
      ],
    );
  }
}

class _RecapPrescription extends StatelessWidget {
  const _RecapPrescription({required this.prescription});

  final _Prescription prescription;

  String get _summary {
    final moments = prescription.moments
        .map((m) => switch (m) {
              _Moment.matin => 'matin',
              _Moment.midi => 'midi',
              _Moment.soir => 'soir',
              _Moment.coucher => 'coucher',
            })
        .join(' · ');
    final repas = prescription.withMeal ? 'avec repas' : 'sans repas';
    return '${prescription.unitsPerTake} ${prescription.medForm.toLowerCase()} '
        '${prescription.takesPerDay}×/j · $moments · $repas · '
        '${prescription.duration}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prescription.medName,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PilooColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _summary,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: PilooColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
