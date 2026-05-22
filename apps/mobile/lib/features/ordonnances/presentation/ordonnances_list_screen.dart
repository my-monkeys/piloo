// Écran 09 Liste ordonnances (#109).
// Maquette : `gt24R` du fichier docs/design/piloo-mobile.pen.
//
// Liste des ordonnances de l'officine active, filtrables par statut
// (Actives / Terminées). Chaque card affiche :
//  - prescripteur (Dr X) + spécialité · date
//  - badge statut coloré
//  - sub-card \$bg avec preview des médocs prescrits (bullets)
//
// Tap sur une card → push /ordonnances/:id (#10 epic).
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
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

class _Ordonnance {
  const _Ordonnance({
    required this.id,
    required this.prescripteur,
    required this.date,
  });

  final String id;
  final String prescripteur;
  final String date;
}

class OrdonnancesListScreen extends ConsumerWidget {
  const OrdonnancesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officine = ref.watch(activeOfficineProvider).valueOrNull;
    final listAsync = officine == null
        ? const AsyncValue<List<api.Ordonnance>>.data([])
        : ref.watch(ordonnancesProvider(officine.id));

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              // go_router : on doit utiliser `context.push(<path>)` ou
              // `context.pushNamed(<name>)` — pas `Navigator.pushNamed`
              // qui s'attend à un NAME et fail silencieux sur un PATH.
              // Avant 2026-05-22 : tap sur "+" ne faisait rien.
              onAdd: () => context.push(RoutePath.ordonnanceCreate),
            ),
            Expanded(
              child: listAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Impossible de charger les ordonnances.\n$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.prescription,
                              size: 48,
                              color: PilooColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune ordonnance',
                              style: GoogleFonts.fraunces(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: PilooColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ajoute une ordonnance pour suivre tes prescriptions.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: PilooColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final mapped = rows.map(_mapApi).toList();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: mapped.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final o = mapped[i];
                      return _OrdoCard(
                        ordonnance: o,
                        onTap: () =>
                            context.push(RoutePath.ordonnanceDetail(o.id)),
                      );
                    },
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

_Ordonnance _mapApi(api.Ordonnance o) {
  final d = o.datePrescription;
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  return _Ordonnance(
    id: o.id,
    prescripteur: o.prescripteur ?? 'Sans prescripteur',
    date: '${d.day} ${months[d.month - 1]} ${d.year}',
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

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
              'Ordonnances',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAdd,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PilooColors.primary,
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsBold.plus,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdoCard extends StatelessWidget {
  const _OrdoCard({required this.ordonnance, required this.onTap});

  final _Ordonnance ordonnance;
  final VoidCallback onTap;

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ordonnance.prescripteur,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ordonnance.date,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: PilooColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
