// Écran de suppression de compte (App Store Guideline 5.1.1(v) / RGPD).
//
// Accessible depuis Profil → « Supprimer mon compte ». Explique les
// conséquences, exige une confirmation explicite (case à cocher), puis
// déclenche POST /v1/me/delete (suppression différée 7 jours côté
// serveur, annulable via reconnexion) et déconnecte l'utilisateur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/settings/data/account_delete_provider.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _submitting = false;

  Future<void> _delete() async {
    setState(() => _submitting = true);
    try {
      await requestAccountDeletion(ref);
      await ref.read(sessionProvider.notifier).signOut();
      if (mounted) context.go(RoutePath.welcome);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        PilooToast.error(context, 'Échec de la suppression. Réessaie.');
      }
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
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: PilooColors.error,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        PhosphorIconsFill.warning,
                        size: 30,
                        color: PilooColors.errorOn,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Supprimer mon compte',
                      style: GoogleFonts.fraunces(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cette action supprime définitivement ton compte et toutes '
                      'tes données : officines, boîtes, ordonnances, rappels et '
                      'partages.',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        height: 1.5,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _InfoRow(
                      icon: PhosphorIconsRegular.clock,
                      text: 'Un délai de 7 jours s\'applique avant l\'effacement '
                          'définitif. Reconnecte-toi pendant ce délai pour '
                          'annuler la suppression.',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: PhosphorIconsRegular.usersThree,
                      text: 'Les officines que tu partages avec des proches '
                          'restent accessibles à leurs autres membres.',
                    ),
                    const SizedBox(height: 28),
                    _ConfirmCheckbox(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _DeleteButton(
                enabled: _confirmed && !_submitting,
                loading: _submitting,
                onTap: _delete,
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
              'Compte',
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: PilooColors.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.45,
              color: PilooColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmCheckbox extends StatelessWidget {
  const _ConfirmCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: value ? PilooColors.errorOn : PilooColors.surface,
              border: Border.all(
                color: value ? PilooColors.errorOn : PilooColors.border,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: value
                ? const Icon(PhosphorIconsBold.check,
                    size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Je comprends que cette action est définitive.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: PilooColors.errorOn,
            borderRadius: BorderRadius.circular(PilooRadius.md),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  'Supprimer définitivement',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
