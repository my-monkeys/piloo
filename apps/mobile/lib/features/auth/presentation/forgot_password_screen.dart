// Écran A6 Mot de passe oublié (#63).
// Maquette : `fl2AZ` du fichier docs/design/piloo-mobile.pen
//
// Branchement #63 : appelle POST /api/auth/forget-password (Better Auth).
// Better Auth renvoie 200 même si l'email n'existe pas (anti-énumération),
// donc on affiche systématiquement le même message de succès.
// L'utilisateur clique le lien dans son mail → ouvre /reset-password
// côté web (Universal Links viendront avec piloo.fr).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/auth/data/auth_api.dart';
import 'package:piloo/features/auth/data/auth_api_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_text_field.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      PilooToast.error(context, 'Email invalide.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authApiProvider).forgetPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthApiException catch (e) {
      if (mounted) PilooToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                child: _sent ? _SentState(email: _email.text.trim()) : _formBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formBody() {
    return Column(
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
    );
  }
}

class _SentState extends StatelessWidget {
  const _SentState({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(child: _IconBadge()),
        const SizedBox(height: 18),
        Text(
          'Vérifie ton email',
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Si un compte existe pour cet email, un lien de réinitialisation arrive dans quelques minutes. Le lien expire dans 1 heure.",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textSecondary,
            height: 1.5,
          ),
        ),
        const Spacer(),
        Center(child: _BackToSignInLink()),
      ],
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
      onTap: () => context.canPop() ? context.pop() : context.go(RoutePath.signIn),
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
