// Écran A6 Mot de passe oublié (#63).
// Maquette : `fl2AZ` du fichier docs/design/piloo-mobile.pen
//
// Reproduit fidèlement :
//  - Header back button
//  - Hero : cercle 96 $accent-soft + icône phosphor key-fill 44 $accent
//  - "Mot de passe oublié" Fraunces 26 + sous-titre Manrope 14
//    "Pas de panique. Indique ton email et on t'envoie un lien pour
//    en créer un nouveau."
//  - Form email (height 48, gap 6)
//  - Bouton "Recevoir le lien" primaire
//  - Lien bas "Retour à la connexion" $primary 14/600
//
// Scope POC : Brevo n'est pas branché (cf. #62 / docs/architecture.md).
// Le bouton "Recevoir le lien" simule l'envoi → toast info + push
// /verify-email avec l'email passé en extra. Quand Brevo arrivera, on
// branchera AuthApi.forgetPassword() qui appelle Better Auth.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_text_field.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_email.text.contains('@')) {
      PilooToast.error(context, 'Email invalide.');
      return;
    }
    setState(() => _submitting = true);
    // POC : pas d'appel API tant que Brevo n'est pas branché. On simule
    // l'envoi en passant directement à l'écran de vérification.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _submitting = false);
    PilooToast.info(context, 'Lien envoyé.');
    Navigator.of(context).pushReplacementNamed(
      RoutePath.verifyEmail,
      arguments: _email.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(children: [PilooCircleBackButton()]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(child: _IconBadge()),
                    const SizedBox(height: 18),
                    _Title(),
                    const SizedBox(height: 20),
                    PilooTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'maxime@exemple.fr',
                      leadingIcon: PhosphorIconsRegular.envelope,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      height: 48,
                      onSubmitted: (_) => _onSubmit(),
                    ),
                    const Spacer(),
                    PilooButton(
                      label: 'Recevoir le lien',
                      variant: PilooButtonVariant.primary,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _onSubmit,
                    ),
                    const SizedBox(height: 20),
                    Center(child: _BackToSignInLink()),
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

class _IconBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: PilooColors.accentSoft,
      ),
      alignment: Alignment.center,
      child: const Icon(
        PhosphorIconsFill.key,
        size: 44,
        color: PilooColors.accent,
      ),
    );
  }
}

class _Title extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Mot de passe oublié',
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Pas de panique. Indique ton email et on t'envoie un lien pour en créer un nouveau.",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _BackToSignInLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Text(
        'Retour à la connexion',
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: PilooColors.primary,
        ),
      ),
    );
  }
}
