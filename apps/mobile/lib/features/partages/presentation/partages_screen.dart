// Écran S2 Gestion partages (#131 + branchement API #339).
// Maquette : `8dyxn` du fichier docs/design/piloo-mobile.pen.
//
// Permet à l'owner d'une officine de :
//  - voir la liste des membres + invitations en attente
//  - changer le rôle d'un membre (dropdown sur le badge)
//  - retirer un membre (bottom sheet de confirmation)
//  - inviter quelqu'un (push S3 #133)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/core/config/api_config.dart';
import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/partages/data/partages_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

enum _Role { proprietaire, editeur, lecteur }

_Role _roleFromApi(api.PartageMemberRoleEnum r) {
  if (r == api.PartageMemberRoleEnum.owner) return _Role.proprietaire;
  if (r == api.PartageMemberRoleEnum.editor) return _Role.editeur;
  return _Role.lecteur;
}

_Role _roleFromPendingApi(api.PendingMemberInvitationRoleEnum r) {
  if (r == api.PendingMemberInvitationRoleEnum.owner) return _Role.proprietaire;
  if (r == api.PendingMemberInvitationRoleEnum.editor) return _Role.editeur;
  return _Role.lecteur;
}

api.UpdatePartageRoleInputRoleEnum _roleToApi(_Role r) => switch (r) {
      _Role.proprietaire => api.UpdatePartageRoleInputRoleEnum.owner,
      _Role.editeur => api.UpdatePartageRoleInputRoleEnum.editor,
      _Role.lecteur => api.UpdatePartageRoleInputRoleEnum.viewer,
    };

class _Member {
  const _Member({
    required this.userId,
    required this.initials,
    required this.avatarColor,
    required this.name,
    required this.email,
    required this.role,
    this.invitationPending = false,
    this.isSelf = false,
    this.invitationId,
    this.expiresAt,
  });

  final String? userId;
  final String initials;
  final Color avatarColor;
  final String name;
  final String email;
  final _Role role;
  final bool invitationPending;
  final bool isSelf;
  final String? invitationId;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get inviteLink =>
      '${ApiConfig.baseUrl}/invitations/$invitationId';
}

class PartagesScreen extends ConsumerWidget {
  const PartagesScreen({this.officineId, super.key});

