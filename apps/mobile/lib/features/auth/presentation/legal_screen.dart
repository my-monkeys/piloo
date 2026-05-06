// Écran O2 Mentions légales (#67).
// Maquette : `Orrca` du fichier docs/design/piloo-mobile.pen
//
// Reproduit fidèlement :
//  - Header back button
//  - Hero : cercle 80 $accent-soft + icône shield-check-fill 40 $accent
//  - "Avant de commencer" Fraunces 26 + sous-titre "Trois choses à
//    savoir sur Piloo."
//  - Card 3 points (radius-lg, $surface, stroke 1 $border) avec
//    séparateurs 1px :
//      1. carnet personnel (pas dispositif médical) — icône info $accent
//      2. données privées (no tracking) — icône lock-simple-fill $primary
//      3. export/suppression à tout moment — icône download-simple $success-fg
//  - 2 checkboxes obligatoires (CGU + Politique RGPD)
//  - Bouton "Accepter et continuer" — actif uniquement si les 2 boxes
//    sont cochées
//  - Liens "Lire en détail · CGU · Confidentialité"
//
// Tracking serveur du consentement : prévu par #67 mais nécessite un
// endpoint /api/v1/consent (pas encore défini). Pour le POC, le
// consentement est validé localement et on push /permissions. Quand
// l'endpoint existera, ajouter un POST /consent avec la version des
// CGU + horodatage avant de naviguer.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_checkbox.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  bool _cguAccepted = false;
  bool _privacyAccepted = false;

  bool get _canContinue => _cguAccepted && _privacyAccepted;

  void _onContinue() {
    if (!_canContinue) return;
    Navigator.of(context).pushReplacementNamed(RoutePath.permissions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 20),
                    _PointsCard(),
                    const SizedBox(height: 20),
                    _Checks(
                      cguAccepted: _cguAccepted,
                      privacyAccepted: _privacyAccepted,
                      onCgu: (v) => setState(() => _cguAccepted = v),
                      onPrivacy: (v) => setState(() => _privacyAccepted = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: PilooButton(
                label: 'Accepter et continuer',
                variant: PilooButtonVariant.primary,
                onPressed: _canContinue ? _onContinue : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _DetailLinks(),
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
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PilooColors.accentSoft,
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.shieldCheck,
              size: 40,
              color: PilooColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Avant de commencer',
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: PilooColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Trois choses à savoir sur Piloo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        children: [
          _Point(
            icon: PhosphorIconsRegular.info,
            iconColor: PilooColors.accent,
            iconBgColor: PilooColors.accentSoft,
            text:
                "Piloo est un carnet personnel, pas un dispositif médical. Il ne remplace pas ton médecin ou pharmacien.",
          ),
          const _Separator(),
          _Point(
            icon: PhosphorIconsFill.lockSimple,
            iconColor: PilooColors.primary,
            iconBgColor: PilooColors.primarySoft,
            text:
                "Tes données médicales restent privées. Aucune publicité, aucune revente, aucun tracking.",
          ),
          const _Separator(),
          _Point(
            icon: PhosphorIconsRegular.downloadSimple,
            iconColor: PilooColors.successOn,
            iconBgColor: PilooColors.success,
            text:
                "Tu peux exporter ou supprimer toutes tes infos à tout moment, depuis les paramètres.",
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textPrimary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: PilooColors.border);
  }
}

class _Checks extends StatelessWidget {
  const _Checks({
    required this.cguAccepted,
    required this.privacyAccepted,
    required this.onCgu,
    required this.onPrivacy,
  });

  final bool cguAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool> onCgu;
  final ValueChanged<bool> onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckRow(
          value: cguAccepted,
          onChanged: onCgu,
          label: "J'accepte les Conditions générales d'utilisation",
        ),
        const SizedBox(height: 12),
        _CheckRow(
          value: privacyAccepted,
          onChanged: onPrivacy,
          label: "J'accepte la Politique de confidentialité (RGPD)",
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PilooCheckbox(value: value, onChanged: onChanged, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final secondary = GoogleFonts.manrope(
      fontSize: 13,
      color: PilooColors.textSecondary,
    );
    final dot = GoogleFonts.manrope(
      fontSize: 13,
      color: PilooColors.textTertiary,
    );
    final link = GoogleFonts.manrope(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: PilooColors.primary,
    );

    // Wrap pour éviter l'overflow sur les viewports plus étroits
    // (split-screen, accessibilité grosse police).
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('Lire en détail', style: secondary),
        Text('·', style: dot),
        // No-op tant que les pages légales web (#173) ne sont pas
        // publiées. Quand elles existeront, lancer un in-app browser
        // (url_launcher) sur https://piloo.fr/cgu et /confidentialite.
        GestureDetector(
          onTap: () {/* #173 */},
          child: Text('CGU', style: link),
        ),
        Text('·', style: dot),
        GestureDetector(
          onTap: () {/* #173 */},
          child: Text('Confidentialité', style: link),
        ),
      ],
    );
  }
}
