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
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
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
    this.roleSubtitle,
    this.alertCount,
  });

  final String id;
  final String name;
  final String meta;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final _OfficineRole role;
  // ex: "2 personnes" ou "partagée par Marie D."
  final String? roleSubtitle;
  // Badge alerte ambre quand >0 (ex: officine d'un proche avec
  // notifications non lues).
  final int? alertCount;
}

class OfficinesListScreen extends StatefulWidget {
  const OfficinesListScreen({super.key});

  @override
  State<OfficinesListScreen> createState() => _OfficinesListScreenState();
}

class _OfficinesListScreenState extends State<OfficinesListScreen> {
  String _activeId = 'maison';

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

  static const _officines = [
    _Officine(
      id: 'maison',
      name: 'Maison',
      meta: "12 boîtes · 5 prises prévues aujourd'hui",
      icon: PhosphorIconsFill.house,
      iconColor: PilooColors.primary,
      iconBg: PilooColors.primarySoft,
      role: _OfficineRole.proprietaire,
      roleSubtitle: '2 personnes',
    ),
    _Officine(
      id: 'papa',
      name: 'Papa',
      meta: "8 boîtes · 3 prises aujourd'hui",
      icon: PhosphorIconsFill.heart,
      iconColor: PilooColors.accent,
      iconBg: PilooColors.accentSoft,
      role: _OfficineRole.editeur,
      roleSubtitle: 'partagée par Marie D.',
      alertCount: 1,
    ),
    _Officine(
      id: 'mme-dubois',
      name: 'Mme Dubois',
      meta: '23 boîtes · patient IDEL',
      icon: PhosphorIconsFill.userCircle,
      iconColor: PilooColors.textSecondary,
      iconBg: PilooColors.surfaceSubtle,
      role: _OfficineRole.proprietaire,
      roleSubtitle: '3 personnes',
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
            _Header(onAdd: () async {
              final draft = await showOfficineEditSheet(context);
              if (draft != null && context.mounted) {
                PilooToast.success(
                  context,
                  'Officine "${draft.name}" créée.',
                );
              }
            }),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _officines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final o = _officines[i];
                  return _OfficineCard(
                    officine: o,
                    active: o.id == _activeId,
                    onTap: () => setState(() => _activeId = o.id),
                    onLongPress: () => _showActions(context, o),
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
    required this.onLongPress,
  });

  final _Officine officine;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
      onLongPress: onLongPress,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tile icône + (éventuel) point d'alerte en overlay
                // top-right : déplacé là pour ne pas être écrasé par
                // le badge "Actif" qui apparaît à droite.
                Stack(
                  clipBehavior: Clip.none,
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
                    if (officine.alertCount != null)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: _AlertDot(count: officine.alertCount!),
                      ),
                  ],
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
                // Slot fixe pour le badge "Actif" : on réserve la
                // largeur même quand inactif pour que le meta text
                // ne se relayoute pas en passant active → inactive.
                // 80px = check 10 + gap 4 + texte "Actif" + padding
                // 10×2 + marge sécurité fonts (en tests, google_fonts
                // tombe sur une fonte plus large).
                SizedBox(
                  width: 88,
                  child: active
                      ? const Align(
                          alignment: Alignment.centerRight,
                          child: _ActiveBadge(),
                        )
                      : null,
                ),
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
                if (officine.roleSubtitle != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '· ${officine.roleSubtitle!}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: PilooColors.textTertiary,
                      ),
                    ),
                  ),
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

/// Pastille de notification overlay sur le coin haut-droit de la
/// tile icône (style badge iOS). Bord blanc épais pour bien la
/// détacher du tile derrière.
class _AlertDot extends StatelessWidget {
  const _AlertDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: PilooColors.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PilooColors.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}
