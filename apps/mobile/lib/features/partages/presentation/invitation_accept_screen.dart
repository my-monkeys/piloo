// Écran S4 Accepter invitation (#135).
//
// Atterrissage depuis un lien d'invitation (deeplink
// `/invitations/:token`). Branché aux endpoints :
//   - GET /v1/invitations/{token} → preview (qui invite, officine, rôle)
//   - POST /v1/invitations/{token}/accept → ajoute l'utilisateur courant
//
// Accepter → ajoute l'utilisateur à l'officine puis push vers /today.
// Refuser → ne contacte pas le serveur (le lien restera valide jusqu'à
// expiration). Pour vraiment révoquer, le propriétaire passe par
// l'écran web Settings → Officines.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';
import 'package:piloo/features/partages/data/invitation_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class InvitationAcceptScreen extends ConsumerStatefulWidget {
  const InvitationAcceptScreen({this.token, super.key});

  final String? token;

  @override
  ConsumerState<InvitationAcceptScreen> createState() =>
      _InvitationAcceptScreenState();
}

class _InvitationAcceptScreenState
    extends ConsumerState<InvitationAcceptScreen> {
  bool _accepting = false;

  Future<void> _accept() async {
    final token = widget.token;
    if (token == null || _accepting) return;
    setState(() => _accepting = true);
    try {
      await acceptInvitation(ref, token);
      ref.invalidate(officinesListProvider);
      ref.invalidate(activeOfficineProvider);
      if (mounted) {
        PilooToast.success(context, 'Invitation acceptée.');
        context.go(RoutePath.today);
      }
    } catch (e) {
      if (mounted) {
        PilooToast.error(context, 'Impossible d\'accepter : $e');
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePath.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null) {
      return Scaffold(
        backgroundColor: PilooColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              children: [
                _Header(onClose: _close),
                const SizedBox(height: 24),
                Text(
                  'Lien invalide.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final previewAsync = ref.watch(invitationPreviewProvider(token));
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: previewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _Header(onClose: _close),
                const SizedBox(height: 24),
                Text(
                  'Impossible de charger l\'invitation.\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          data: (preview) => _buildBody(preview),
        ),
      ),
    );
  }

  Widget _buildBody(api.InvitationPreview preview) {
    final isPending =
        preview.status == api.InvitationPreviewStatusEnum.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(onClose: _close),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(
                  initials: _initialsFrom(preview.invitedByName),
                  inviterName: preview.invitedByName,
                  officineName: preview.officineNom,
                ),
                const SizedBox(height: 18),
                Center(child: _RoleBadge(role: preview.role)),
                if (!isPending) ...[
                  const SizedBox(height: 16),
                  _StatusBanner(status: preview.status),
                ],
              ],
            ),
          ),
        ),
        if (isPending)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                PilooButton(
                  label: _accepting
                      ? 'Acceptation...'
                      : "Accepter l'invitation",
                  variant: PilooButtonVariant.primary,
                  onPressed: _accepting ? null : _accept,
                ),
                const SizedBox(height: 8),
                PilooButton(
                  label: 'Refuser',
                  variant: PilooButtonVariant.outline,
                  onPressed: _close,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _initialsFrom(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.initials,
    required this.inviterName,
    required this.officineName,
  });

  final String initials;
  final String inviterName;
  final String officineName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.accent,
            boxShadow: [
              BoxShadow(
                color: PilooColors.accent.withValues(alpha: 0.2),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          inviterName,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PilooColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "t'invite à rejoindre",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          officineName,
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final api.InvitationPreviewRoleEnum role;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (role) {
      api.InvitationPreviewRoleEnum.owner => (
          'En tant que Propriétaire',
          PhosphorIconsRegular.key,
        ),
      api.InvitationPreviewRoleEnum.editor => (
          "En tant qu'Éditeur",
          PhosphorIconsRegular.pencilSimple,
        ),
      api.InvitationPreviewRoleEnum.viewer => (
          'En tant que Lecteur',
          PhosphorIconsRegular.eye,
        ),
      _ => ('Invitation', PhosphorIconsRegular.envelope),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PilooColors.info,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PilooColors.infoOn),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PilooColors.infoOn,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final api.InvitationPreviewStatusEnum status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      api.InvitationPreviewStatusEnum.expired => 'Cette invitation a expiré.',
      api.InvitationPreviewStatusEnum.accepted =>
        'Cette invitation a déjà été acceptée.',
      api.InvitationPreviewStatusEnum.revoked =>
        "Cette invitation a été révoquée.",
      _ => 'Invitation indisponible.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PilooColors.warning,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.warningOn),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: PilooColors.warningOn,
        ),
      ),
    );
  }
}
