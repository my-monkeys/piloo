// Écran S3 Inviter quelqu'un (#133).
// Maquette : `uhKGM` du fichier docs/design/piloo-mobile.pen.
//
// Form pour ajouter un membre à une officine :
//  - email du destinataire
//  - choix du rôle (Propriétaire / Éditeur / Lecteur) en cards radio
//  - rappel "le lien expire dans 72 h"
//  - bouton "Envoyer l'invitation"
//
// POST /officines/:id/invitations câblé via piloo_api_client. Le
// serveur génère le token + envoie l'email Brevo (best-effort) au
// destinataire avec un lien d'acceptation.
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
import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

enum _InviteRole { proprietaire, editeur, lecteur }

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({this.officineId, super.key});

  final String? officineId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _emailCtrl = TextEditingController();
  _InviteRole _role = _InviteRole.editeur;
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  static const _emailRegex =
      r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$";

  /// Résout l'officine cible. Le router peut passer `officineId='maison'`
  /// comme placeholder quand l'écran s'ouvre depuis Plus → Partages sans
  /// avoir d'officine encore sélectionnée — dans ce cas on fallback sur
  /// l'officine active du user.
  String? _resolveOfficineId() {
    final fromRoute = widget.officineId;
    if (fromRoute != null && fromRoute.length == 36) return fromRoute;
    return ref.read(activeOfficineProvider).valueOrNull?.id;
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(_emailRegex).hasMatch(email)) {
      PilooToast.error(context, 'Email invalide.');
      return;
    }
    final officineId = _resolveOfficineId();
    if (officineId == null) {
      PilooToast.error(context, 'Aucune officine sélectionnée.');
      return;
    }
    setState(() => _sending = true);
    try {
      final client = ref.read(pilooApiClientProvider).getInvitationsApi();
      final builder = api.CreateInvitationInputBuilder()
        ..email = email
        ..role = _toWireRole(_role);
      final res = await client.v1OfficinesOfficineIdInvitationsPost(
        officineId: officineId,
        createInvitationInput: builder.build(),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception('Statut ${res.statusCode}');
      }
      if (!mounted) return;
      PilooToast.success(context, "Invitation envoyée à $email.");
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          context.canPop() ? context.pop() : context.go(RoutePath.today);
        }
      });
    } catch (e) {
      if (mounted) PilooToast.error(context, "Échec de l'envoi : $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  api.CreateInvitationInputRoleEnum _toWireRole(_InviteRole r) {
    return switch (r) {
      _InviteRole.proprietaire => api.CreateInvitationInputRoleEnum.owner,
      _InviteRole.editeur => api.CreateInvitationInputRoleEnum.editor,
      _InviteRole.lecteur => api.CreateInvitationInputRoleEnum.viewer,
    };
  }

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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ContextBanner(officineLabel: 'Maison'),
                    const SizedBox(height: 18),
                    _EmailField(controller: _emailCtrl),
                    const SizedBox(height: 18),
                    _RoleSelector(
                      value: _role,
                      onChange: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 14),
                    _ExpiryHelp(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PilooButton(
                label: "Envoyer l'invitation",
                variant: PilooButtonVariant.primary,
                onPressed: _send,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Flexible(
            child: Text(
              'Inviter',
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

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.officineLabel});

  final String officineLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PilooColors.primarySoft,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.house,
            size: 18,
            color: PilooColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Inviter quelqu'un à rejoindre $officineLabel",
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PilooColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EMAIL DE LA PERSONNE',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border: Border.all(color: PilooColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                PhosphorIconsRegular.envelope,
                size: 16,
                color: PilooColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: 'sylvie.d@exemple.fr',
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 14,
                      color: PilooColors.textTertiary,
                    ),
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: PilooColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChange});

  final _InviteRole value;
  final ValueChanged<_InviteRole> onChange;

  static const _entries = [
    (
      role: _InviteRole.proprietaire,
      title: 'Propriétaire',
      desc: 'Tous les droits, y compris gérer les partages',
    ),
    (
      role: _InviteRole.editeur,
      title: 'Éditeur',
      desc: 'Modifier boîtes, ordonnances, prises',
    ),
    (
      role: _InviteRole.lecteur,
      title: 'Lecteur',
      desc: 'Consulter + signaler un manque. Pas de modification.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RÔLE',
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
          _RoleCard(
            title: _entries[i].title,
            description: _entries[i].desc,
            selected: value == _entries[i].role,
            onTap: () => onChange(_entries[i].role),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Padding 11 quand bord 2px, 12 quand 1px (inner width
        // constant pour ne pas relayouter le texte au switch).
        padding: EdgeInsets.all(selected ? 11 : 12),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(
            color: selected ? PilooColors.primary : PilooColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Radio(selected: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: PilooColors.textSecondary,
                      height: 1.4,
                    ),
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

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? PilooColors.primary : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: PilooColors.border, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class _ExpiryHelp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          PhosphorIconsRegular.clock,
          size: 14,
          color: PilooColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            "Le lien d'invitation expire dans 72 h",
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: PilooColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
