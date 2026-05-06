// Écran A4 Inscription email + password (#60).
//
// Maquette : `w1tR2` du fichier docs/design/piloo-mobile.pen
// Reproduit fidèlement :
//  - StatusBar (gérée nativement via SafeArea)
//  - Header avec circle back button
//  - Titre Fraunces 26 + sous-titre Manrope 14
//  - Boutons Apple / Google (no-op pour le POC, câblés en #64/#65)
//  - Divider "ou"
//  - Form prénom/nom (row), email, password (avec eye toggle)
//  - Checkbox CGU obligatoire + texte 12px ($text-secondary)
//  - Spacer + bouton Primary "Créer mon compte"
//  - Lien bas "Déjà un compte ? Se connecter"
//
// `typeCompte` est passé en argument constructor — il a normalement été
// choisi à l'écran A2 (#59). Tant que A2 n'existe pas, le router peut
// défaulter à 'particulier'.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/auth/data/auth_api.dart';
import 'package:piloo/features/auth/data/auth_api_provider.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_checkbox.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_text_field.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({this.typeCompte = 'particulier', super.key});

  final String typeCompte;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cguAccepted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final invalid = _localValidationError();
    if (invalid != null) {
      PilooToast.error(context, invalid);
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(authApiProvider);
      final session = await api.signUpEmail(
        email: _email.text.trim(),
        password: _password.text,
        name: '${_prenom.text.trim()} ${_nom.text.trim()}'.trim(),
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        typeCompte: widget.typeCompte,
      );
      await ref.read(sessionProvider.notifier).signIn(session);

      if (!mounted) return;
      // Atterrissage sur l'écran principal après inscription.
      Navigator.of(context).pushNamedAndRemoveUntil(
        RoutePath.today,
        (_) => false,
      );
    } on AuthApiException catch (e) {
      if (mounted) PilooToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _localValidationError() {
    if (_prenom.text.trim().isEmpty) return 'Prénom requis.';
    if (_nom.text.trim().isEmpty) return 'Nom requis.';
    if (!_email.text.contains('@')) return 'Email invalide.';
    if (_password.text.length < 8) return 'Mot de passe : 8 caractères minimum.';
    if (!_cguAccepted) return 'Tu dois accepter les conditions.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec back button.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [PilooCircleBackButton()],
              ),
            ),
            // Contenu principal scrollable, padding top:16 right/bottom/left:24.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Title(),
                    const SizedBox(height: 20),
                    PilooButton(
                      label: 'Continuer avec Apple',
                      variant: PilooButtonVariant.apple,
                      onPressed: _submitting ? null : () {/* #64 */},
                    ),
                    const SizedBox(height: 20),
                    PilooButton(
                      label: 'Continuer avec Google',
                      variant: PilooButtonVariant.google,
                      onPressed: _submitting ? null : () {/* #65 */},
                    ),
                    const SizedBox(height: 20),
                    const _OrDivider(),
                    const SizedBox(height: 20),
                    _NameRow(prenom: _prenom, nom: _nom),
                    const SizedBox(height: 10),
                    PilooTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'maxime@exemple.fr',
                      leadingIcon: PhosphorIconsRegular.envelope,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 10),
                    PilooTextField(
                      label: 'Mot de passe',
                      controller: _password,
                      hint: 'Au moins 8 caractères',
                      leadingIcon: PhosphorIconsRegular.lockSimple,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _onSubmit(),
                    ),
                    const SizedBox(height: 20),
                    _CguRow(
                      value: _cguAccepted,
                      onChanged: (v) => setState(() => _cguAccepted = v),
                    ),
                    const SizedBox(height: 24),
                    PilooButton(
                      label: 'Créer mon compte',
                      variant: PilooButtonVariant.primary,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _onSubmit,
                    ),
                    const SizedBox(height: 12),
                    _BottomSignInLink(),
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

class _Title extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Créons ton compte',
          style: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Quelques infos et tu pourras scanner ta première boîte.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: PilooColors.border, height: 1)),
        const SizedBox(width: 12),
        Text(
          'ou',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: PilooColors.border, height: 1)),
      ],
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.prenom, required this.nom});

  final TextEditingController prenom;
  final TextEditingController nom;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: PilooTextField(
            label: 'Prénom',
            controller: prenom,
            hint: 'Maxime',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PilooTextField(
            label: 'Nom',
            controller: nom,
            hint: 'Durand',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
          ),
        ),
      ],
    );
  }
}

class _CguRow extends StatelessWidget {
  const _CguRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: PilooCheckbox(value: value, onChanged: onChanged),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              "J'accepte les Conditions générales et la Politique de confidentialité. Piloo est un carnet de suivi personnel, pas un dispositif médical.",
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomSignInLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 4,
        children: [
          Text(
            'Déjà un compte ?',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: PilooColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(RoutePath.signIn),
            child: Text(
              'Se connecter',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PilooColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
