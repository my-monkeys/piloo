// Écran O3 Permissions caméra + notifs (#68).
// Maquette : `1kOHD` du fichier docs/design/piloo-mobile.pen.
//
// 3 cartes :
//  - Caméra (hard-required) : badge "Requis" $primary, border 2 $primary.
//    Tap → ask. Si granted, le badge passe à check-bold "Activé".
//    Si permanently denied, on propose un lien vers les paramètres OS.
//  - Notifications (optionnel) : switch. Toggle on → ask. Toggle off →
//    ne révoque pas l'OS (impossible programmatiquement) : on garde
//    juste le state local pour le UX d'onboarding.
//  - Contacts (optionnel) : switch également. Même logique.
//
// Boutons :
//  - "Terminer" : navigue vers /today. On ne bloque PAS sur la caméra
//    refusée à ce stade — on re-prompt à l'écran scan le moment venu.
//    Empêcher la sortie créerait un cul-de-sac UX (cf. AC #68 "lien
//    vers paramètres OS si refus permanent" implique qu'on permet
//    quand même de continuer).
//  - "Ignorer pour l'instant" : alias visuel, même destination /today.
//
// Permissions Android non câblées dans cet écran : la map plugin
// permission_handler unifie iOS/Android et `Permission.camera` /
// `Permission.notification` couvrent les deux. Les manifestes Android
// seront enrichis quand on commencera les tests sur ce target (#?).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_switch.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  PermissionStatus _camera = PermissionStatus.denied;
  PermissionStatus _notifications = PermissionStatus.denied;
  PermissionStatus _contacts = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final results = await Future.wait([
      Permission.camera.status,
      Permission.notification.status,
      Permission.contacts.status,
    ]);
    if (!mounted) return;
    setState(() {
      _camera = results[0];
      _notifications = results[1];
      _contacts = results[2];
    });
  }

  Future<void> _askCamera() async {
    if (_camera.isPermanentlyDenied) {
      await _openSettings();
      return;
    }
    final next = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _camera = next);
    if (next.isPermanentlyDenied) {
      PilooToast.info(
        context,
        "Active la caméra dans Réglages > Piloo pour scanner tes boîtes.",
      );
    }
  }

  Future<void> _toggleNotifications(bool desired) async {
    if (!desired) {
      // Impossible de révoquer programmatiquement — on reflète juste l'UX.
      setState(() => _notifications = PermissionStatus.denied);
      return;
    }
    if (_notifications.isPermanentlyDenied) {
      await _openSettings();
      return;
    }
    final next = await Permission.notification.request();
    if (!mounted) return;
    setState(() => _notifications = next);
  }

  Future<void> _toggleContacts(bool desired) async {
    if (!desired) {
      setState(() => _contacts = PermissionStatus.denied);
      return;
    }
    if (_contacts.isPermanentlyDenied) {
      await _openSettings();
      return;
    }
    final next = await Permission.contacts.request();
    if (!mounted) return;
    setState(() => _contacts = next);
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  void _finish() {
    // /today appartient à la ShellRoute : pushReplacement pour ne pas
    // empiler la coquille au-dessus de l'onboarding.
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutePath.today,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(children: [PilooCircleBackButton()]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(),
                    const SizedBox(height: 18),
                    _CameraCard(
                      status: _camera,
                      onTap: _askCamera,
                    ),
                    const SizedBox(height: 10),
                    _ToggleCard(
                      icon: PhosphorIconsFill.bellRinging,
                      iconColor: PilooColors.accent,
                      iconBgColor: PilooColors.accentSoft,
                      title: 'Notifications',
                      description: 'Rappels de prise et alertes péremption',
                      value: _notifications.isGranted,
                      onChanged: _toggleNotifications,
                    ),
                    const SizedBox(height: 10),
                    _ToggleCard(
                      icon: PhosphorIconsRegular.addressBook,
                      iconColor: PilooColors.textSecondary,
                      iconBgColor: PilooColors.surfaceSubtle,
                      title: 'Contacts (optionnel)',
                      description: 'Pour inviter tes proches plus facilement',
                      value: _contacts.isGranted,
                      onChanged: _toggleContacts,
                    ),
                    const SizedBox(height: 18),
                    _HelpBar(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: PilooButton(
                label: 'Terminer',
                variant: PilooButtonVariant.primary,
                onPressed: _finish,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _finish,
                child: Text(
                  "Ignorer pour l'instant",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textSecondary,
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

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quelques autorisations',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: PilooColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pour que Piloo fonctionne au mieux. Tu peux les changer plus tard dans les paramètres.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.status, required this.onTap});

  final PermissionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final granted = status.isGranted;
    // Border rouge 2px tant que non accordée (cohérent avec le badge),
    // vert primary 1px sinon. Padding ajusté pour garder une largeur
    // intérieure constante quand l'épaisseur du bord change.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(granted ? 14 : 13),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: Border.all(
            color: granted ? PilooColors.primary : PilooColors.accent,
            width: granted ? 1 : 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _IconTile(
              icon: PhosphorIconsFill.camera,
              iconColor: PilooColors.primary,
              bgColor: PilooColors.primarySoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caméra',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pour scanner le DataMatrix des boîtes',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusBadge(granted: granted),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    // Tant que la caméra n'est pas accordée, badge rouge ($accent) avec
    // icône warning : signal visuel fort que l'action est obligatoire.
    // Une fois accordée, badge vert ($primary) avec check.
    final color = granted ? PilooColors.primary : PilooColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted ? PhosphorIconsBold.check : PhosphorIconsBold.warning,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            granted ? 'Activé' : 'Requis',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _IconTile(icon: icon, iconColor: iconColor, bgColor: iconBgColor),
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
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PilooSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: iconColor),
    );
  }
}

class _HelpBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.lockKey,
            size: 16,
            color: PilooColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'On ne partage ces accès avec personne, jamais.',
              style: GoogleFonts.manrope(
                fontSize: 12,
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
