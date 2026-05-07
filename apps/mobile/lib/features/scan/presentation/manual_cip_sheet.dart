// Bottom sheet de saisie manuelle CIP13 (#85).
//
// Utilisé quand :
//  - le scan a échoué (DataMatrix non-pharma, pas lisible)
//  - l'utilisateur connaît le CIP de tête (collé d'une ordonnance ou
//    écrit sur la boîte)
//
// Le sheet retourne :
//   - un `ScanResult` avec juste le cip13 (lot/serial/expiry vides)
//     si l'utilisateur a saisi un CIP valide
//   - null si l'utilisateur a fermé ou cliqué "Continuer sans CIP"
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/scan/data/scan_result.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';

/// Affiche le sheet. Retourne un `ScanResult` si l'utilisateur a saisi
/// un CIP valide, null s'il a annulé ou choisi "Continuer sans CIP".
Future<ScanResult?> showManualCipSheet(BuildContext context) {
  return showModalBottomSheet<ScanResult?>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ManualCipSheet(),
  );
}

class _ManualCipSheet extends StatefulWidget {
  const _ManualCipSheet();

  @override
  State<_ManualCipSheet> createState() => _ManualCipSheetState();
}

class _ManualCipSheetState extends State<_ManualCipSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Saisis le code à 13 chiffres au dos de la boîte.');
      return;
    }
    if (!RegExp(r'^\d{13}$').hasMatch(raw)) {
      setState(() => _error = 'Le CIP13 doit faire 13 chiffres.');
      return;
    }
    if (!raw.startsWith('3400')) {
      // Heuristique : tous les CIP13 français commencent par 3400.
      // Un autre préfixe = saisie probablement erronée.
      setState(() => _error = 'Ce code ne ressemble pas à un CIP13 français.');
      return;
    }
    Navigator.of(context).pop(ScanResult(cip13: raw));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
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
            Center(
              child: Text(
                'Saisir le CIP13 à la main',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Le code à 13 chiffres se trouve au dos de la boîte, '
              'sous le DataMatrix. Il commence par 3400.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: PilooColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: PilooColors.surface,
                borderRadius: BorderRadius.circular(PilooRadius.md),
                border: Border.all(
                  color: _error != null
                      ? PilooColors.errorOn
                      : PilooColors.border,
                ),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: '3400…',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 14,
                    color: PilooColors.textTertiary,
                  ),
                ),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  letterSpacing: 1,
                  color: PilooColors.textPrimary,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: PilooColors.errorOn,
                ),
              ),
            ],
            const SizedBox(height: 20),
            PilooButton(
              label: 'Continuer',
              variant: PilooButtonVariant.primary,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Continuer sans CIP',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
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
