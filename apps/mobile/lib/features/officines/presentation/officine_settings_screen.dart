// Réglages d'une officine — sélecteur de fuseau horaire (#363).
//
// Le fuseau de l'officine détermine l'heure locale des prises (créneaux
// matin/midi/soir/coucher + libellés). Utile quand un pro/proche crée le
// carnet d'un patient d'une autre région que la sienne.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class OfficineSettingsScreen extends ConsumerStatefulWidget {
  const OfficineSettingsScreen({required this.officineId, super.key});

  final String officineId;

  @override
  ConsumerState<OfficineSettingsScreen> createState() => _OfficineSettingsScreenState();
}

class _OfficineSettingsScreenState extends ConsumerState<OfficineSettingsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _saving = false;

  /// Liste IANA triée (base tz initialisée au boot dans main.dart).
  late final List<String> _allZones = tz.timeZoneDatabase.locations.keys.toList()..sort();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return _allZones;
    final q = _query.toLowerCase();
    return _allZones.where((z) => z.toLowerCase().contains(q)).toList();
  }

  Future<void> _select(String zone) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await updateOfficineTimezone(
        ref,
        officineId: widget.officineId,
        timezone: zone,
      );
      if (mounted) {
        PilooToast.success(context, 'Fuseau mis à jour : $zone.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        PilooToast.error(context, 'Échec : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final officine = ref
        .watch(officinesListProvider)
        .valueOrNull
        ?.where((o) => o.id == widget.officineId)
        .firstOrNull;
    final current = officine?.timezone;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(subtitle: officine?.nom),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: _SearchField(controller: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final zone = _filtered[i];
                  return _ZoneRow(
                    zone: zone,
                    selected: zone == current,
                    onTap: _saving ? null : () => _select(zone),
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
  const _Header({this.subtitle});
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const PilooCircleBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fuseau horaire',
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.manrope(fontSize: 14, color: PilooColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Rechercher (ex. Paris, New_York)…',
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: PilooColors.textTertiary),
        prefixIcon: const Icon(
          PhosphorIconsRegular.magnifyingGlass,
          size: 18,
          color: PilooColors.textTertiary,
        ),
        filled: true,
        fillColor: PilooColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          borderSide: const BorderSide(color: PilooColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          borderSide: const BorderSide(color: PilooColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          borderSide: const BorderSide(color: PilooColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone, required this.selected, required this.onTap});
  final String zone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? PilooColors.primarySoft : PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(PilooRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PilooRadius.md),
              border: Border.all(
                color: selected ? PilooColors.primary : PilooColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    zone.replaceAll('_', ' '),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? PilooColors.primary : PilooColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(PhosphorIconsFill.checkCircle, size: 18, color: PilooColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
