// Écran S1 Mes officines (#72).
// Maquette : `RV85C` du fichier docs/design/piloo-mobile.pen.
//
// Liste des officines auxquelles l'utilisateur a accès :
//  - sa propre officine personnelle (Maison)
//  - officines partagées avec lui (par un proche, ex: Papa)
//  - officines pro de santé (patient suivi par un IDEL)
//
// Card "active" : bord 2px primary + badge Actif (check). Tap sur une
// autre card switch l'officine active (state global Riverpod plus
// tard ; pour l'instant on bascule juste localement).
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
import 'package:piloo/features/officines/data/pending_invitations_provider.dart';
import 'package:piloo/features/officines/presentation/officine_edit_sheet.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

enum _OfficineRole { proprietaire, editeur, lecteur }

class _Officine {
  const _Officine({
    required this.id,
    required this.name,
    required this.meta,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.role,
  });

  final String id;
  final String name;
  final String meta;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final _OfficineRole role;
}

class OfficinesListScreen extends ConsumerStatefulWidget {
  const OfficinesListScreen({super.key});

  @override
  ConsumerState<OfficinesListScreen> createState() =>
      _OfficinesListScreenState();
}

class _OfficinesListScreenState extends ConsumerState<OfficinesListScreen> {

  Future<void> _showActions(BuildContext context, _Officine officine) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PilooColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
              _SheetAction(
                icon: PhosphorIconsRegular.users,
                label: 'Membres',
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push(RoutePath.partages(officine.id));
                },
              ),
              const SizedBox(height: 8),
              _SheetAction(
                icon: PhosphorIconsRegular.pencilSimple,
                label: 'Renommer',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final updated = await showOfficineEditSheet(
                    context,
                    initial: OfficineDraft(name: officine.name),
                  );
                  if (updated != null && context.mounted) {
                    PilooToast.success(
                      context,
                      'Renommée en "${updated.name}".',
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              _SheetAction(
                icon: PhosphorIconsRegular.archive,
                label: 'Archiver',
                destructive: true,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ok = await confirmArchiveOfficine(
                    context,
                    officineName: officine.name,
                  );
                  if (ok && context.mounted) {
                    PilooToast.info(
                      context,
                      '"${officine.name}" archivée.',
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(officinesListProvider);
    final activeAsync = ref.watch(activeOfficineProvider);
    final activeId = activeAsync.value?.id;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onAdd: () async {
              final draft = await showOfficineEditSheet(context);
              if (draft != null && context.mounted) {
                PilooToast.success(
                  context,
                  'Officine "${draft.name}" créée.',
                );
                ref.invalidate(officinesListProvider);
              }
            }),
            Expanded(
              child: listAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Impossible de charger les officines.\n$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                data: (rows) {
                  return CustomScrollView(
                    slivers: [
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                        sliver: SliverToBoxAdapter(child: _PendingInvitationsSection()),
                      ),
                      if (rows.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Aucune officine.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: PilooColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          sliver: SliverList.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final o = _mapApi(rows[i]);
                              return _OfficineCard(
                                officine: o,
                                active: o.id == activeId,
                                onTap: () => ref
                                    .read(activeOfficineProvider.notifier)
                                    .select(o.id),
                                onActions: () => _showActions(context, o),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_Officine _mapApi(api.Officine o) {
  final role = switch (o.role) {
    api.OfficineRoleEnum.owner => _OfficineRole.proprietaire,
    api.OfficineRoleEnum.editor => _OfficineRole.editeur,
    api.OfficineRoleEnum.viewer => _OfficineRole.lecteur,
    _ => _OfficineRole.lecteur,
  };
  final (icon, color, bg) = switch (o.type) {
    api.OfficineTypeEnum.perso => (
        PhosphorIconsFill.house,
        PilooColors.primary,
        PilooColors.primarySoft,
      ),
    api.OfficineTypeEnum.patient => (
        PhosphorIconsFill.userCircle,
        PilooColors.textSecondary,
        PilooColors.surfaceSubtle,
      ),
    _ => (
        PhosphorIconsFill.house,
        PilooColors.primary,
        PilooColors.primarySoft,
      ),
  };
  return _Officine(
    id: o.id,
    name: o.nom,
    meta: _formatMeta(o),
    icon: icon,
    iconColor: color,
    iconBg: bg,
    role: role,
  );
}

String _formatMeta(api.Officine o) {
  return switch (o.type) {
    api.OfficineTypeEnum.perso => 'Officine personnelle',
    api.OfficineTypeEnum.patient => 'Patient pro de santé',
    _ => '',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

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
              'Mes officines',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAdd,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.primary,
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsBold.plus,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficineCard extends StatelessWidget {
  const _OfficineCard({
    required this.officine,
    required this.active,
    required this.onTap,
    required this.onActions,
  });

  final _Officine officine;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onActions;

  ({Color bg, Color fg, String label}) get _roleStyle => switch (officine.role) {
        _OfficineRole.proprietaire => (
            bg: PilooColors.primarySoft,
            fg: PilooColors.primary,
            label: 'Propriétaire',
          ),
        _OfficineRole.editeur => (
            bg: PilooColors.info,
            fg: PilooColors.infoOn,
            label: 'Éditeur',
          ),
        _OfficineRole.lecteur => (
            bg: PilooColors.surfaceSubtle,
            fg: PilooColors.textSecondary,
            label: 'Lecteur',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final role = _roleStyle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Padding compensé : 13 quand bord 2px, 14 quand bord 1px.
        padding: EdgeInsets.all(active ? 13 : 14),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: Border.all(
            color: active ? PilooColors.primary : PilooColors.border,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: officine.iconBg,
                    borderRadius: BorderRadius.circular(PilooRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    officine.icon,
                    size: 22,
                    color: officine.iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officine.name,
                        style: GoogleFonts.fraunces(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: PilooColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        officine.meta,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: PilooColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton actions (molette) : toujours visible pour
                // remplacer le long-press qui n'était pas découvrable.
                _ActionsButton(onTap: onActions),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: role.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role.label,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: role.fg,
                    ),
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 8),
                  const _ActiveBadge(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PilooColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsBold.check, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Actif',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsButton extends StatelessWidget {
  const _ActionsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          PhosphorIconsRegular.gear,
          size: 20,
          color: PilooColors.textSecondary,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
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
    final fg = destructive ? PilooColors.errorOn : PilooColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section "Invitations en attente" (#129). Affichée au-dessus de la liste
/// des officines quand au moins une invitation pending matche l'email de
/// l'user. Permet l'accept inline sans passer par le lien dédié.
class _PendingInvitationsSection extends ConsumerWidget {
  const _PendingInvitationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(pendingInvitationsProvider);
    return asyncList.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Text(
                  'Invitations en attente',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              for (final inv in items) ...[
                _PendingInvitationCard(invitation: inv),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PendingInvitationCard extends ConsumerStatefulWidget {
  const _PendingInvitationCard({required this.invitation});

  final api.PendingInvitation invitation;

  @override
  ConsumerState<_PendingInvitationCard> createState() => _PendingInvitationCardState();
}

class _PendingInvitationCardState extends ConsumerState<_PendingInvitationCard> {
  bool _accepting = false;

  String _roleLabel(api.PendingInvitationRoleEnum r) {
    if (r == api.PendingInvitationRoleEnum.owner) return 'Propriétaire';
    if (r == api.PendingInvitationRoleEnum.editor) return 'Éditeur';
    return 'Lecteur';
  }

  Future<void> _onAccept() async {
    setState(() => _accepting = true);
    try {
      await acceptInvitation(ref, widget.invitation.token);
      if (!mounted) return;
      PilooToast.success(context, 'Tu as rejoint "${widget.invitation.officineNom}".');
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(officinesListProvider);
    } catch (_) {
      if (mounted) PilooToast.error(context, "Impossible d'accepter l'invitation.");
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.primary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsFill.envelopeOpen, size: 28, color: PilooColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.officineNom,
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${inv.invitedByName} · ${_roleLabel(inv.role)}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _accepting ? null : _onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _accepting ? PilooColors.primarySoft : PilooColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _accepting ? '…' : 'Accepter',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _accepting ? PilooColors.primary : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

