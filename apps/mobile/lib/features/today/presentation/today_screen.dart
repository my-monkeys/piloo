// Écran 02 Aujourd'hui (#115). Maquette `ZNRR8`.
//
// Vue principale après onboarding : timeline des prises du jour
// regroupées en 4 sections (Matin/Midi/Soir/Coucher). Pour cette
// première itération, données mockées en local — la connexion à
// la DB locale (Drift) + sync arrive avec les tickets timeline
// (#14 epic).
//
// Statuts de prise rendus :
//  - prise   : cercle plein vert $success + check
//  - à venir : cercle vide bord $border
//  - oubliée : cercle plein $warning-on + warning-fill, et la card
//    elle-même passe en fond $warning + bord $warning-on (signal fort
//    qu'une action est attendue)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/today/data/prises_provider.dart';
import 'package:piloo/features/today/presentation/prise_actions_sheet.dart';
import 'package:piloo/shared/widgets/piloo_day_picker.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

enum PriseStatus { taken, upcoming, missed, skipped }

class _Prise {
  const _Prise({
    required this.name,
    required this.meta,
    required this.timeOrLabel,
    required this.status,
    this.apiPrise,
  });

  final String name;
  final String? meta;
  final String timeOrLabel;
  final PriseStatus status;
  /// Référence API pour pouvoir mutate via PATCH /v1/prises/{id} au tap.
  /// Null quand on est sur le fallback mock (pas de session / pas
  /// d'officine active / chargement).
  final api.PriseTimelineItem? apiPrise;
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  DateTime _date = DateTime.now();

  // Bornes navigation (#116) :
  // - passé = -365j (proxy de "depuis l'inscription" tant qu'on
  //   n'expose pas createdAt côté API)
  // - futur = +30j (matche WINDOW_DAYS du cron generation-glissante)
  static const _maxPastDays = 365;
  static const _maxFutureDays = 30;

  void _shiftDay(int delta) {
    final next = _date.add(Duration(days: delta));
    if (!_isWithinBounds(next)) return;
    setState(() => _date = next);
  }

  bool _isWithinBounds(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final delta = target.difference(today).inDays;
    return delta >= -_maxPastDays && delta <= _maxFutureDays;
  }

  bool get _canGoPrev => _isWithinBounds(_date.subtract(const Duration(days: 1)));
  bool get _canGoNext => _isWithinBounds(_date.add(const Duration(days: 1)));

  // Mock fallback affiché quand on n'a pas de données API (offline /
  // pas d'officine active / loading initial). Permet une démo visuelle
  // immédiate au cold start.
  static const _mockMatin = [
    _Prise(
      name: 'Doliprane 1000 mg',
      meta: '1 comprimé',
      timeOrLabel: '8:00',
      status: PriseStatus.upcoming,
    ),
  ];
  static const _mockMidi = <_Prise>[];
  static const _mockSoir = <_Prise>[];
  static const _mockCoucher = <_Prise>[];

  ({
    List<_Prise> matin,
    List<_Prise> midi,
    List<_Prise> soir,
    List<_Prise> coucher,
  }) _groupByMoment(List<api.PriseTimelineItem> items) {
    final matin = <_Prise>[];
    final midi = <_Prise>[];
    final soir = <_Prise>[];
    final coucher = <_Prise>[];
    final sorted = [...items]
      ..sort((a, b) => a.datetimePrevue.compareTo(b.datetimePrevue));
    for (final p in sorted) {
      final local = p.datetimePrevue.toLocal();
      final m = _mapApiPrise(p, local);
      final bucket = switch (local.hour) {
        < 12 => matin,
        < 16 => midi,
        < 21 => soir,
        _ => coucher,
      };
      bucket.add(m);
    }
    return (matin: matin, midi: midi, soir: soir, coucher: coucher);
  }

