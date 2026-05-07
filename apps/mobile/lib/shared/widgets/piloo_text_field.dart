// Champ texte type "input avec label" — maquette A4 Inscription
// (formulaire `00Hcu` du fichier docs/design/piloo-mobile.pen).
//
// Pattern :
//   - Label uppercase tracking 0.5 (10px, Manrope 600, $text-tertiary)
//   - Champ 44px hauteur, fond $surface, bord 1 $border, radius $radius-md
//   - Optionnel : icône phosphor à gauche (envelope, lock-simple, …)
//   - Optionnel : icône eye à droite pour les passwords
//   - Optionnel : errorText sous le champ (border errorOn, message rouge)
//   - Bordure primary quand le champ a le focus
//
// Accessibilité : le label est exposé via Semantics(label:) ; les
// erreurs via Semantics(value:) pour que VoiceOver/TalkBack annoncent
// l'état.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

class PilooTextField extends StatefulWidget {
  const PilooTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.leadingIcon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.errorText,
    this.height = 44,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? leadingIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  /// Si non null, le champ passe en état erreur (bordure rouge,
  /// message visible sous le champ, exposé via Semantics).
  final String? errorText;

  // 44 sur A4, 48 sur A3 — la maquette propose 2 hauteurs selon la
  // densité du formulaire.
  final double height;

  @override
  State<PilooTextField> createState() => _PilooTextFieldState();
}

class _PilooTextFieldState extends State<PilooTextField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  late bool _obscured = widget.obscure;
  bool _hasFocus = false;

  void _onFocusChange() {
    if (_focus.hasFocus != _hasFocus) {
      setState(() => _hasFocus = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.manrope(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: PilooColors.textTertiary,
    );
    final inputTextStyle = GoogleFonts.manrope(
      fontSize: 14,
      color: PilooColors.textPrimary,
    );
    final hintStyle = GoogleFonts.manrope(
      fontSize: 14,
      color: PilooColors.textTertiary,
    );

    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? PilooColors.errorOn
        : _hasFocus
            ? PilooColors.primary
            : PilooColors.border;

    return Semantics(
      label: widget.label,
      textField: true,
      value: hasError ? 'erreur : ${widget.errorText}' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label.toUpperCase(), style: labelStyle),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: widget.height,
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(PilooRadius.md),
              border: Border.all(color: borderColor),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.leadingIcon != null ? 14 : 12,
            ),
            child: Row(
              children: [
                if (widget.leadingIcon != null) ...[
                  Icon(widget.leadingIcon, size: 16, color: PilooColors.textTertiary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    obscureText: _obscured,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    style: inputTextStyle,
                    cursorColor: PilooColors.primary,
                    // Material 3 dessine un border par défaut sur chaque état
                    // (enabled/focused/disabled/error). `border:` seul ne couvre
                    // pas les états — il faut tous les tuer un par un, sinon
                    // un trait gris apparaît à l'intérieur du conteneur blanc.
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: hintStyle,
                    ),
                  ),
                ),
                if (widget.obscure) ...[
                  const SizedBox(width: 8),
                  _EyeToggle(
                    obscured: _obscured,
                    onToggle: () => setState(() => _obscured = !_obscured),
                  ),
                ],
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.errorOn,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscured, required this.onToggle});

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscured ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Icon(
          obscured ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash,
          size: 18,
          color: PilooColors.textSecondary,
        ),
      ),
    );
  }
}
