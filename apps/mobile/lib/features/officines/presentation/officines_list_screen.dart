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
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

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
            _Header(onAdd: () {/* TODO #71 form création officine */}),
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
  });

  final _Officine officine;
  final bool active;
  final VoidCallback onTap;

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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: officine.iconBg,
                    borderRadius: BorderRadius.circular(PilooRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(officine.icon, size: 22, color: officine.iconColor),
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
                if (active)
                  const _ActiveBadge()
                else if (officine.alertCount != null)
                  _AlertBadge(count: officine.alertCount!),
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

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PilooColors.warning,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            PhosphorIconsFill.warning,
            size: 10,
            color: PilooColors.warningOn,
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: PilooColors.warningOn,
            ),
          ),
        ],
      ),
    );
  }
}
