// Écran A3 Connexion email + password (#61).
//
// Maquette : `6tsCm` du fichier docs/design/piloo-mobile.pen
// Reproduit fidèlement :
//  - Header avec back button (mêmes pattern qu'A4)
//  - Titre "Bon retour" Fraunces 28 + sous-titre Manrope 14
//  - Boutons Apple / Google (no-op, câblés en #64/#65)
//  - Divider "ou"
//  - Form email + password (height 48, gap 12) + lien
//    "Mot de passe oublié ?" aligné à droite
//  - Bouton primaire "Se connecter"
//  - Lien bas "Pas encore de compte ? S'inscrire"
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/auth/data/auth_api.dart';
import 'package:piloo/features/auth/data/auth_api_provider.dart';
import 'package:piloo/features/auth/data/session.dart';
import 'package:piloo/features/auth/data/social_sign_in_service.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_text_field.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
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
      final session = await api.signInEmail(
        email: _email.text.trim(),
        password: _password.text,
      );
      await ref.read(sessionProvider.notifier).signIn(session);

      if (!mounted) return;
      context.go(RoutePath.today);
    } on AuthApiException catch (e) {
      if (mounted) PilooToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onSocial(Future<Session> Function() doSignIn) async {
    setState(() => _submitting = true);
    try {
      final session = await doSignIn();
      await ref.read(sessionProvider.notifier).signIn(session);
      if (!mounted) return;
      context.go(RoutePath.today);
    } on SocialSignInCancelled {
      // Annulation par l'utilisateur : aucun toast — comportement attendu.
    } on SocialSignInFailure catch (e) {
      if (mounted) PilooToast.error(context, e.message);
    } on AuthApiException catch (e) {
      if (mounted) PilooToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _localValidationError() {
    if (!_email.text.contains('@')) return 'Email invalide.';
    if (_password.text.isEmpty) return 'Mot de passe requis.';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(children: [PilooCircleBackButton()]),
            ),
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
                      onPressed: _submitting
                          ? null
                          : () => _onSocial(
                                ref.read(socialSignInProvider).signInWithApple,
                              ),
                    ),
                    const SizedBox(height: 20),
                    PilooButton(
                      label: 'Continuer avec Google',
                      variant: PilooButtonVariant.google,
                      onPressed: _submitting
                          ? null
                          : () => _onSocial(
                                ref.read(socialSignInProvider).signInWithGoogle,
                              ),
                    ),
                    const SizedBox(height: 20),
                    const _OrDivider(),
                    const SizedBox(height: 20),
                    PilooTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'maxime@exemple.fr',
                      leadingIcon: PhosphorIconsRegular.envelope,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      height: 48,
                    ),
                    const SizedBox(height: 12),
                    PilooTextField(
                      label: 'Mot de passe',
                      controller: _password,
                      hint: '••••••••••',
                      leadingIcon: PhosphorIconsRegular.lockSimple,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      height: 48,
                      onSubmitted: (_) => _onSubmit(),
                    ),
                    const SizedBox(height: 12),
                    _ForgotPasswordRow(),
                    const SizedBox(height: 24),
                    PilooButton(
                      label: 'Se connecter',
                      variant: PilooButtonVariant.primary,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _onSubmit,
                    ),
                    const SizedBox(height: 12),
                    _BottomSignUpLink(),
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
          'Bon retour',
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Connecte-toi pour accéder à tes officines.',
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

class _ForgotPasswordRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => context.push(RoutePath.forgotPassword),
          child: Text(
            'Mot de passe oublié ?',
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

class _BottomSignUpLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 4,
        children: [
          Text(
            'Pas encore de compte ?',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () => context.push(RoutePath.signUp),
            child: Text(
              "S'inscrire",
              style: GoogleFonts.manrope(
                fontSize: 14,
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
