// Écran S2 Gestion partages (#131).
// Maquette : `8dyxn` du fichier docs/design/piloo-mobile.pen.
//
// Permet à l'owner d'une officine de :
//  - voir la liste des membres (Owner / Éditeur / Lecteur / invité
//    en attente)
//  - changer le rôle d'un membre (dropdown sur le badge)
//  - retirer un membre (bottom sheet de confirmation)
//  - inviter quelqu'un (push S3 #133)
//
// L'owner ne peut pas se révoquer (pas de dropdown sur son badge).
// Pour la review on accepte juste les changements de rôle en local.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

enum _Role { proprietaire, editeur, lecteur }

class _Member {
  const _Member({
    required this.initials,
    required this.avatarColor,
    required this.name,
    required this.email,
    required this.role,
    this.invitationPending = false,
  });

  final String initials;
  final Color avatarColor;
  final String name;
  final String email;
  final _Role role;
  // Si vrai, le sous-titre (email) passe en warning et l'email est
  // suffixé par "· invitation en attente".
  final bool invitationPending;
}

class PartagesScreen extends StatefulWidget {
  const PartagesScreen({this.officineId, super.key});

  final String? officineId;

  @override
  State<PartagesScreen> createState() => _PartagesScreenState();
}

class _PartagesScreenState extends State<PartagesScreen> {
  // Données mockées — branchement Drift + API plus tard.
  late List<_Member> _members = const [
    _Member(
      initials: 'MD',
      avatarColor: PilooColors.primary,
      name: 'Maxime Durand (toi)',
      email: 'maxime@exemple.fr',
      role: _Role.proprietaire,
    ),
    _Member(
      initials: 'SL',
      avatarColor: PilooColors.accent,
      name: 'Sophie Laurent',
      email: 'sophie.l@exemple.fr',
      role: _Role.editeur,
    ),
    _Member(
      initials: 'PM',
      avatarColor: PilooColors.primarySoft,
      name: 'Paul Martin',
      email: 'paul.m@exemple.fr',
      role: _Role.lecteur,
      invitationPending: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(officineLabel: 'Maison'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Eyebrow(label: 'MEMBRES · ${_members.length}'),
                    const SizedBox(height: 8),
                    _MembersCard(
                      members: _members,
                      onRoleChange: (idx, role) => setState(() {
                        final m = _members[idx];
                        _members = [
                          ..._members.sublist(0, idx),
                          _Member(
                            initials: m.initials,
                            avatarColor: m.avatarColor,
                            name: m.name,
                            email: m.email,
                            role: role,
                            invitationPending: m.invitationPending,
                          ),
                          ..._members.sublist(idx + 1),
                        ];
                      }),
                    ),
                    const SizedBox(height: 16),
                    _RolesHelp(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PilooButton(
                label: '+ Inviter quelqu\'un',
                variant: PilooButtonVariant.primary,
                // Push placeholder — S3 Inviter quelqu'un = #133.
                onPressed: () {/* TODO push /officines/:id/invite */},
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  const _MembersCard({required this.members, required this.onRoleChange});

  final List<_Member> members;
  final void Function(int index, _Role newRole) onRoleChange;

  @override
  Widget build(BuildContext context) {
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
          );
        }),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onRoleChange});

  final _Member member;
  final ValueChanged<_Role> onRoleChange;

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == _Role.proprietaire;
    final emailColor = member.invitationPending
        ? PilooColors.warningOn
        : PilooColors.textTertiary;

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
                  member.invitationPending
                      ? '${member.email} · invitation en attente'
                      : member.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: emailColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RoleBadge(
            role: member.role,
            // Owner : badge fixe sans dropdown (un owner ne peut pas
            // se révoquer ni se changer en éditeur — il faut transférer
            // d'abord la propriété).
            onChange: isOwner ? null : onRoleChange,
          ),
        ],
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
    // Si le fond est clair (primary-soft pour Paul mock), on rend le
    // texte en primary plutôt qu'en blanc pour rester lisible.
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
  // Si null → badge fixe (cas owner).
  final ValueChanged<_Role>? onChange;
  // Override du fond pour contextes spéciaux (ex: card LES RÔLES en
  // \$surface-subtle où le badge Lecteur disparaîtrait sinon).
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
              for (final r in [_Role.editeur, _Role.lecteur])
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
                                _Role.editeur => 'Éditeur',
                                _Role.lecteur => 'Lecteur',
                                _Role.proprietaire => 'Propriétaire',
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
  // Une ligne par rôle, chaque rôle dans le même badge coloré que celui
  // utilisé sur les rows membres pour que le mapping visuel soit
  // immédiat.
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
        // Badge fixe (sans dropdown) — réutilise la même mécanique de
        // style que les badges des rows membres. On force le bg blanc
        // pour le Lecteur sinon il se confond avec la card help (qui
        // est en \$surface-subtle, comme la couleur native du badge).
        _RoleBadge(
          role: role,
          onChange: null,
          bgOverride:
              role == _Role.lecteur ? PilooColors.surface : null,
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
