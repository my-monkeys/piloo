// Écran O1 Welcome — carousel 3 slides (#66).
// Maquette : `oU3Xt` (slide 1) du fichier docs/design/piloo-mobile.pen.
//
// La maquette ne couvre QUE la slide 1 ("Scanne, c'est tout"). Les
// slides 2 et 3 réutilisent le même template (hero gradient + icône
// circle + titre Fraunces 32 + sous-titre Manrope 15) avec un contenu
// dérivé de docs/ui-ux-guidelines.md §"Welcome screens" :
//   1. Scanner ses médicaments
//   2. Suivre ses prises
//   3. Partager avec ses proches
//
// Si le design impose des variations par slide (couleur du hero, icône
// précise, copywriting), une nouvelle passe Pencil pour les slides 2
// et 3 raffinera le visuel.
//
// UX
//  - Swipe horizontal entre les 3 slides (PageView).
//  - Dots loader en bas : pill 24×8 $primary pour l'active, cercles 8
//    $border pour les autres.
//  - "Passer" en haut-droite ($text-secondary 14/600) : skip → /account-type.
//  - "Suivant" en bas (primaire) : avance d'une slide. Sur la dernière
//    slide, label devient "Commencer" et push /account-type.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
}

const _slides = <_WelcomeSlide>[
  _WelcomeSlide(
    icon: PhosphorIconsRegular.scan,
    title: "Scanne, c'est tout",
    subtitle:
        'Le DataMatrix au dos de ta boîte suffit. Péremption, lot, stock : tout est rempli automatiquement.',
  ),
  _WelcomeSlide(
    icon: PhosphorIconsRegular.bell,
    title: 'Ne rate plus une prise',
    subtitle:
        "Une timeline claire, des rappels au bon moment, et l'historique de chaque dose validée.",
  ),
  _WelcomeSlide(
    icon: PhosphorIconsRegular.users,
    title: 'Avec tes proches',
    subtitle:
        'Partage une officine avec ta famille ou tes patients. Chacun voit ce qu\'il doit voir, à son rythme.',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _currentIndex >= _slides.length - 1;

  void _onSkip() {
    Navigator.of(context).pushReplacementNamed(RoutePath.accountType);
  }

  void _onNext() {
    if (_isLast) {
      _onSkip();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onSkip: _onSkip),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                children: [
                  _Dots(count: _slides.length, activeIndex: _currentIndex),
                  const SizedBox(height: 16),
                  PilooButton(
                    label: _isLast ? 'Commencer' : 'Suivant',
                    variant: PilooButtonVariant.primary,
                    onPressed: _onNext,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSkip,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                'Passer',
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
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _WelcomeSlide slide;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView pour absorber les petits viewports (tests,
    // appareils en split-screen, accessibilité grosse police). Sur un
    // iPhone classique, le contenu tient sans scroll.
    return SingleChildScrollView(
      child: Column(
        children: [
          const _HeroGradient(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: PilooColors.textSecondary,
                    height: 1.5,
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

class _HeroGradient extends StatelessWidget {
  const _HeroGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // 135° → top-left → bottom-right.
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PilooColors.primarySoft, PilooColors.accentSoft],
        ),
      ),
      alignment: Alignment.center,
      child: Builder(
        builder: (context) {
          // Récupère l'index courant via PageView pour piloter l'icône
          // affichée dans le hero. Le SlideView est buildé pour chaque
          // page mais le hero a l'air "constant" — pour avoir l'icône
          // qui change par slide, on doit l'injecter par slide.
          final ancestor =
              context.findAncestorWidgetOfExactType<_SlideView>();
          final icon = ancestor?.slide.icon ?? PhosphorIconsRegular.scan;
          return _HeroBadge(icon: icon);
        },
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PilooColors.surface,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF252A30).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 76, color: PilooColors.accent),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: i == activeIndex ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? PilooColors.primary
                  : PilooColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}