  _Prise _mapApiPrise(api.PriseTimelineItem p, DateTime local) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final status = switch (p.statut) {
      api.PriseTimelineItemStatutEnum.prise => PriseStatus.taken,
      api.PriseTimelineItemStatutEnum.sautee => PriseStatus.skipped,
      api.PriseTimelineItemStatutEnum.oubliee => PriseStatus.missed,
      _ => PriseStatus.upcoming,
    };
    final timeLabel = status == PriseStatus.missed ? 'Oubliée' : '$hh:$mm';
    return _Prise(
      name: p.prescription.nomTexte,
      meta: _posologyLine(p.prescription),
      timeOrLabel: timeLabel,
      status: status,
      apiPrise: p,
    );
  }

  String? _posologyLine(api.PriseTimelinePrescription prescription) {
    // Posologie est un BuiltMap<String, JsonObject?> ; on extrait
    // unitesParPrise + unite pour la ligne meta. Si absent, retombe
    // sur l'indication.
    final raw = prescription.posologie;
    final units = raw['unitesParPrise']?.value;
    final unite = raw['unite']?.value;
    final avecRepas = raw['avecRepas']?.value == true;
    final parts = <String>[];
    if (units != null && unite is String) {
      parts.add('${units.toString()} $unite');
    }
    if (avecRepas) parts.add('avec repas');
    if (parts.isEmpty && prescription.indication != null) {
      return prescription.indication;
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _onPriseTap(_Prise prise) async {
    final apiPrise = prise.apiPrise;
    if (apiPrise == null) return;
    final local = apiPrise.datetimePrevue.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final action = await showPriseActionsSheet(
      context,
      info: PriseActionsContext(
        medicamentName: prise.name,
        dose: prise.meta ?? '',
        scheduledLabel: 'Prévue à $hh:$mm',
      ),
    );
    if (action == null || !mounted) return;
    final statut = switch (action) {
      PriseAction.taken => api.UpdatePriseInputStatutEnum.prise,
      PriseAction.skipped => api.UpdatePriseInputStatutEnum.sautee,
      PriseAction.snoozed => null, // pas encore branché serveur-side
    };
    if (statut == null) {
      if (mounted) PilooToast.info(context, 'Reporter bientôt disponible.');
      return;
    }
    try {
      await updatePriseStatut(
        ref,
        priseId: apiPrise.id,
        officineId: apiPrise.officineId,
        date: isoDate(_date),
        statut: statut,
      );
      if (mounted) {
        PilooToast.success(
          context,
          statut == api.UpdatePriseInputStatutEnum.prise
              ? 'Prise validée.'
              : 'Prise sautée.',
        );
      }
    } catch (e) {
      if (mounted) PilooToast.error(context, 'Échec : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOfficine = ref.watch(activeOfficineProvider).valueOrNull;
    final prisesAsync = activeOfficine == null
        ? const AsyncValue<List<api.PriseTimelineItem>>.data([])
        : ref.watch(prisesDayProvider(
            PrisesDayKey(officineId: activeOfficine.id, date: isoDate(_date)),
          ));

    final apiBuckets = prisesAsync.maybeWhen(
      data: _groupByMoment,
      orElse: () => (
        matin: <_Prise>[],
        midi: <_Prise>[],
        soir: <_Prise>[],
        coucher: <_Prise>[],
      ),
    );

    final hasApiData = apiBuckets.matin.isNotEmpty ||
        apiBuckets.midi.isNotEmpty ||
        apiBuckets.soir.isNotEmpty ||
        apiBuckets.coucher.isNotEmpty;

    final matin = hasApiData ? apiBuckets.matin : _mockMatin;
    final midi = hasApiData ? apiBuckets.midi : _mockMidi;
    final soir = hasApiData ? apiBuckets.soir : _mockSoir;
    final coucher = hasApiData ? apiBuckets.coucher : _mockCoucher;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PilooScreenHeader(
              title: "Aujourd'hui",
              bellEnabled: false,
            ),
            PilooDayPicker(
              date: _date,
              onPrev: _canGoPrev ? () => _shiftDay(-1) : null,
              onNext: _canGoNext ? () => _shiftDay(1) : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      icon: PhosphorIconsFill.sunHorizon,
                      label: 'Matin',
                      countLabel: _countLabel(matin),
                      countColor: _countColor(matin),
                      prises: matin,
                      onPriseTap: _onPriseTap,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: PhosphorIconsFill.sun,
                      label: 'Midi',
                      countLabel: _countLabel(midi),
                      countColor: _countColor(midi),
                      prises: midi,
                      onPriseTap: _onPriseTap,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: PhosphorIconsFill.moon,
                      label: 'Soir',
                      countLabel: _countLabel(soir),
                      countColor: _countColor(soir),
                      prises: soir,
                      onPriseTap: _onPriseTap,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: PhosphorIconsFill.moonStars,
                      label: 'Coucher',
                      countLabel: _countLabel(coucher),
                      countColor: _countColor(coucher),
                      prises: coucher,
                      onPriseTap: _onPriseTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countLabel(List<_Prise> prises) {
    if (prises.isEmpty) return 'Aucune';
    final missed = prises.where((p) => p.status == PriseStatus.missed).length;
    if (missed > 0) return '$missed oubliée${missed > 1 ? 's' : ''}';
    return '${prises.length} prise${prises.length > 1 ? 's' : ''}';
  }

  Color _countColor(List<_Prise> prises) {
    final hasMissed = prises.any((p) => p.status == PriseStatus.missed);
    return hasMissed ? PilooColors.warningOn : PilooColors.textTertiary;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.countLabel,
    required this.countColor,
    required this.prises,
    required this.onPriseTap,
  });

  final IconData icon;
  final String label;
  final String countLabel;
  final Color countColor;
  final List<_Prise> prises;
  final Future<void> Function(_Prise) onPriseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: PilooColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                countLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(prises.length, (i) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: _PriseCard(prise: prises[i], onTap: onPriseTap),
          );
        }),
      ],
    );
  }
}

