// Écran A2 Choix type compte (#59).
// Maquette : `pXfBS` du fichier docs/design/piloo-mobile.pen
//
// Reproduit fidèlement :
//  - Header avec back button
//  - Titre "Tu utilises Piloo pour…" Fraunces 26 + sous-titre Manrope 14
//  - 2 cards radius-lg : Particulier (icône house-fill + primary-soft)
//    / Pro de santé (icône first-aid + surface-subtle).
//    Card sélectionnée : stroke 2 $primary + check rempli.
//    Card non-sélectionnée : stroke 1 $border + check vide.
//  - Bouton "Continuer" en bas, qui pousse `/sign-up` avec
//    `extra: typeCompte` (le SignUpScreen lit déjà state.extra).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  // Particulier sélectionné par défaut (cible 80% des users selon
  // docs/dossier-cadrage.md).
  String _selected = 'particulier';

  void _select(String value) => setState(() => _selected = value);

  void _onContinue() {
    Navigator.of(context).pushNamed(RoutePath.signUp, arguments: _selected);
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tu utilises Piloo pour…',
                      style: GoogleFonts.fraunces(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choisis le type de compte qui te correspond. Tu pourras le modifier plus tard.',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: PilooColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AccountTypeCard(
                      selected: _selected == 'particulier',
                      onTap: () => _select('particulier'),
                      icon: PhosphorIconsFill.house,
                      title: 'Particulier',
                      description: 'Mon officine familiale et celle de mes proches',
                    ),
                    const SizedBox(height: 16),
                    _AccountTypeCard(
                      selected: _selected == 'pro',
                      onTap: () => _select('pro'),
                      icon: PhosphorIconsRegular.firstAid,
                      title: 'Pro de santé',
                      description: 'IDEL, aide-soignant, aidant à domicile, SSIAD',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PilooButton(
                label: 'Continuer',
                variant: PilooButtonVariant.primary,
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.description,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final iconBoxColor =
        selected ? PilooColors.primarySoft : PilooColors.surfaceSubtle;
    final iconColor = selected ? PilooColors.primary : PilooColors.textSecondary;

    return Material(
      color: PilooColors.surface,
      borderRadius: BorderRadius.circular(PilooRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        onTap: onTap,
        child: Container(
          // Border passe de 1 à 2px à la sélection : on compense le
          // padding interne (15 → 16) pour que la zone de contenu garde
          // la même largeur, sinon les longs descriptifs ("Mon officine
          // familiale et celle de mes proches") rewrappent au moment de
          // la sélection — saut visuel disgracieux.
          padding: EdgeInsets.all(selected ? 15 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(
              color: selected ? PilooColors.primary : PilooColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBoxColor,
                  borderRadius: BorderRadius.circular(PilooRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 14),
              _RadioCircle(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioCircle extends StatelessWidget {
  const _RadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? PilooColors.primary : Colors.transparent,
        border: selected ? null : Border.all(color: PilooColors.border, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(
              PhosphorIconsBold.check,
              size: 12,
              color: PilooColors.textOnPrimary,
            )
          : null,
    );
  }
}
