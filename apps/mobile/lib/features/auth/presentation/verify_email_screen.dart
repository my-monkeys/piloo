// Écran A5 Vérification email (#62).
// Maquette : `CYraU` du fichier docs/design/piloo-mobile.pen
//
// Reproduit fidèlement :
//  - Header avec back button
//  - Hero : cercle 120 $primary-soft + envelope-simple-fill 56 $primary
//    avec shadow blur 16 / offset (0,4) / #4a6b6420
//  - "Vérifie ton email" Fraunces 26 + sous-titre "On vient
//    d'envoyer un lien de confirmation à" + email pill
//  - Bloc d'aide $surface-subtle padding 14 avec icône info
//  - Bouton "J'ai cliqué sur le lien"
//  - "Pas reçu ? Renvoyer dans Xs" — countdown 60s puis lien actif
//
// Branchement #62 : "Renvoyer" appelle réellement
// POST /api/auth/send-verification-email (Better Auth). "J'ai cliqué"
// renvoie vers /sign-in : la session n'est créée que par un signIn
// post-vérification (le lien magique ouvre le navigateur, pas l'app —
// les Universal Links seront ajoutés une fois le domaine piloo.fr posé).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/auth/data/auth_api.dart';
import 'package:piloo/features/auth/data/auth_api_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({this.email = 'votre@email.fr', super.key});

  final String email;

  static const int _resendCooldownSeconds = 60;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late int _secondsLeft = VerifyEmailScreen._resendCooldownSeconds;
  Timer? _ticker;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(
      () => _secondsLeft = VerifyEmailScreen._resendCooldownSeconds,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _onVerified() {
    // Le lien magique ouvre la page web /email-verified : il n'y a pas
    // de cookie partagé avec l'app native, donc on ne peut pas auto-
    // logger l'utilisateur ici. On le renvoie sur sign-in avec son
    // email pré-rempli — le signIn passera maintenant que `emailVerified`
    // est vrai côté serveur.
    context.go(RoutePath.signIn);
  }

  Future<void> _onResend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await ref.read(authApiProvider).sendVerificationEmail(widget.email);
      if (!mounted) return;
      PilooToast.info(context, "Email renvoyé.");
      _startCountdown();
    } on AuthApiException catch (e) {
      if (mounted) PilooToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Center(child: _IconBadge()),
                    const SizedBox(height: 20),
                    _TextGroup(email: widget.email),
                    const SizedBox(height: 16),
                    _HelpBox(),
                    const Spacer(),
                    PilooButton(
                      label: "J'ai cliqué sur le lien",
                      variant: PilooButtonVariant.primary,
                      onPressed: _onVerified,
                    ),
                    const SizedBox(height: 20),
                    _ResendRow(
                      secondsLeft: _secondsLeft,
                      onResend: () {
                        unawaited(_onResend());
                      },
                    ),
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
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PilooColors.primarySoft,
        boxShadow: [
          BoxShadow(
            color: PilooColors.primary.withValues(alpha: 0.125),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        PhosphorIconsFill.envelopeSimple,
        size: 56,
        color: PilooColors.primary,
      ),
    );
  }
}

class _TextGroup extends StatelessWidget {
  const _TextGroup({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          "On vient d'envoyer un lien de confirmation à",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        _EmailPill(email: email),
      ],
    );
  }
}

class _EmailPill extends StatelessWidget {
  const _EmailPill({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.full),
        border: Border.all(color: PilooColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            PhosphorIconsFill.envelope,
            size: 14,
            color: PilooColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            email,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PilooColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsRegular.info,
            size: 18,
            color: PilooColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Ouvre l'email et clique sur le lien. Pense à vérifier tes spams si tu ne le vois pas.",
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsLeft, required this.onResend});

  final int secondsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final canResend = secondsLeft <= 0;
    final actionText = canResend ? 'Renvoyer' : 'Renvoyer dans ${secondsLeft}s';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pas reçu ?',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canResend ? onResend : null,
          child: Text(
            actionText,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: canResend
                  ? PilooColors.primary
                  : PilooColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