class _PriseCard extends StatelessWidget {
  const _PriseCard({required this.prise, required this.onTap});

  final _Prise prise;
  final Future<void> Function(_Prise) onTap;

  @override
  Widget build(BuildContext context) {
    final missed = prise.status == PriseStatus.missed;
    final cardColor = missed ? PilooColors.warning : PilooColors.surface;
    final borderColor = missed ? PilooColors.warningOn : PilooColors.border;
    final timeColor = switch (prise.status) {
      PriseStatus.taken => PilooColors.textSecondary,
      PriseStatus.upcoming => PilooColors.textPrimary,
      PriseStatus.missed => PilooColors.warningOn,
      PriseStatus.skipped => PilooColors.textTertiary,
    };
    final metaColor = missed ? PilooColors.warningOn : PilooColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(prise),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StatusDot(status: prise.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prise.name,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
                ),
                if (prise.meta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    prise.meta!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: metaColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            prise.timeOrLabel,
            style: GoogleFonts.manrope(
              fontSize: missed ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: timeColor,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    await showPriseActionsSheet(
      context,
      info: PriseActionsContext(
        medicamentName: prise.name,
        dose: prise.meta ?? '1 prise',
        scheduledLabel: prise.status == PriseStatus.missed
            ? '${prise.timeOrLabel} · oubliée'
            : 'Prévue à ${prise.timeOrLabel}',
      ),
    );
    // TODO #91 : convertir le PriseAction en pending_operations.
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final PriseStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PriseStatus.taken => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.success,
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsBold.check,
            size: 14,
            color: PilooColors.successOn,
          ),
        ),
      PriseStatus.upcoming => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PilooColors.border, width: 2),
          ),
        ),
      PriseStatus.missed => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.warningOn,
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsFill.warning,
            size: 14,
            color: Colors.white,
          ),
        ),
      PriseStatus.skipped => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.surfaceSubtle,
            border: Border.all(color: PilooColors.border, width: 2),
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsRegular.x,
            size: 14,
            color: PilooColors.textTertiary,
          ),
        ),
    };
  }
}
