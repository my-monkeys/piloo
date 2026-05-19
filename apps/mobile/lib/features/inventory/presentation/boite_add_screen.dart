// Écran 05 Nouvelle boîte post-scan (#89 + #84 wire-up BDPM).
// Maquette : `BRaE1` du fichier docs/design/piloo-mobile.pen.
//
// Form pré-rempli depuis le DataMatrix qu'on vient de scanner :
//   - Le `scanResultProvider` (#84) fournit cip13/lot/serial/expiry
//     extraits par le parser GS1 (#81).
//   - Le `bdpmDbProvider` résout cip13 → médicament reconnu (#83).
//   - Si scan absent ou cip13 inconnu, fallback "Médicament non
//    reconnu" (cas #85).
//
// Structure visuelle inchangée vs #89 ; seul le contenu du preview
// dépend maintenant des providers Riverpod.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

import 'package:piloo/core/router/routes.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/inventory/data/boites_provider.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/scan/data/scan_result.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_medicament.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

enum _StockLevel { plein, troisQuarts, moitie, unQuart, presqueVide }

class BoiteAddScreen extends ConsumerStatefulWidget {
  const BoiteAddScreen({super.key});

  @override
  ConsumerState<BoiteAddScreen> createState() => _BoiteAddScreenState();
}

