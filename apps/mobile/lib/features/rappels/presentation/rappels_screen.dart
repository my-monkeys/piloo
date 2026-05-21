// Écran Rappels simples (#327).
//
// Liste les rappels actifs/inactifs de l'user, permet d'en créer, de
// toggle on/off ou supprimer. Chaque mutation re-schedule les notifs
// locales via RappelScheduler.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/rappels/data/rappel_scheduler.dart';
import 'package:piloo/features/rappels/data/rappels_provider.dart';
import 'package:piloo/features/rappels/presentation/rappel_form_sheet.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

final _notificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>(
  (ref) => FlutterLocalNotificationsPlugin(),
);

final _schedulerProvider = Provider<RappelScheduler>(
  (ref) => RappelScheduler(ref.read(_notificationsPluginProvider)),
);

class RappelsScreen extends ConsumerWidget {
  const RappelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rappelsAsync = ref.watch(rappelsProvider);

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const PilooCircleBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rappels',
                      style: GoogleFonts.fraunces(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Aide-mémoire récurrents (pilule, vitamine, supplément). '
                "Tu n'as pas besoin d'ajouter une ordonnance.",
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: PilooColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: rappelsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(error: '$e'),
                data: (rappels) => rappels.isEmpty
                    ? const _EmptyState()
                    : _RappelsList(rappels: rappels),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PilooColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(PhosphorIconsRegular.plus),
        label: Text(
          'Nouveau rappel',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        onPressed: () => _openCreateSheet(context, ref),
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final draft = await showRappelFormSheet(context);
    if (draft == null) return;
    try {
      await createRappel(
        ref,
        label: draft.label,
        heure: draft.heure,
      );
      final current = await ref.read(rappelsProvider.future);
      await ref.read(_schedulerProvider).rescheduleAll(current);
      if (context.mounted) PilooToast.success(context, 'Rappel créé.');
    } catch (e) {
      if (context.mounted) PilooToast.error(context, 'Échec : $e');
    }
  }
}

class _RappelsList extends ConsumerWidget {
  const _RappelsList({required this.rappels});
  final List<api.Rappel> rappels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: rappels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RappelTile(rappel: rappels[i]),
    );
  }
}

class _RappelTile extends ConsumerWidget {
  const _RappelTile({required this.rappel});
  final api.Rappel rappel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heureLabel = rappel.heure.length >= 5 ? rappel.heure.substring(0, 5) : rappel.heure;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: rappel.actif ? PilooColors.primarySoft : PilooColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIconsFill.bell,
              size: 22,
              color: rappel.actif ? PilooColors.primary : PilooColors.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rappel.label,
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: rappel.actif ? PilooColors.textPrimary : PilooColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tous les jours · $heureLabel',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: rappel.actif,
            activeThumbColor: PilooColors.primary,
            onChanged: (v) => _toggle(context, ref, v),
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(PhosphorIconsRegular.trash, size: 20),
            color: PilooColors.textTertiary,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    try {
      await updateRappel(ref, rappelId: rappel.id, actif: value);
      final current = await ref.read(rappelsProvider.future);
      await ref.read(_schedulerProvider).rescheduleAll(current);
    } catch (e) {
      if (context.mounted) PilooToast.error(context, 'Échec : $e');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PilooColors.surface,
        title: Text('Supprimer ce rappel ?',
            style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w500)),
        content: Text(
          'Le rappel "${rappel.label}" sera supprimé et ne déclenchera plus de notification.',
          style: GoogleFonts.manrope(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteRappel(ref, rappelId: rappel.id);
      await ref.read(_schedulerProvider).cancel(rappel.id);
      ref.invalidate(rappelsProvider);
      if (context.mounted) PilooToast.success(context, 'Supprimé.');
    } catch (e) {
      if (context.mounted) PilooToast.error(context, 'Échec : $e');
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.bellSlash, size: 48, color: PilooColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              'Aucun rappel pour le moment',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Ajoute un rappel quotidien pour ta pilule, ta vitamine D ou tout aide-mémoire récurrent.",
              style: GoogleFonts.manrope(fontSize: 13, color: PilooColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Erreur de chargement : $error',
          style: GoogleFonts.manrope(fontSize: 13, color: PilooColors.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
