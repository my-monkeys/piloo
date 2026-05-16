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
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

enum _OrdoStatus { active, terminee }

class _Ordonnance {
  const _Ordonnance({
    required this.id,
    required this.prescripteur,
    required this.specialite,
    required this.date,
    required this.status,
    required this.medocs,
  });

  final String id;
  final String prescripteur;
  final String specialite;
  final String date;
  final _OrdoStatus status;
  final List<String> medocs;
}

class OrdonnancesListScreen extends StatefulWidget {
  const OrdonnancesListScreen({super.key});

  @override
  State<OrdonnancesListScreen> createState() => _OrdonnancesListScreenState();
}

class _OrdonnancesListScreenState extends State<OrdonnancesListScreen> {
  _OrdoStatus _filter = _OrdoStatus.active;

  static const _all = [
    _Ordonnance(
      id: 'o1',
      prescripteur: 'Dr Sophie Laurent',
      specialite: 'Cardiologue',
      date: '20 mars 2026',
      status: _OrdoStatus.active,
      medocs: [
        'Ramipril 5 mg — 1 cp/j',
        'Atorvastatine 20 mg — 1 cp le soir',
        'Kardegic 75 mg — 1 sachet/j',
      ],
    ),
    _Ordonnance(
      id: 'o2',
      prescripteur: 'Dr Thomas Martin',
      specialite: 'Médecin traitant',
      date: '10 avril 2026',
      status: _OrdoStatus.active,
      medocs: [
        'Metformine 500 mg — 1 cp matin + soir',
        'Doliprane 1000 mg — si douleur, max 4/j',
      ],
    ),
    _Ordonnance(
      id: 'o3',
      prescripteur: 'Dr Julie Benoît',
      specialite: 'ORL',
      date: '28 février 2026',
      status: _OrdoStatus.terminee,
      medocs: [
        'Amoxicilline 500 mg — 3/j pendant 7 jours',
      ],
    ),
  ];

  List<_Ordonnance> get _filtered =>
      _all.where((o) => o.status == _filter).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final actives = _all.where((o) => o.status == _OrdoStatus.active).length;
    final terminees =
        _all.where((o) => o.status == _OrdoStatus.terminee).length;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              onAdd: () => Navigator.of(context)
                  .pushNamed(RoutePath.ordonnanceCreate),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Actives · $actives',
                    selected: _filter == _OrdoStatus.active,
                    onTap: () => setState(() => _filter = _OrdoStatus.active),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Terminées · $terminees',
                    selected: _filter == _OrdoStatus.terminee,
                    onTap: () =>
                        setState(() => _filter = _OrdoStatus.terminee),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final o = _filtered[i];
                  return _OrdoCard(
                    ordonnance: o,
                    onTap: () =>
                        context.push(RoutePath.ordonnanceDetail(o.id)),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? PilooColors.primary : PilooColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: PilooColors.border),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? PilooColors.textOnPrimary
                  : PilooColors.textPrimary,
            ),
          ),
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        '${ordonnance.specialite} · ${ordonnance.date}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: PilooColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: ordonnance.status),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PilooColors.background,
                borderRadius: BorderRadius.circular(PilooRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < ordonnance.medocs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    Text(
                      '• ${ordonnance.medocs[i]}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _OrdoStatus status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == _OrdoStatus.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? PilooColors.success : PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Terminée',
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? PilooColors.successOn : PilooColors.textSecondary,
        ),
      ),
    );
  }
}