class _BoiteAddScreenState extends ConsumerState<BoiteAddScreen> {
  _StockLevel _stock = _StockLevel.plein;
  final _notesCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  // Péremption : on stocke (mois, année) pour rester aligné avec ce
  // qu'on récupère du DataMatrix (AI 17 = YYMM).
  int _expMonth = 3;
  int _expYear = DateTime.now().year + 2;
  String _officine = 'Maison';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplit lot et péremption depuis le scan le plus récent.
    final scan = ref.read(scanResultProvider);
    if (scan != null) {
      if (scan.lot != null && scan.lot!.isNotEmpty) {
        _lotCtrl.text = scan.lot!;
      }
      if (scan.expiry != null) {
        _expMonth = scan.expiry!.month;
        _expYear = scan.expiry!.year;
      }
    }
  }

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _officines = ['Maison', 'Voiture', 'Bureau', 'Maman'];

  String get _expLabel =>
      '${_expMonth.toString().padLeft(2, '0')} / $_expYear';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _lotCtrl.dispose();
    super.dispose();
  }

  Future<void> _editPeremption() async {
    final picked = await showModalBottomSheet<({int month, int year})>(
      context: context,
      backgroundColor: PilooColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PeremptionPicker(
        initialMonth: _expMonth,
        initialYear: _expYear,
        months: _months,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _expMonth = picked.month;
        _expYear = picked.year;
      });
    }
  }

  Future<void> _save() async {
    final scan = ref.read(scanResultProvider);
    final cip13 = scan?.cip13;
    if (cip13 == null || cip13.length != 13) {
      PilooToast.error(context, 'Scan requis pour récupérer le CIP13.');
      return;
    }
    final activeOfficine = ref.read(activeOfficineProvider).valueOrNull;
    if (activeOfficine == null) {
      PilooToast.error(context, 'Aucune officine active.');
      return;
    }

    // BDPM (local OU API) : si on a le nom on le préfixe dans notes
    // pour le retrouver côté liste (voir convention dans officine_screen).
    // On utilise le lookup unifié — déjà mis en cache par Riverpod si
    // le preview screen l'a résolu.
    final lookup = await ref.read(bdpmLookupProvider(cip13).future);
    final medName = lookup?.denomination;
    final userNotes = _notesCtrl.text.trim();
    final notes = medName != null
        ? (userNotes.isEmpty ? medName : '$medName // $userNotes')
        : (userNotes.isEmpty ? null : userNotes);

    setState(() => _saving = true);
    try {
      await createBoite(
        ref,
        officineId: activeOfficine.id,
        cip13: cip13,
        peremption: _peremptionDate(),
        lot: _lotCtrl.text.trim().isEmpty ? null : _lotCtrl.text.trim(),
        unitesRestantes: _stockToUnits(_stock),
        notes: notes,
      );
      if (!mounted) return;
      PilooToast.success(context, 'Boîte ajoutée.');
      context.canPop() ? context.pop() : context.go(RoutePath.officine);
    } catch (e) {
      if (!mounted) return;
      PilooToast.error(context, 'Échec de l\'ajout : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  api.Date _peremptionDate() {
    // On prend le dernier jour du mois pour matcher l'usage "périmé à
    // compter de fin du mois N".
    final lastDay = DateTime(_expYear, _expMonth + 1, 0).day;
    return api.Date(_expYear, _expMonth, lastDay);
  }

  int? _stockToUnits(_StockLevel level) => switch (level) {
        _StockLevel.plein => null, // unitesInitiales/restantes inconnues
        _StockLevel.troisQuarts => 24,
        _StockLevel.moitie => 16,
        _StockLevel.unQuart => 8,
        _StockLevel.presqueVide => 2,
      };

  Future<void> _pickOfficine() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PilooColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OfficinePicker(
        current: _officine,
        options: _officines,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _officine = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onBack: () => context.canPop() ? context.pop() : context.go(RoutePath.today)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MedicamentPreviewSection(
                      cip13: ref.watch(scanResultProvider)?.cip13,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'PÉREMPTION',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _editPeremption,
                              child: _ValueRow(
                                text: _expLabel,
                                trailing: const Icon(
                                  PhosphorIconsRegular.pencilSimple,
                                  size: 16,
                                  color: PilooColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Field(
                            label: 'N° DE LOT',
                            child: _LotField(controller: _lotCtrl),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      label: 'OFFICINE CIBLE',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pickOfficine,
                        child: _ValueRow(
                          leading: const Icon(
                            PhosphorIconsFill.house,
                            size: 16,
                            color: PilooColors.primary,
                          ),
                          text: _officine,
                          trailing: const Icon(
                            PhosphorIconsRegular.caretDown,
                            size: 14,
                            color: PilooColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StockChips(
                      value: _stock,
                      onChanged: (v) => setState(() => _stock = v),
                    ),
                    const SizedBox(height: 16),
                    _NotesField(controller: _notesCtrl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PilooButton(
                      label: 'Annuler',
                      variant: PilooButtonVariant.outline,
                      onPressed: () => context.canPop() ? context.pop() : context.go(RoutePath.today),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PilooButton(
                      label: _saving ? 'Ajout…' : 'Ajouter',
                      variant: PilooButtonVariant.primary,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Header avec titre centré : back left + ghost 40 right pour
    // équilibrer la largeur (sinon le titre dérive vers la droite).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PilooCircleBackButton(),
          Flexible(
            child: Text(
              'Nouvelle boîte',
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

/// Wrapper qui résout le médicament BDPM depuis le cip13 (post-scan)
/// et délègue le rendu à [_MedicamentPreview]. 3 cas :
///   - cip13 + DB BDPM disponibles + match → preview rempli
///   - cip13 + DB indisponible OU pas de match → preview "non reconnu"
///   - pas de cip13 (saisie manuelle) → preview "saisie manuelle"
class _MedicamentPreviewSection extends ConsumerWidget {
  const _MedicamentPreviewSection({required this.cip13});

  final String? cip13;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cip13 == null) {
      return const _MedicamentPreview(
        title: 'Saisie manuelle',
        subtitle: 'Renseigne les informations ci-dessous',
        primary: 'Sans CIP scanné',
      );
    }
    // Lookup local d'abord, fallback API si pas de SQLite local
    // (cf. bdpmLookupProvider). Tant que la sync SQLite #78/#79 n'est
    // pas câblée, le fallback API est la seule source pour les CIP13
    // qu'on n'a jamais vus.
    final lookup = ref.watch(bdpmLookupProvider(cip13!));
    return lookup.when(
      loading: () => const _MedicamentPreview(
        title: 'Résolution…',
        subtitle: 'Recherche dans la base médicaments',
        primary: '',
      ),
      error: (_, _) => _unknownPreview(cip13: cip13!),
      data: (med) {
        if (med == null) return _unknownPreview(cip13: cip13!);
        return _MedicamentPreview(
          title: med.denomination,
          subtitle: _subtitleFor(med),
          primary: _primaryLineFor(med),
        );
      },
    );
  }

  static _MedicamentPreview _unknownPreview({required String cip13}) {
    return _MedicamentPreview(
      title: 'Médicament non reconnu',
      subtitle: 'CIP $cip13',
      primary: 'Tu peux quand même ajouter la boîte avec un nom manuel',
      muted: true,
    );
  }

  static String _subtitleFor(BdpmMedicament m) {
    final titulaire = m.titulaire;
    final dosage = m.dosage;
    if (titulaire != null && dosage != null) return '$dosage · $titulaire';
    return titulaire ?? dosage ?? '';
  }

  static String _primaryLineFor(BdpmMedicament m) {
    final forme = m.forme;
    final taux = m.tauxRemboursement;
    final remb = taux != null ? 'Remboursé $taux%' : 'Non remboursé';
    return forme != null ? '$forme · $remb' : remb;
  }
}

class _MedicamentPreview extends StatelessWidget {
  const _MedicamentPreview({
    required this.title,
    required this.subtitle,
    required this.primary,
    this.muted = false,
  });

  final String title;
  final String subtitle;
  final String primary;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bg = muted ? PilooColors.surfaceSubtle : PilooColors.primarySoft;
    final accent = muted ? PilooColors.textSecondary : PilooColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              muted ? PhosphorIconsRegular.question : PhosphorIconsFill.pill,
              size: 28,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                    ),
                  ),
                ],
                if (primary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    primary,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.text, this.leading, this.trailing});

  final String text;
  final Widget? leading;
  final Widget? trailing;

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
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StockChips extends StatelessWidget {
  const _StockChips({required this.value, required this.onChanged});

  final _StockLevel value;
  final ValueChanged<_StockLevel> onChanged;

  static const _options = [
    (_StockLevel.plein, 'Plein'),
    (_StockLevel.troisQuarts, '3/4'),
    (_StockLevel.moitie, 'Moitié'),
    (_StockLevel.unQuart, '1/4'),
    (_StockLevel.presqueVide, 'Presque vide'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: 'NIVEAU INITIAL',
      child: Row(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _StockChip(
                label: _options[i].$2,
                selected: value == _options[i].$1,
                onTap: () => onChanged(_options[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: selected ? PilooColors.primary : PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: selected ? null : Border.all(color: PilooColors.border),
        ),
        alignment: Alignment.center,
        // Padding horizontal pour que "Presque vide" tienne sans
        // overflow sur les viewports étroits.
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: label.length > 6 ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color:
                selected ? PilooColors.textOnPrimary : PilooColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _LotField extends StatelessWidget {
  const _LotField({required this.controller});

  final TextEditingController controller;

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
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PilooColors.textPrimary,
        ),
      ),
    );
  }
}

class _PeremptionPicker extends StatefulWidget {
  const _PeremptionPicker({
    required this.initialMonth,
    required this.initialYear,
    required this.months,
  });

  final int initialMonth;
  final int initialYear;
  final List<String> months;

  @override
  State<_PeremptionPicker> createState() => _PeremptionPickerState();
}

class _PeremptionPickerState extends State<_PeremptionPicker> {
  late int _month = widget.initialMonth;
  late int _year = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final years = List.generate(12, (i) => DateTime.now().year + i);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: PilooColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Center(
              child: Text(
                'Date de péremption',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPickerWheel(
                      items: [for (var i = 0; i < 12; i++) widget.months[i]],
                      initialIndex: _month - 1,
                      onChanged: (i) => setState(() => _month = i + 1),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPickerWheel(
                      items: years.map((y) => '$y').toList(),
                      initialIndex: years.indexOf(_year).clamp(0, years.length - 1),
                      onChanged: (i) => setState(() => _year = years[i]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PilooButton(
              label: 'Confirmer',
              variant: PilooButtonVariant.primary,
              onPressed: () =>
                  Navigator.of(context).pop((month: _month, year: _year)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-roulette type Cupertino. Bande primary-soft au centre pour
/// indiquer la sélection courante + item central rendu en primary
/// gras (les autres en text-tertiary plus léger).
class CupertinoPickerWheel extends StatefulWidget {
  const CupertinoPickerWheel({
    required this.items,
    required this.initialIndex,
    required this.onChanged,
    super.key,
  });

  final List<String> items;
  final int initialIndex;
  final ValueChanged<int> onChanged;

  @override
  State<CupertinoPickerWheel> createState() => _CupertinoPickerWheelState();
}

class _CupertinoPickerWheelState extends State<CupertinoPickerWheel> {
  late int _selected = widget.initialIndex;

  static const double _itemExtent = 36;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Bande primary-soft qui marque la zone de sélection. Le picker
        // est dessiné par-dessus pour que l'item central apparaisse
        // posé sur la bande.
        Container(
          height: _itemExtent,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: PilooColors.primarySoft,
            borderRadius: BorderRadius.circular(PilooRadius.md),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: FixedExtentScrollController(
            initialItem: widget.initialIndex,
          ),
          itemExtent: _itemExtent,
          perspective: 0.005,
          diameterRatio: 1.6,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) {
            setState(() => _selected = i);
            widget.onChanged(i);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.items.length,
            builder: (_, i) {
              final isSelected = i == _selected;
              return Center(
                child: Text(
                  widget.items[i],
                  style: GoogleFonts.manrope(
                    fontSize: isSelected ? 17 : 16,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? PilooColors.primary
                        : PilooColors.textTertiary,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OfficinePicker extends StatelessWidget {
  const _OfficinePicker({required this.current, required this.options});

  final String current;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: PilooColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Center(
              child: Text(
                'Choisir une officine',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...options.map((o) {
              final selected = o == current;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(o),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PilooColors.surface,
                    borderRadius: BorderRadius.circular(PilooRadius.md),
                    border: Border.all(
                      color: selected
                          ? PilooColors.primary
                          : PilooColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsFill.house,
                        size: 18,
                        color: selected
                            ? PilooColors.primary
                            : PilooColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          o,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: PilooColors.textPrimary,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          PhosphorIconsBold.check,
                          size: 16,
                          color: PilooColors.primary,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: 'NOTES (OPTIONNEL)',
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            hintText: 'Armoire salle de bain…',
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
    );
  }
}
