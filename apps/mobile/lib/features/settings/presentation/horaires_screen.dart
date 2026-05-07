// Horaires par défaut matin/midi/soir/coucher (#156).
//
// Pas de maquette dédiée — design dans la cohérence du reste : header
// back, 4 cards (1 par moment) avec icône typée + heure cliquable.
// Tap sur l'heure → showTimePicker natif. Helper en bas qui rappelle
// que changer les horaires régénère les prises planifiées affectées
// (logique côté worker sync, pas dans cet écran).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class HorairesScreen extends StatefulWidget {
  const HorairesScreen({super.key});

  @override
  State<HorairesScreen> createState() => _HorairesScreenState();
}

class _HorairesScreenState extends State<HorairesScreen> {
  // Valeurs par défaut. Seront remplacées par le profil serveur
  // quand les préférences user seront câblées.
  TimeOfDay _matin = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _midi = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _soir = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _coucher = const TimeOfDay(hour: 22, minute: 0);

  Future<void> _pick(TimeOfDay current, ValueChanged<TimeOfDay> onSet) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onSet(picked);
  }

  void _save() {
    PilooToast.success(context, 'Horaires mis à jour.');
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).maybePop();
    });
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
                    _IntroText(),
                    const SizedBox(height: 16),
                    _MomentRow(
                      icon: PhosphorIconsFill.sunHorizon,
                      iconColor: PilooColors.accent,
                      iconBg: PilooColors.accentSoft,
                      label: 'Matin',
                      time: _matin,
                      onTap: () =>
                          _pick(_matin, (t) => setState(() => _matin = t)),
                    ),
                    const SizedBox(height: 10),
                    _MomentRow(
                      icon: PhosphorIconsFill.sun,
                      iconColor: PilooColors.warningOn,
                      iconBg: PilooColors.warning,
                      label: 'Midi',
                      time: _midi,
                      onTap: () =>
                          _pick(_midi, (t) => setState(() => _midi = t)),
                    ),
                    const SizedBox(height: 10),
                    _MomentRow(
                      icon: PhosphorIconsFill.moon,
                      iconColor: PilooColors.primary,
                      iconBg: PilooColors.primarySoft,
                      label: 'Soir',
                      time: _soir,
                      onTap: () =>
                          _pick(_soir, (t) => setState(() => _soir = t)),
                    ),
                    const SizedBox(height: 10),
                    _MomentRow(
                      icon: PhosphorIconsFill.moonStars,
                      iconColor: PilooColors.infoOn,
                      iconBg: PilooColors.info,
                      label: 'Coucher',
                      time: _coucher,
                      onTap: () => _pick(
                        _coucher,
                        (t) => setState(() => _coucher = t),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _RegenerateNotice(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PilooButton(
                label: 'Enregistrer',
                variant: PilooButtonVariant.primary,
                onPressed: _save,
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
              'Horaires par défaut',
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

class _IntroText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Heures par défaut utilisées pour planifier tes prises quand '
      'une ordonnance précise un moment (matin, midi, soir, coucher) '
      'sans heure exacte.',
      style: GoogleFonts.manrope(
        fontSize: 13,
        color: PilooColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  String get _formatted {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: PilooColors.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatted,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PilooColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    PhosphorIconsRegular.caretDown,
                    size: 12,
                    color: PilooColors.primary,
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

class _RegenerateNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PilooColors.info,
        borderRadius: BorderRadius.circular(PilooRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsFill.info,
            size: 16,
            color: PilooColors.infoOn,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modifier ces horaires recalcule les prises à venir qui '
              'utilisent les moments par défaut. Les prises déjà '
              'validées ne sont pas affectées.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.infoOn,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
