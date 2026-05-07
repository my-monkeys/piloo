// Sous-écran Profil édition (#153).
//
// Pas de maquette dédiée — design inféré pour matcher le reste de
// l'app : header back centré, avatar large avec initiales (fallback
// quand pas de photo), bouton "Changer la photo", form prénom / nom
// / email, bouton "Enregistrer" en bas.
//
// Validation email locale ; PUT /me serveur à câbler avec OpenAPI.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _Sex { femme, homme, autre }

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController(text: 'Maxime');
  final _lastNameCtrl = TextEditingController(text: 'Durand');
  final _emailCtrl = TextEditingController(text: 'maxime@exemple.fr');
  // Champs santé. Optionnels — l'utilisateur n'est pas obligé de les
  // remplir.
  // IMPORTANT : ces données sont stockées en local + sync, mais
  // l'app NE FAIT AUCUNE recommandation clinique automatique
  // (règlement MDR : si on alertait sur des contre-indications, on
  // deviendrait dispositif médical). C'est de l'info à montrer au
  // pharmacien / médecin, pas un système expert.
  DateTime? _birthDate;
  _Sex? _sex;
  bool _pregnant = false;
  bool _smoker = false;
  final _allergiesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime d) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Calcule l'âge en années pleines à partir de la date de naissance.
  /// Soustrait 1 si l'anniversaire de cette année n'est pas encore
  /// passé.
  static int _ageFrom(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    final hasHadBirthdayThisYear = now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  static String _formatBirthDateWithAge(DateTime d) {
    final age = _ageFrom(d);
    return '${_formatDate(d)} ($age ans)';
  }

  String get _initials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    final fi = f.isEmpty ? '' : f[0].toUpperCase();
    final li = l.isEmpty ? '' : l[0].toUpperCase();
    return (fi + li).isEmpty ? '?' : (fi + li);
  }

  static const _emailRegex =
      r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$";

  void _save() {
    final email = _emailCtrl.text.trim();
    if (_firstNameCtrl.text.trim().isEmpty ||
        _lastNameCtrl.text.trim().isEmpty) {
      PilooToast.error(context, 'Prénom et nom sont obligatoires.');
      return;
    }
    if (!RegExp(_emailRegex).hasMatch(email)) {
      PilooToast.error(context, 'Email invalide.');
      return;
    }
    PilooToast.success(context, 'Profil mis à jour.');
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AvatarSection(
                      initials: _initials,
                      onChangePhoto: () {/* TODO image_picker */},
                    ),
                    const SizedBox(height: 24),
                    _LabeledField(
                      label: 'PRÉNOM',
                      controller: _firstNameCtrl,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'NOM',
                      controller: _lastNameCtrl,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'EMAIL',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'INFORMATIONS DE SANTÉ',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: PilooColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Optionnel · à montrer à ton médecin ou '
                      'pharmacien. Piloo ne fait aucune recommandation '
                      'clinique automatique.',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: PilooColors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'DATE DE NAISSANCE',
                      value: _birthDate,
                      formatter: _formatBirthDateWithAge,
                      onChanged: (d) => setState(() => _birthDate = d),
                    ),
                    const SizedBox(height: 14),
                    _SexField(
                      value: _sex,
                      onChanged: (s) => setState(() => _sex = s),
                    ),
                    // Toggle Enceinte affiché en permanence (et pas
                    // seulement si sexe=Femme) pour des raisons
                    // d'inclusion : trans, non-binaires, etc. peuvent
                    // être concernés. C'est à l'utilisateur de
                    // décider si la donnée s'applique.
                    const SizedBox(height: 14),
                    _ToggleRow(
                      label: 'Enceinte',
                      sub: 'Active pendant la durée de la grossesse',
                      value: _pregnant,
                      onChanged: (v) => setState(() => _pregnant = v),
                    ),
                    const SizedBox(height: 14),
                    _ToggleRow(
                      label: 'Fumeur·euse',
                      value: _smoker,
                      onChanged: (v) => setState(() => _smoker = v),
                    ),
                    const SizedBox(height: 14),
                    _MultilineField(
                      label: 'ALLERGIES CONNUES',
                      hint: 'Pénicilline, arachides, latex…',
                      controller: _allergiesCtrl,
                    ),
                    const SizedBox(height: 14),
                    _MultilineField(
                      label: 'CONDITIONS MÉDICALES',
                      hint: 'Insuffisance rénale, diabète type 2, '
                          'hypertension…',
                      controller: _conditionsCtrl,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PilooButton(
                label: 'Enregistrer',
                variant: PilooButtonVariant.primary,
                onPressed: _save,
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
              'Profil',
              textAlign: TextAlign.center,
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

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.initials,
    required this.onChangePhoto,
  });

  final String initials;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: PilooColors.primary.withValues(alpha: 0.18),
                    offset: const Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            // Petit badge caméra en overlay bottom-right pour
            // signifier "tap pour changer la photo".
            Positioned(
              right: -4,
              bottom: -4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChangePhoto,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PilooColors.surface,
                    border: Border.all(
                      color: PilooColors.background,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    PhosphorIconsFill.camera,
                    size: 16,
                    color: PilooColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChangePhoto,
          child: Text(
            'Changer la photo',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PilooColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final String Function(DateTime) formatter;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return Column(
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
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pick(context),
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
                    filled ? formatter(value!) : 'Choisir une date',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight:
                          filled ? FontWeight.w500 : FontWeight.normal,
                      color: filled
                          ? PilooColors.textPrimary
                          : PilooColors.textTertiary,
                    ),
                  ),
                ),
                const Icon(
                  PhosphorIconsRegular.caretDown,
                  size: 12,
                  color: PilooColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SexField extends StatelessWidget {
  const _SexField({required this.value, required this.onChanged});

  final _Sex? value;
  final ValueChanged<_Sex> onChanged;

  static const _options = [
    (sex: _Sex.femme, label: 'Femme'),
    (sex: _Sex.homme, label: 'Homme'),
    (sex: _Sex.autre, label: 'Autre'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEXE',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SexChip(
                  label: _options[i].label,
                  selected: value == _options[i].sex,
                  onTap: () => onChanged(_options[i].sex),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SexChip extends StatelessWidget {
  const _SexChip({
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
        // Padding compensé pour conserver la largeur intérieure quand
        // le bord passe de 1 à 2px à la sélection.
        padding: EdgeInsets.symmetric(vertical: selected ? 13 : 14),
        decoration: BoxDecoration(
          color: selected ? PilooColors.primary : PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: selected
              ? null
              : Border.all(color: PilooColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? PilooColors.textOnPrimary
                : PilooColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: PilooColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 22,
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
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border: Border.all(color: PilooColors.border),
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            minLines: 2,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                color: PilooColors.textTertiary,
              ),
            ),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            controller: controller,
            keyboardType: keyboardType,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
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
}
