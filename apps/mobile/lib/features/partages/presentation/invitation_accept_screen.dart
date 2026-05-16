// Écran S4 Accepter invitation (#135).
// Maquette : `M8kbS` du fichier docs/design/piloo-mobile.pen.
//
// Atterrissage depuis un lien d'invitation (deeplink
// `/invitations/:token`). Affiche un aperçu :
//  - qui invite (avatar initiales + nom)
//  - quelle officine
//  - rôle proposé
//  - les 3 droits que ce rôle confère (check vert) + 1 limitation
//    (x-circle gris)
//  - actions Accepter (primary) / Refuser (outline)
//
// Refuser → l'invitation est marquée invalide côté serveur (le lien
// ne fonctionnera plus). Accepter → ajoute l'utilisateur à
// l'officine puis push vers /today (ou /welcome si user pas connecté).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';

class InvitationAcceptScreen extends StatelessWidget {
  const InvitationAcceptScreen({this.token, super.key});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClose: () => context.canPop() ? context.pop() : context.go(RoutePath.today)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      initials: 'SL',
                      inviterName: 'Sophie Laurent',
                      officineName: 'Maison',
                    ),
                    const SizedBox(height: 18),
                    _OfficineCard(),
                    const SizedBox(height: 14),
                    Center(child: _RoleBadge()),
                    const SizedBox(height: 18),
                    _CanDoList(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  PilooButton(
                    label: "Accepter l'invitation",
                    variant: PilooButtonVariant.primary,
                    onPressed: () {/* TODO POST /invitations/:token/accept */},
                  ),
                  const SizedBox(height: 8),
                  PilooButton(
                    label: 'Refuser',
                    variant: PilooButtonVariant.outline,
                    onPressed: () => context.canPop() ? context.pop() : context.go(RoutePath.today),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _OfficineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.primarySoft,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.house,
              size: 22,
              color: PilooColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Officine familiale',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '12 boîtes · 2 autres membres',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PilooColors.info,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            PhosphorIconsRegular.pencilSimple,
            size: 14,
            color: PilooColors.infoOn,
          ),
          const SizedBox(width: 6),
          Text(
            "En tant qu'Éditeur",
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

class _CanDoList extends StatelessWidget {
  static const _entries = [
    (
      icon: PhosphorIconsFill.checkCircle,
      iconColor: PilooColors.successOn,
      text: 'Voir et modifier les boîtes de Maison',
      textColor: PilooColors.textPrimary,
    ),
    (
      icon: PhosphorIconsFill.checkCircle,
      iconColor: PilooColors.successOn,
      text: 'Gérer les ordonnances et valider les prises',
      textColor: PilooColors.textPrimary,
    ),
    (
      icon: PhosphorIconsFill.xCircle,
      iconColor: PilooColors.textTertiary,
      text: 'Pas de gestion des partages (réservé au Propriétaire)',
      textColor: PilooColors.textSecondary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TU POURRAS',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_entries[i].icon, size: 16, color: _entries[i].iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _entries[i].text,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: _entries[i].textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
