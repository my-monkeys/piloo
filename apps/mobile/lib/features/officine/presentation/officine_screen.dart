// Écran 03 Officine — liste + filtres + recherche (#87).
// Maquette : `i1ydC` du fichier docs/design/piloo-mobile.pen.
//
// Structure :
//  - Header "Officine"
//  - Switcher d'officine : chip blanc avec icône house + nom + caret
//    (tap → S1 #72 : sélectionner une autre officine du foyer/pro)
//  - Compteur "12 boîtes · 8 médicaments"
//  - Champ recherche (placeholder : "Rechercher un médicament…")
//  - Pills filtres : Tout · Actif · Périmé · Stock bas (compteur dans
//    le label, couleur du compteur signale la criticité)
//  - Liste verticale de cards "boîte" :
//      - icône (pill-fill, drop-fill, etc.) sur tile colorée selon
//        l'état (vert primary par défaut, accent sur stock bas, error
//        sur périmé)
//      - nom + meta (DCI · forme galénique)
//      - badge stock (à droite haut), exp date (à droite bas)
//      - card "périmé" : fond rouge clair $error + bord $error-on,
//        signal d'action urgente (à jeter)
//
// Données mockées : reproduit fidèlement la maquette pour la review
// visuelle. Sera branché sur Drift + filter Riverpod quand l'epic
// Inventory (#11) avancera.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/officine/data/grouping_pref.dart';
import 'package:piloo/features/officine/domain/boite_grouping.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';

enum _Filter { tout, actif, perime, stockBas }

enum _BoiteState { ok, stockBas, perime }

class _Boite implements GroupableBoite {
  const _Boite({
    required this.name,
    required this.dci,
    required this.meta,
    required this.icon,
    required this.count,
    this.exp,
    this.state = _BoiteState.ok,
  });

  @override
  final String name;
  @override
  final String dci;
  final String meta;
  final IconData icon;
  final int count;
  final String? exp; // ex: "exp. 08/2026" ou null si périmé
  final _BoiteState state;
}

class OfficineScreen extends StatefulWidget {
  const OfficineScreen({super.key});

  @override
  State<OfficineScreen> createState() => _OfficineScreenState();
}

class _OfficineScreenState extends State<OfficineScreen> {
  _Filter _filter = _Filter.tout;
  BoiteGrouping _grouping = BoiteGrouping.medicament;

  @override
  void initState() {
    super.initState();
    _loadGrouping();
  }

  Future<void> _loadGrouping() async {
    final saved = await readBoiteGrouping();
    if (!mounted) return;
    setState(() => _grouping = saved);
  }

  void _changeGrouping(BoiteGrouping mode) {
    setState(() => _grouping = mode);
    // Persistence best-effort, on ne bloque pas l'UI dessus.
    writeBoiteGrouping(mode);
  }

  // Mock — le branchement Drift arrivera avec l'epic Inventory.
  static const _all = [
    _Boite(
      name: 'Doliprane 1000 mg',
      dci: 'Paracétamol',
      meta: 'Paracétamol · comprimé',
      icon: PhosphorIconsFill.pill,
      count: 3,
      exp: 'exp. 08/2026',
    ),
    _Boite(
      name: 'Kardegic 75 mg',
      dci: 'Acide acétylsalicylique',
      meta: 'Acide acétylsalicylique · sachet',
      icon: PhosphorIconsFill.pill,
      count: 2,
      exp: 'exp. 06/2026',
      state: _BoiteState.stockBas,
    ),
    _Boite(
      name: 'Metformine 500 mg',
      dci: 'Metformine',
      meta: 'Metformine · comprimé',
      icon: PhosphorIconsFill.pill,
      count: 1,
      exp: 'exp. 05/2027',
    ),
    _Boite(
      name: 'Amoxicilline 500 mg',
      dci: 'Amoxicilline',
      meta: 'Périmée depuis 14 jours · à jeter',
      icon: PhosphorIconsFill.warningOctagon,
      count: 1,
      state: _BoiteState.perime,
    ),
    _Boite(
      name: 'Humex rhume',
      dci: 'Paracétamol + chlorphénamine',
      meta: 'Paracétamol + chlorphénamine · sirop',
      icon: PhosphorIconsFill.drop,
      count: 1,
      exp: 'exp. 11/2025',
    ),
    _Boite(
      name: 'Dafalgan 500 mg',
      dci: 'Paracétamol',
      meta: 'Paracétamol · gélule',
      icon: PhosphorIconsFill.pill,
      count: 2,
      exp: 'exp. 03/2027',
    ),
  ];

  List<_Boite> get _filtered => switch (_filter) {
        _Filter.tout => _all,
        _Filter.actif => _all
            .where((b) => b.state == _BoiteState.ok)
            .toList(growable: false),
        _Filter.perime => _all
            .where((b) => b.state == _BoiteState.perime)
            .toList(growable: false),
        _Filter.stockBas => _all
            .where((b) => b.state == _BoiteState.stockBas)
            .toList(growable: false),
      };

