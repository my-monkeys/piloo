// Page dev permettant de reviewer la `showQuickActionsSheet` (#101)
// sur le simulateur via `--dart-define=PILOO_BOOT_ROUTE=/_dev/quick-actions`.
// Ouvre automatiquement la sheet au mount avec des données mockées.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/features/inventory/presentation/quick_actions_sheet.dart';

class QuickActionsDemoScreen extends StatefulWidget {
  const QuickActionsDemoScreen({super.key});

  @override
  State<QuickActionsDemoScreen> createState() => _QuickActionsDemoScreenState();
}

class _QuickActionsDemoScreenState extends State<QuickActionsDemoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    await showQuickActionsSheet(
      context,
      info: const QuickActionsContext(
        officineLabel: 'Maison',
        medicamentName: 'Doliprane 1000 mg',
        cip13: '3400934857188',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Demo Quick Actions Sheet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La sheet s\'ouvre automatiquement. Tape pour la rouvrir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: PilooColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _open,
                  child: const Text('Rouvrir la sheet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
