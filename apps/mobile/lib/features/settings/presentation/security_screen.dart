// Sécurité 2FA TOTP (#157).
//
// Pas de maquette dédiée — design en 2 états :
//
//  1) 2FA désactivée : hero shield-warning ambre + explication +
//     bouton "Activer la double authentification". Push une étape
//     interne qui montre un QR code + champ code 6 chiffres.
//
//  2) 2FA activée : hero shield-check vert + statut + 2 actions :
//     "Voir mes codes de secours" et "Désactiver".
//
// Le QR + secret TOTP seront servis par /api/v1/auth/2fa/setup.
// Pour la review, état piloté par un toggle local.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _twoFAEnabled = false;

  Future<void> _activate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _ActivateFlow()),
    );
    if (ok == true && mounted) {
      setState(() => _twoFAEnabled = true);
      PilooToast.success(context, 'Double authentification activée.');
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Désactiver la 2FA ?'),
        content: const Text(
          "Tu pourras te connecter sans code, mais ton compte "
          'sera moins protégé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Désactiver',
              style: GoogleFonts.manrope(color: PilooColors.errorOn),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _twoFAEnabled = false);
      PilooToast.info(context, 'Double authentification désactivée.');
    }
  }

  void _showBackupCodes() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PilooColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BackupCodesSheet(),
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
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _twoFAEnabled
                    ? _EnabledView(
                        onShowCodes: _showBackupCodes,
                        onDeactivate: _deactivate,
                      )
                    : _DisabledView(onActivate: _activate),
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
              'Sécurité',
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

class _DisabledView extends StatelessWidget {
  const _DisabledView({required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PilooColors.warning,
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.shieldWarning,
              size: 40,
              color: PilooColors.warningOn,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Double authentification désactivée',
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Ajoute une étape de vérification à chaque connexion en '
          'plus de ton mot de passe. Recommandé pour les comptes pro '
          'qui suivent plusieurs patients.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _BulletList(
          items: const [
            'Compatible avec Google Authenticator, Authy, 1Password…',
            'Codes de secours générés automatiquement',
            'Désactivable à tout moment',
          ],
        ),
        const SizedBox(height: 24),
        PilooButton(
          label: 'Activer la double authentification',
          variant: PilooButtonVariant.primary,
          onPressed: onActivate,
        ),
      ],
    );
  }
}

class _EnabledView extends StatelessWidget {
  const _EnabledView({
    required this.onShowCodes,
    required this.onDeactivate,
  });

  final VoidCallback onShowCodes;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PilooColors.success,
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.shieldCheck,
              size: 40,
              color: PilooColors.successOn,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Double authentification active',
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Un code à 6 chiffres te sera demandé à chaque connexion '
          'sur un nouvel appareil.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _ActionTile(
          icon: PhosphorIconsRegular.key,
          iconColor: PilooColors.primary,
          iconBg: PilooColors.primarySoft,
          title: 'Codes de secours',
          subtitle: 'Voir tes codes de secours à usage unique',
          onTap: onShowCodes,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: PhosphorIconsRegular.shieldSlash,
          iconColor: PilooColors.errorOn,
          iconBg: PilooColors.error,
          title: 'Désactiver la 2FA',
          subtitle: 'Reviens à une connexion par mot de passe seul',
          onTap: onDeactivate,
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

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
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 16,
                  color: PilooColors.successOn,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
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
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: PilooColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Flow d'activation (page poussée)
// ============================================================================

class _ActivateFlow extends StatefulWidget {
  const _ActivateFlow();

  @override
  State<_ActivateFlow> createState() => _ActivateFlowState();
}

class _ActivateFlowState extends State<_ActivateFlow> {
  final _codeCtrl = TextEditingController();

  // Secret mocké pour le placeholder QR. Réel = servi par
  // /api/v1/auth/2fa/setup.
  static const _mockSecret = 'JBSWY3DPEHPK3PXP';

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _verify() {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      PilooToast.error(context, 'Le code doit contenir 6 chiffres.');
      return;
    }
    // Vraie vérification côté serveur — pour le POC, on accepte
    // n'importe quel 6 chiffres.
    Navigator.of(context).pop(true);
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '1. Scanne ce QR code',
                      style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Avec Google Authenticator, Authy, 1Password ou '
                      'toute app TOTP compatible.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: PilooColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _QrPlaceholder(),
                    const SizedBox(height: 14),
                    _SecretCopy(secret: _mockSecret),
                    const SizedBox(height: 24),
                    Text(
                      '2. Entre le code à 6 chiffres',
                      style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Le code change toutes les 30 secondes.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CodeField(controller: _codeCtrl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PilooButton(
                label: 'Vérifier et activer',
                variant: PilooButtonVariant.primary,
                onPressed: _verify,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Vrai QR code : à générer côté serveur ou via un package
    // (qr_flutter). Pour l'instant on rend un placeholder visuel
    // sympa qui suggère un QR sans en être un.
    return Center(
      child: Container(
        width: 200,
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: Border.all(color: PilooColors.border),
        ),
        child: GridView.count(
          crossAxisCount: 12,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(144, (i) {
            // Pattern pseudo-aléatoire stable basé sur l'index +
            // 3 grosses ancres de coin classiques d'un QR.
            final r = i ~/ 12;
            final c = i % 12;
            bool corner(int rs, int cs) =>
                r >= rs && r < rs + 3 && c >= cs && c < cs + 3;
            final isCorner =
                corner(0, 0) || corner(0, 9) || corner(9, 0);
            final filled = isCorner || (i * 7 + 3) % 5 < 2;
            return Container(
              color: filled ? Colors.black : Colors.transparent,
            );
          }),
        ),
      ),
    );
  }
}

class _SecretCopy extends StatelessWidget {
  const _SecretCopy({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ou saisie manuelle',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: PilooColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secret,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: PilooColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // TODO Clipboard.setData quand on aura besoin de copier
              // pour de vrai. Pour le POC : juste un toast.
              PilooToast.info(context, 'Copié dans le presse-papier.');
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                PhosphorIconsRegular.copy,
                size: 18,
                color: PilooColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          hintText: '000 000',
          hintStyle: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 6,
            color: PilooColors.textTertiary,
          ),
        ),
        style: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 6,
          color: PilooColors.textPrimary,
        ),
      ),
    );
  }
}

// ============================================================================
// Sheet codes de secours
// ============================================================================

class _BackupCodesSheet extends StatelessWidget {
  const _BackupCodesSheet();

  // Mocks — sera servi par l'API.
  static const _codes = [
    'a1b2-c3d4', 'e5f6-g7h8', 'i9j0-k1l2', 'm3n4-o5p6',
    'q7r8-s9t0', 'u1v2-w3x4', 'y5z6-a7b8', 'c9d0-e1f2',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: PilooColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Codes de secours',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Garde ces codes en lieu sûr. Chacun ne peut être '
              'utilisé qu\'une seule fois si tu perds l\'accès à '
              'ton app TOTP.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PilooColors.surface,
                borderRadius: BorderRadius.circular(PilooRadius.md),
                border: Border.all(color: PilooColors.border),
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 12,
                children: [
                  for (final c in _codes)
                    Text(
                      c,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PilooButton(
              label: 'Fermer',
              variant: PilooButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
