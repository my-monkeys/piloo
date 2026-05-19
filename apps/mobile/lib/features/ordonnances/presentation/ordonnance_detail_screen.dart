// Écran 10 Détail ordonnance (#113 + parent #110).
//
// Affiche une ordonnance avec ses prescriptions, permet :
//   - Édition prescripteur / date / notes via un bottom sheet (#113).
//   - Duplication : crée une nouvelle ordonnance à la date du jour
//     avec les mêmes médocs (cas du renouvellement à l'identique).
//
// La suppression (soft delete) n'est PAS implémentée ici — l'API
// `DELETE /v1/ordonnances/{id}` existe mais on attend un flow UX
// dédié pour confirmer (ticket séparé).
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
import 'package:piloo/features/ordonnances/data/ordonnances_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

class OrdonnanceDetailScreen extends ConsumerWidget {
  const OrdonnanceDetailScreen({required this.ordonnanceId, super.key});

  final String ordonnanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(ordonnanceDetailProvider(ordonnanceId));
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Column(
            children: [
              _Header(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Impossible de charger l\'ordonnance.\n$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (o) => _DetailBody(ordonnance: o),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.ordonnance});

  final api.OrdonnanceWithPrescriptions ordonnance;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _busy = false;

  Future<void> _openEdit() async {
    final o = widget.ordonnance;
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      backgroundColor: PilooColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditSheet(
        initialPrescripteur: o.prescripteur ?? '',
        initialDate: DateTime(
          o.datePrescription.year,
          o.datePrescription.month,
          o.datePrescription.day,
        ),
        initialNotes: o.notes ?? '',
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await updateOrdonnance(
        ref,
        ordonnanceId: o.id,
        prescripteur: result.prescripteur,
        datePrescription: api.Date(
          result.date.year,
          result.date.month,
          result.date.day,
        ),
        notes: result.notes,
      );
      final officineId = ref.read(activeOfficineProvider).valueOrNull?.id;
      if (officineId != null) ref.invalidate(ordonnancesProvider(officineId));
      if (mounted) PilooToast.success(context, 'Ordonnance mise à jour.');
    } catch (e) {
      if (mounted) PilooToast.error(context, 'Échec : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _duplicate() async {
    final officineId = ref.read(activeOfficineProvider).valueOrNull?.id;
    if (officineId == null) {
      PilooToast.error(context, 'Officine active introuvable.');
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await duplicateOrdonnance(
        ref,
        source: widget.ordonnance,
        officineId: officineId,
      );
      if (!mounted) return;
      PilooToast.success(context, 'Ordonnance dupliquée.');
      context.go(RoutePath.ordonnanceDetail(created.id));
    } catch (e) {
      if (mounted) PilooToast.error(context, 'Échec : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.ordonnance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Summary(ordonnance: o),
                const SizedBox(height: 14),
                _PrescriptionsList(prescriptions: o.prescriptions.toList()),
                if (o.notes != null && o.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _NotesCard(notes: o.notes!),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              PilooButton(
                label: 'Modifier',
                variant: PilooButtonVariant.outline,
                onPressed: _busy ? null : _openEdit,
              ),
              const SizedBox(height: 8),
              PilooButton(
                label: _busy ? 'Duplication...' : 'Dupliquer pour aujourd\'hui',
                variant: PilooButtonVariant.primary,
                onPressed: _busy ? null : _duplicate,
              ),
            ],
          ),
        ),
      ],
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
              'Ordonnance',
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

class _Summary extends StatelessWidget {
  const _Summary({required this.ordonnance});

  final api.OrdonnanceWithPrescriptions ordonnance;

  @override
  Widget build(BuildContext context) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final d = ordonnance.datePrescription;
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ordonnance.prescripteur?.isNotEmpty == true
                ? ordonnance.prescripteur!
                : 'Sans prescripteur',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PilooColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prescrite le $dateStr',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: PilooColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionsList extends StatelessWidget {
  const _PrescriptionsList({required this.prescriptions});

  final List<api.Prescription> prescriptions;

  @override
  Widget build(BuildContext context) {
    if (prescriptions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Aucun médicament dans cette ordonnance.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textTertiary,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(prescriptions.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(height: 1, color: PilooColors.border);
          }
          return _PrescriptionRow(prescription: prescriptions[i ~/ 2]);
        }),
      ),
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({required this.prescription});

  final api.Prescription prescription;

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final raw = p.posologie;
    final units = raw['unitesParPrise']?.value;
    final unite = raw['unite']?.value;
    final freq = raw['frequence']?.value;
    final parts = <String>[];
    if (units != null && unite is String) parts.add('$units $unite');
    if (freq is String) parts.add(freq);
    final posoLine = parts.join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.nomTexte,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PilooColors.textPrimary,
            ),
          ),
          if (posoLine.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              posoLine,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.textSecondary,
              ),
            ),
          ],
          if (p.indication != null && p.indication!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              p.indication!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: PilooColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

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
          Text(
            'NOTES',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: PilooColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: PilooColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditResult {
  const _EditResult({
    required this.prescripteur,
    required this.date,
    required this.notes,
  });

  final String prescripteur;
  final DateTime date;
  final String notes;
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.initialPrescripteur,
    required this.initialDate,
    required this.initialNotes,
  });

  final String initialPrescripteur;
  final DateTime initialDate;
  final String initialNotes;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _prescripteurCtrl =
      TextEditingController(text: widget.initialPrescripteur);
  late final _notesCtrl = TextEditingController(text: widget.initialNotes);
  late DateTime _date = widget.initialDate;

  @override
  void dispose() {
    _prescripteurCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    Navigator.of(context).pop(_EditResult(
      prescripteur: _prescripteurCtrl.text.trim(),
      date: _date,
      notes: _notesCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PilooColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Modifier',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _Label(text: 'PRESCRIPTEUR'),
              const SizedBox(height: 4),
              TextField(
                controller: _prescripteurCtrl,
                decoration: const InputDecoration(
                  hintText: 'Dr Sophie Laurent',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              _Label(text: 'DATE DE PRESCRIPTION'),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: PilooColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_date.day.toString().padLeft(2, '0')}/'
                          '${_date.month.toString().padLeft(2, '0')}/'
                          '${_date.year}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: PilooColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        PhosphorIconsRegular.calendarBlank,
                        size: 16,
                        color: PilooColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Label(text: 'NOTES'),
              const SizedBox(height: 4),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Notes libres',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PilooButton(
                      label: 'Annuler',
                      variant: PilooButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PilooButton(
                      label: 'Enregistrer',
                      variant: PilooButtonVariant.primary,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: PilooColors.textTertiary,
      ),
    );
  }
}