  @override
  Widget build(BuildContext context) {
    final perimeCount =
        _all.where((b) => b.state == _BoiteState.perime).length;
    final stockBasCount =
        _all.where((b) => b.state == _BoiteState.stockBas).length;

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PilooScreenHeader(title: 'Officine', bellEnabled: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _OfficineSwitcher(label: 'Maison', onTap: () {}),
                  Flexible(
                    child: Text(
                      '12 boîtes · 8 médicaments',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: PilooColors.textTertiary,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: _SearchBox(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _GroupingToggle(
                value: _grouping,
                onChanged: _changeGrouping,
              ),
            ),
            // Hauteur 52 + padding vertical 8 = 36 px utiles pour les
            // pilules (padding interne 6 + texte 12 line-height ≈ 32),
            // sinon le texte se fait écraser verticalement.
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  _FilterChip(
                    label: 'Tout · ${_all.length}',
                    selected: _filter == _Filter.tout,
                    onTap: () => setState(() => _filter = _Filter.tout),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Actif',
                    selected: _filter == _Filter.actif,
                    onTap: () => setState(() => _filter = _Filter.actif),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Périmé · $perimeCount',
                    accent: PilooColors.errorOn,
                    selected: _filter == _Filter.perime,
                    onTap: () => setState(() => _filter = _Filter.perime),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Stock bas · $stockBasCount',
                    accent: PilooColors.warningOn,
                    selected: _filter == _Filter.stockBas,
                    onTap: () => setState(() => _filter = _Filter.stockBas),
                  ),
                ],
              ),
            ),
            Expanded(
              // Bottom padding 140 = tab bar (~105) + safe area home
              // indicator (extendBody: true côté _MainShell).
              child: _GroupedList(
                sections: groupBoites(_filtered, _grouping),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficineSwitcher extends StatelessWidget {
  const _OfficineSwitcher({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsFill.house,
              size: 14,
              color: PilooColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              PhosphorIconsRegular.caretDown,
              size: 12,
              color: PilooColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 16,
            color: PilooColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: 'Rechercher un médicament…',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  color: PilooColors.textTertiary,
                ),
              ),
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: PilooColors.textPrimary,
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
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  // Couleur du label quand non sélectionné (pour signaler la criticité
  // du filtre — rouge "périmé", ambre "stock bas").
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? PilooColors.textOnPrimary
        : (accent ?? PilooColors.textPrimary);
    // Align.center pour ne pas étirer le chip en hauteur dans la
    // ListView horizontale (sinon le texte se fait pousser et le
    // padding visuel disparaît).
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
            border:
                selected ? null : Border.all(color: PilooColors.border),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupingToggle extends StatelessWidget {
  const _GroupingToggle({required this.value, required this.onChanged});

  final BoiteGrouping value;
  final ValueChanged<BoiteGrouping> onChanged;

  static const _options = [
    (mode: BoiteGrouping.medicament, label: 'Médicament'),
    (mode: BoiteGrouping.molecule, label: 'Molécule'),
    (mode: BoiteGrouping.plat, label: 'Toutes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final opt in _options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(opt.mode),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: value == opt.mode
                        ? PilooColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: value == opt.mode
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt.label,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: value == opt.mode
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: value == opt.mode
                          ? PilooColors.textPrimary
                          : PilooColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.sections});

  final List<BoiteSection<_Boite>> sections;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (section.header != null) {
        if (s > 0) items.add(const SizedBox(height: 8));
        items.add(_SectionHeader(label: section.header!));
        items.add(const SizedBox(height: 8));
      } else if (s > 0) {
        items.add(const SizedBox(height: 10));
      }
      for (var i = 0; i < section.boites.length; i++) {
        if (i > 0) items.add(const SizedBox(height: 10));
        items.add(_BoiteCard(boite: section.boites[i]));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: items,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: PilooColors.textTertiary,
      ),
    );
  }
}

class _BoiteCard extends StatelessWidget {
  const _BoiteCard({required this.boite});

  final _Boite boite;

  @override
  Widget build(BuildContext context) {
    final isPerime = boite.state == _BoiteState.perime;
    final isStockBas = boite.state == _BoiteState.stockBas;

    final cardBg = isPerime ? PilooColors.error : PilooColors.surface;
    final cardBorder = isPerime ? PilooColors.errorOn : PilooColors.border;

    final iconBg = isPerime
        ? PilooColors.errorOn
        : isStockBas
            ? PilooColors.accentSoft
            : PilooColors.primarySoft;
    final iconFg = isPerime
        ? Colors.white
        : isStockBas
            ? PilooColors.accent
            : PilooColors.primary;

    final countBg = isPerime
        ? PilooColors.errorOn
        : isStockBas
            ? PilooColors.warning
            : PilooColors.primarySoft;
    final countFg = isPerime
        ? Colors.white
        : isStockBas
            ? PilooColors.warningOn
            : PilooColors.primary;

    final metaColor = isPerime
        ? PilooColors.errorOn
        : PilooColors.textSecondary;
    final expColor = isStockBas
        ? PilooColors.warningOn
        : PilooColors.textTertiary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(boite.icon, size: 22, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  boite.name,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  boite.meta,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: isPerime ? FontWeight.w500 : FontWeight.normal,
                    color: metaColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${boite.count}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: countFg,
                  ),
                ),
              ),
              if (boite.exp != null) ...[
                const SizedBox(height: 4),
                Text(
                  boite.exp!,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight:
                        isStockBas ? FontWeight.w600 : FontWeight.normal,
                    color: expColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
