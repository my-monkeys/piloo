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

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController(text: 'Maxime');
  final _lastNameCtrl = TextEditingController(text: 'Durand');
  final _emailCtrl = TextEditingController(text: 'maxime@exemple.fr');

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
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
