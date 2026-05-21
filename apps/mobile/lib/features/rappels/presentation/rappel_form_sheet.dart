// Bottom sheet de création d'un rappel simple (#327).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

class RappelDraft {
  const RappelDraft({required this.label, required this.heure});
  final String label;
  /// HH:MM:SS pour matcher le format Postgres `time`.
  final String heure;
}

Future<RappelDraft?> showRappelFormSheet(BuildContext context) {
  return showModalBottomSheet<RappelDraft>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _RappelFormSheet(),
  );
}

class _RappelFormSheet extends StatefulWidget {
  const _RappelFormSheet();

  @override
  State<_RappelFormSheet> createState() => _RappelFormSheetState();
}

class _RappelFormSheetState extends State<_RappelFormSheet> {
  final _labelCtrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    Navigator.of(context).pop(RappelDraft(label: label, heure: '$hh:$mm:00'));
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
                'Nouveau rappel',
                style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                "Un aide-mémoire récurrent chaque jour à l'heure choisie.",
                style: GoogleFonts.manrope(fontSize: 12, color: PilooColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Libellé',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: PilooColors.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                style: GoogleFonts.manrope(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ex. Pilule, Vitamine D, Magnésium…',
                  hintStyle: GoogleFonts.manrope(fontSize: 13, color: PilooColors.textTertiary),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Heure',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: PilooColors.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(PilooRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: PilooColors.surface,
                    borderRadius: BorderRadius.circular(PilooRadius.md),
                    border: Border.all(color: PilooColors.border),
                  ),
                  child: Text(
                    _time.format(context),
                    style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: PilooColors.primary),
                      child: const Text('Créer le rappel'),
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
