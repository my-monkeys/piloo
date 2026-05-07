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
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
  _Prescription({
    this.medName = 'Ramipril 5 mg',
    this.medForm = 'Comprimé',
    this.unitsPerTake = 1,
    this.takesPerDay = 2,
    this.moments = const {_Moment.matin},
    this.withMeal = true,
    this.duration = 'À vie',
  });

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
      Navigator.of(context).maybePop();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.of(context).maybePop();
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
            _Header(onClose: () => Navigator.of(context).maybePop()),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < prescriptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _PrescriptionEditor(
            prescription: prescriptions[i],
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
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
        _SectionLabel('MOMENTS DE PRISE'),
        const SizedBox(height: 8),
        _MomentsRow(
          selected: prescription.moments,
          onToggle: (m) {
            if (prescription.moments.contains(m)) {
              prescription.moments = {...prescription.moments}..remove(m);
            } else {
              prescription.moments = {...prescription.moments, m};
            }
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
              child: _DurationRow(value: prescription.duration),
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
  const _MomentsRow({required this.selected, required this.onToggle});

  final Set<_Moment> selected;
  final ValueChanged<_Moment> onToggle;

  static const _items = [
    (m: _Moment.matin, label: 'Matin'),
    (m: _Moment.midi, label: 'Midi'),
    (m: _Moment.soir, label: 'Soir'),
    (m: _Moment.coucher, label: 'Coucher'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MomentChip(
              label: _items[i].label,
              selected: selected.contains(_items[i].m),
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
        height: 44,
        decoration: BoxDecoration(
          color: selected ? PilooColors.primary : PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: selected ? null : Border.all(color: PilooColors.border),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(PhosphorIconsBold.check, size: 12, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: label.length > 5 ? 11 : 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? PilooColors.textOnPrimary
                      : PilooColors.textPrimary,
                ),
              ),
            ),
          ],
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
  const _DurationRow({required this.value});

  final String value;

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
        ],
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