  final String? officineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = officineId;
    if (id == null || id.isEmpty) {
      return const _MissingOfficineScaffold();
    }
    final partagesAsync = ref.watch(partagesProvider(id));
    final session = ref.watch(sessionProvider).value;
    final currentUserId = session?.userId;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(officineLabel: 'Officine'),
            Expanded(
              child: partagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Impossible de charger les membres.\n$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: PilooColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                data: (data) => _LoadedBody(
                  officineId: id,
                  data: data,
                  currentUserId: currentUserId,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PilooButton(
                label: "+ Inviter quelqu'un",
                variant: PilooButtonVariant.primary,
                onPressed: () => context.push(RoutePath.invite(id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingOfficineScaffold extends StatelessWidget {
  const _MissingOfficineScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(officineLabel: ''),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "Aucune officine sélectionnée. Reviens en arrière et choisis-en une.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: PilooColors.textSecondary,
                      fontSize: 13,
                    ),
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

/// Corps quand les données API sont chargées. Convertit le payload
/// API en liste de `_Member` (mix membres actifs + invitations en
/// attente) et délègue le rendu aux sous-widgets de présentation.
class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({
    required this.officineId,
    required this.data,
    required this.currentUserId,
  });

  final String officineId;
  final api.PartagesList data;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = <_Member>[
      for (final m in data.members)
        _Member(
          userId: m.userId,
          initials: _initialsFromName(m.displayName, m.email),
          avatarColor: _colorForUserId(m.userId),
          name: m.displayName + (m.userId == currentUserId ? ' (toi)' : ''),
          email: m.email,
          role: _roleFromApi(m.role),
          isSelf: m.userId == currentUserId,
        ),
      for (final inv in data.pendingInvitations)
        _Member(
          userId: null,
          initials: _initialsFromEmail(inv.email),
          avatarColor: PilooColors.primarySoft,
          name: inv.email ?? 'Invitation par lien',
          email: inv.email ?? 'Lien partageable',
          role: _roleFromPendingApi(inv.role),
          invitationPending: true,
          invitationId: inv.invitationId,
          expiresAt: inv.expiresAt.toLocal(),
        ),
    ];

    Future<void> handleRoleChange(int idx, _Role newRole) async {
      final m = members[idx];
      final uid = m.userId;
      if (uid == null) return;
      try {
        await updateMemberRole(
          ref,
          officineId: officineId,
          userId: uid,
          role: _roleToApi(newRole),
        );
        if (context.mounted) PilooToast.success(context, 'Rôle mis à jour.');
      } catch (e) {
        if (context.mounted) PilooToast.error(context, 'Échec : $e');
      }
    }

    Future<void> handleRevoke(int idx) async {
      final m = members[idx];
      final uid = m.userId;
      if (uid == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Retirer ce membre ?'),
          content: Text(
            '${m.name} n\'aura plus accès à cette officine. Tu pourras la ou le réinviter plus tard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: PilooColors.error),
              child: const Text('Retirer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        await revokeMember(ref, officineId: officineId, userId: uid);
        if (context.mounted) PilooToast.success(context, 'Membre retiré.');
      } catch (e) {
        if (context.mounted) PilooToast.error(context, 'Échec : $e');
      }
    }

    Future<void> handleCopyLink(int idx) async {
      final m = members[idx];
      if (m.invitationId == null) return;
      await Clipboard.setData(ClipboardData(text: m.inviteLink));
      if (context.mounted) PilooToast.success(context, 'Lien copié.');
    }

    Future<void> handleCancelInvitation(int idx) async {
      final m = members[idx];
      if (m.invitationId == null) return;
      try {
        await cancelInvitation(ref, invitationId: m.invitationId!);
        if (context.mounted) PilooToast.success(context, 'Invitation annulée.');
      } catch (e) {
        if (context.mounted) PilooToast.error(context, 'Échec : $e');
      }
    }

    Future<void> handleResend(int idx) async {
      final m = members[idx];
      if (m.invitationId == null) return;
      try {
        // Annule l'ancienne puis recrée (le backend nettoie les doublons).
        await cancelInvitation(ref, invitationId: m.invitationId!);
        context.push(RoutePath.invite(officineId));
      } catch (e) {
        if (context.mounted) PilooToast.error(context, 'Échec : $e');
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Eyebrow(label: 'MEMBRES · ${members.length}'),
          const SizedBox(height: 8),
          _MembersCard(
            members: members,
            onRoleChange: handleRoleChange,
            onRevoke: handleRevoke,
            onCopyLink: handleCopyLink,
            onCancelInvitation: handleCancelInvitation,
            onResend: handleResend,
          ),
          const SizedBox(height: 16),
          const _RolesHelp(),
        ],
      ),
    );
  }
}

String _initialsFromName(String name, String email) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return _initialsFromEmail(email);
  final first = parts.first.substring(0, 1).toUpperCase();
  final second = parts.length > 1
      ? parts.elementAt(1).substring(0, 1).toUpperCase()
      : '';
  return '$first$second';
}

String _initialsFromEmail(String? email) {
  if (email == null || email.isEmpty) return '?';
  return email.substring(0, 1).toUpperCase();
}

/// Couleur d'avatar stable basée sur l'userId — évite que tout le
/// monde apparaisse en vert (qui suggérerait à tort un rôle owner).
Color _colorForUserId(String userId) {
  final palette = [
    PilooColors.primary,
    PilooColors.accent,
    PilooColors.infoOn,
  ];
  final h = userId.hashCode.abs();
  return palette[h % palette.length];
}

class _Header extends StatelessWidget {
  const _Header({required this.officineLabel});

  final String officineLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PilooCircleBackButton(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Partages',
                  style: GoogleFonts.fraunces(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                if (officineLabel.isNotEmpty)
                  Text(
                    officineLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: PilooColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: PilooColors.textTertiary,
        ),
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.members,
    required this.onRoleChange,
    required this.onRevoke,
    this.onCopyLink,
    this.onCancelInvitation,
    this.onResend,
  });

  final List<_Member> members;
  final Future<void> Function(int index, _Role newRole) onRoleChange;
  final Future<void> Function(int index) onRevoke;
  final Future<void> Function(int index)? onCopyLink;
  final Future<void> Function(int index)? onCancelInvitation;
  final Future<void> Function(int index)? onResend;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: Border.all(color: PilooColors.border),
        ),
        child: Text(
          'Aucun membre.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textSecondary,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        children: List.generate(members.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(height: 1, color: PilooColors.border);
          }
          final idx = i ~/ 2;
          return _MemberRow(
            member: members[idx],
            onRoleChange: (r) => onRoleChange(idx, r),
            onRevoke: () => onRevoke(idx),
            onCopyLink: onCopyLink != null ? () => onCopyLink!(idx) : null,
            onCancel: onCancelInvitation != null
                ? () => onCancelInvitation!(idx)
                : null,
            onResend: onResend != null ? () => onResend!(idx) : null,
          );
        }),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onRoleChange,
    required this.onRevoke,
    this.onCopyLink,
    this.onCancel,
    this.onResend,
  });

  final _Member member;
  final ValueChanged<_Role> onRoleChange;
  final VoidCallback onRevoke;
  final VoidCallback? onCopyLink;
  final VoidCallback? onCancel;
  final VoidCallback? onResend;

  String _expiryLabel() {
    final exp = member.expiresAt;
    if (exp == null) return 'invitation en attente';
    if (exp.isBefore(DateTime.now())) return 'expirée';
    final diff = exp.difference(DateTime.now());
    if (diff.inHours >= 24) return 'expire dans ${diff.inDays}j';
    if (diff.inHours >= 1) return 'expire dans ${diff.inHours}h';
    return 'expire dans ${diff.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == _Role.proprietaire;
    final canEdit = !isOwner && !member.isSelf && !member.invitationPending;
    final isPending = member.invitationPending;

    if (isPending) {
      return _PendingInvitationRow(
        member: member,
        expiryLabel: _expiryLabel(),
        onCopyLink: onCopyLink,
        onCancel: onCancel,
        onResend: member.isExpired ? onResend : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(
            initials: member.initials,
            color: member.avatarColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RoleBadge(
            role: member.role,
            onChange: canEdit ? onRoleChange : null,
          ),
          if (canEdit) ...[
            const SizedBox(width: 6),
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(
                PhosphorIconsRegular.trash,
                color: PilooColors.error,
              ),
              onPressed: onRevoke,
              tooltip: 'Retirer',
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingInvitationRow extends StatelessWidget {
  const _PendingInvitationRow({
    required this.member,
    required this.expiryLabel,
    this.onCopyLink,
    this.onCancel,
    this.onResend,
  });

  final _Member member;
  final String expiryLabel;
  final VoidCallback? onCopyLink;
  final VoidCallback? onCancel;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final isExpired = member.isExpired;
    final statusColor = isExpired ? PilooColors.error : PilooColors.warningOn;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                initials: member.initials,
                color: member.avatarColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expiryLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              _RoleBadge(role: member.role, onChange: null),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onCopyLink != null)
                _SmallAction(
                  icon: PhosphorIconsRegular.copy,
                  label: 'Copier le lien',
                  onTap: onCopyLink!,
                ),
              if (onResend != null) ...[
                const SizedBox(width: 8),
                _SmallAction(
                  icon: PhosphorIconsRegular.arrowCounterClockwise,
                  label: 'Renvoyer',
                  onTap: onResend!,
                ),
              ],
              const Spacer(),
              if (onCancel != null)
                _SmallAction(
                  icon: PhosphorIconsRegular.x,
                  label: 'Annuler',
                  onTap: onCancel!,
                  destructive: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? PilooColors.error : PilooColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fg = color == PilooColors.primarySoft
        ? PilooColors.primary
        : Colors.white;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.role,
    required this.onChange,
    this.bgOverride,
  });

  final _Role role;
  final ValueChanged<_Role>? onChange;
  final Color? bgOverride;

  ({Color bg, Color fg, String label}) get _style => switch (role) {
        _Role.proprietaire => (
            bg: PilooColors.primarySoft,
            fg: PilooColors.primary,
            label: 'Propriétaire',
          ),
        _Role.editeur => (
            bg: PilooColors.info,
            fg: PilooColors.infoOn,
            label: 'Éditeur',
          ),
        _Role.lecteur => (
            bg: PilooColors.surfaceSubtle,
            fg: PilooColors.textSecondary,
            label: 'Lecteur',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final body = Container(
      padding: EdgeInsets.fromLTRB(10, 4, onChange == null ? 10 : 8, 4),
      decoration: BoxDecoration(
        color: bgOverride ?? s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: s.fg,
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 3),
            Icon(PhosphorIconsRegular.caretDown, size: 10, color: s.fg),
          ],
        ],
      ),
    );

    if (onChange == null) return body;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await _pickRole(context, role);
        if (picked != null) onChange!(picked);
      },
      child: body,
    );
  }

  Future<_Role?> _pickRole(BuildContext context, _Role current) async {
    return showModalBottomSheet<_Role>(
      context: context,
      backgroundColor: PilooColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PilooColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (final r in [_Role.proprietaire, _Role.editeur, _Role.lecteur])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(r),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PilooColors.surface,
                        borderRadius: BorderRadius.circular(PilooRadius.md),
                        border: Border.all(
                          color: r == current
                              ? PilooColors.primary
                              : PilooColors.border,
                          width: r == current ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              switch (r) {
                                _Role.proprietaire => 'Propriétaire',
                                _Role.editeur => 'Éditeur',
                                _Role.lecteur => 'Lecteur',
                              },
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: PilooColors.textPrimary,
                              ),
                            ),
                          ),
                          if (r == current)
                            const Icon(
                              PhosphorIconsBold.check,
                              size: 16,
                              color: PilooColors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolesHelp extends StatelessWidget {
  const _RolesHelp();

  static const _entries = [
    (role: _Role.proprietaire, desc: 'tout, y compris gérer les partages'),
    (role: _Role.editeur, desc: 'modifier boîtes & ordonnances'),
    (role: _Role.lecteur, desc: 'consulter + signaler un manque'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LES RÔLES',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: PilooColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_entries.length * 2 - 1, (i) {
            if (i.isOdd) return const SizedBox(height: 10);
            final e = _entries[i ~/ 2];
            return _RoleHelpRow(role: e.role, description: e.desc);
          }),
        ],
      ),
    );
  }
}

class _RoleHelpRow extends StatelessWidget {
  const _RoleHelpRow({required this.role, required this.description});

  final _Role role;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _RoleBadge(
          role: role,
          onChange: null,
          bgOverride: role == _Role.lecteur ? PilooColors.surface : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: PilooColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
