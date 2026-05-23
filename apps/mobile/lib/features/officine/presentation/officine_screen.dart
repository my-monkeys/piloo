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
import 'dart:collection';

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
import 'package:piloo/features/inventory/presentation/quick_actions_sheet.dart';
import 'package:piloo/features/officine/data/grouping_pref.dart';
import 'package:piloo/features/officine/domain/boite_grouping.dart';
import 'package:piloo/features/officines/data/active_officine_provider.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';
import 'package:piloo/features/rappels/data/rappels_provider.dart';
import 'package:piloo/features/rappels/presentation/rappel_quick_sheet.dart';
import 'package:piloo/shared/api/api_client_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_db.dart';
import 'package:piloo/shared/bdpm/bdpm_lookup_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_medicament.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo/shared/widgets/bdpm_conflict_warning.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';
import 'package:piloo/shared/widgets/piloo_toast.dart';

enum _Filter { tout, actif, perime, stockBas }

enum _BoiteState { ok, stockBas, perime }

class _Boite implements GroupableBoite {
  const _Boite({
    required this.name,
    required this.dci,
    required this.meta,
    required this.icon,
    required this.count,
    this.total,
    this.exp,
    this.state = _BoiteState.ok,
    this.apiBoite,
  });

  @override
  final String name;
  @override
  final String dci;
  final String meta;
  final IconData icon;
  /// Doses restantes (unitesRestantes côté DB).
  final int count;
  /// Doses totales de la boîte (unitesInitiales). null quand l'user
  /// n'a pas renseigné la taille.
  final int? total;
  final String? exp; // ex: "exp. 08/2026" ou null si périmé
  final _BoiteState state;
  /// Référence à la Boite API quand la card provient de l'API (sinon
  /// fallback mock). Sert au tap → quick actions sheet → PATCH.
  final api.Boite? apiBoite;
}

class OfficineScreen extends ConsumerStatefulWidget {
  const OfficineScreen({super.key});

  @override
  ConsumerState<OfficineScreen> createState() => _OfficineScreenState();
}

class _OfficineScreenState extends ConsumerState<OfficineScreen> {
  _Filter _filter = _Filter.tout;
  BoiteGrouping _grouping = BoiteGrouping.medicament;
  /// Texte de recherche libre. Filtre name + dci + cip13 case-insensitive.
  /// Vide → toutes les boîtes affichées (modulo le filtre de statut).
  /// #100 : tap sur "Principe actif" depuis la fiche médicament viendra
  /// pré-remplir ce champ avec la DCI.
  String _searchQuery = '';

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

  /// Tap sur une card → bottom sheet d'actions rapides (#102/#103/#104).
  /// Sans `apiBoite` (fallback mock), tap est no-op.
  Future<void> _onBoiteTap(_Boite boite) async {
    final apiBoite = boite.apiBoite;
    if (apiBoite == null) return;
    final bdpmDb = ref.read(bdpmDbProvider).valueOrNull;
    final recognized = bdpmDb?.findByCip13(apiBoite.cip13) != null;
    final peremption = DateTime(
      apiBoite.peremption.year,
      apiBoite.peremption.month,
      apiBoite.peremption.day,
    );
    final action = await showQuickActionsSheet(
      context,
      info: QuickActionsContext(
        officineLabel: ref.read(activeOfficineProvider).valueOrNull?.nom ?? '',
        medicamentName: boite.name,
        cip13: apiBoite.cip13,
        recognizedFromBdpm: recognized,
        peremptionDate: peremption,
        substances: bdpmDb?.findByCip13(apiBoite.cip13)?.substances ?? const [],
      ),
    );
    if (action == null || !mounted) return;
    await _runAction(apiBoite, action);
  }

  Future<void> _runAction(api.Boite boite, QuickAction action) async {
    try {
      switch (action) {
        case QuickAction.adjustStock:
          final adjust = await _askStock(
            boite.unitesRestantes,
            boite.unitesInitiales,
            cip13: boite.cip13,
          );
          if (adjust == null || !mounted) return;
          // Quand le user sélectionne le chip "Vide" (restantes=0) on
          // bascule aussi le statut à 'vide' — sinon la boîte reste
          // "active" et l'icône/badge ne se mettent pas à jour. C'est
          // ce remplacement qui rend l'action séparée "Marquer comme
          // vide" inutile (cf. cleanup quick actions 2026-05-22).
          final markVide = adjust.restantes == 0;
          await updateBoite(
            ref,
            boiteId: boite.id,
            officineId: boite.officineId,
            unitesRestantes: adjust.restantes,
            unitesInitiales: adjust.totalUpdated,
            statut: markVide ? api.UpdateBoiteInputStatutEnum.vide : null,
          );
          if (mounted) {
            PilooToast.success(
              context,
              markVide ? 'Marquée vide.' : 'Stock mis à jour.',
            );
          }
        case QuickAction.reportMissing:
          final alertesApi = ref.read(pilooApiClientProvider).getAlertesApi();
          final input = api.SignalerManqueInputBuilder()
            ..cip13 = boite.cip13
            ..libelle = boite.cip13;
          final res = await alertesApi.v1OfficinesOfficineIdSignalerManquePost(
            officineId: boite.officineId,
            signalerManqueInput: input.build(),
          );
          if (!mounted) return;
          if (res.statusCode == 201 || res.statusCode == 200) {
            PilooToast.success(context, 'Manque signalé aux membres.');
          } else {
            PilooToast.error(context, 'Échec : statut ${res.statusCode ?? 0}');
          }
        case QuickAction.seeInfo:
          if (mounted) context.push(RoutePath.medicamentInfo(boite.cip13));
        case QuickAction.rename:
          await _runRename(boite);
        case QuickAction.addAnotherBox:
          // Ne devrait pas remonter ici : ce flow est réservé à
          // boite_add_screen post-scan-409. Depuis l'officine on accède
          // déjà à la boîte directement, "+1 boîte" passerait par
          // adjustStock ou un long-press. Garde-fou explicite pour
          // satisfaire l'exhaustivité du switch.
          break;
        case QuickAction.setRappel:
          await _runSetRappel(boite);
        case QuickAction.discard:
          await _runDiscard(boite);
      }
    } catch (e) {
      if (mounted) PilooToast.error(context, 'Action échouée : $e');
    }
  }

  /// "Jeter cette boîte" — soft-delete avec confirmation.
  /// Si `nombre_boites > 1`, décrémente le compteur au lieu de
  /// supprimer (cas où l'user a 3 boîtes du même lot et n'en jette
  /// qu'une).
  Future<void> _runDiscard(api.Boite boite) async {
    final nb = boite.nombreBoites;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nb > 1 ? 'Jeter une boîte ?' : 'Jeter cette boîte ?'),
        content: Text(
          nb > 1
              ? 'Tu as $nb boîtes de ce lot. On décrémente le compteur à ${nb - 1} ?'
              : 'Cette action retire la boîte de ton inventaire. Tu pourras la rescanner si besoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: PilooColors.error),
            child: Text(nb > 1 ? 'Décrémenter' : 'Jeter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (nb > 1) {
      await updateBoite(
        ref,
        boiteId: boite.id,
        officineId: boite.officineId,
        nombreBoites: nb - 1,
      );
      if (mounted) PilooToast.success(context, 'Une boîte retirée.');
    } else {
      await deleteBoite(
        ref,
        boiteId: boite.id,
        officineId: boite.officineId,
      );
      if (mounted) PilooToast.success(context, 'Boîte jetée.');
    }
  }

  /// Renomme une boîte en éditant le préfixe `NOM // notes` de la
  /// colonne `notes`. Sert principalement quand la boîte scannée n'est
  /// pas reconnue dans BDPM — au lieu d'afficher "CIP 3400…", l'user
  /// met le nom imprimé sur la boîte.
  Future<void> _runRename(api.Boite boite) async {
    final parts = _splitNotes(boite.notes);
    final currentName = parts.name ?? '';
    final newName = await _askRename(currentName);
    if (newName == null || !mounted) return;
    final trimmed = newName.trim();
    final newNotes = trimmed.isEmpty
        ? parts.rest // l'user efface le nom → on garde juste les notes libres
        : (parts.rest == null || parts.rest!.isEmpty
            ? trimmed
            : '$trimmed // ${parts.rest}');
    await updateBoite(
      ref,
      boiteId: boite.id,
      officineId: boite.officineId,
      notes: newNotes,
    );
    if (mounted) PilooToast.success(context, 'Renommée.');
  }

  /// Ouvre la modale "Rappel rapide" pour configurer matin/midi/soir/
  /// coucher × quantité sur ce médoc. POST /v1/officines/{id}/rappels.
  /// Pas de génération automatique des prises planifiées pour ce ship —
  /// l'user verra son rappel listé, les notifications viendront en suivi.
  Future<void> _runSetRappel(api.Boite boite) async {
    final bdpmDb = ref.read(bdpmDbProvider).valueOrNull;
    final bdpmHit = bdpmDb?.findByCip13(boite.cip13);
    final medName = bdpmHit != null
        ? _stripFormeSuffix(bdpmHit.denomination, bdpmHit.forme)
        : (_splitNotes(boite.notes).name ?? 'Médicament');
    final unite = bdpmHit?.doseUnit ?? 'comprimé';

    final result = await showRappelQuickSheet(
      context,
      medicamentName: medName,
      suggestedUnite: unite,
    );
    if (result == null || !mounted) return;

    final today = DateTime.now();
    await createRappel(
      ref,
      officineId: boite.officineId,
      cip13: boite.cip13,
      nomTexte: medName,
      unite: unite,
      quantiteMatin: result.matin,
      quantiteMidi: result.midi,
      quantiteSoir: result.soir,
      quantiteCoucher: result.coucher,
      dateDebut: api.Date(today.year, today.month, today.day),
    );
    if (mounted) PilooToast.success(context, 'Rappel créé.');
  }

  Future<String?> _askRename(String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PilooColors.surface,
        title: Text(
          'Renommer',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: PilooColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nom du médicament tel qu\'il apparaît sur la boîte.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: PilooColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'ex. Doliprane 1000 mg',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  /// Sheet de saisie du stock (#102 + #103). Combine :
  ///   - 5 chips "Plein / 3-4 / Moitié / 1-4 / Vide" pour estimation rapide
  ///   - un champ numérique pour comptage précis
  /// Quand `total` (= unitesInitiales) est connu, les chips affichent
  /// les doses correspondantes (3/4 d'une boîte de 8 = 6).
  Future<StockAdjustResult?> _askStock(
    int? current,
    int? total, {
    required String cip13,
  }) async {
    // bdpmLookupProvider plutôt que bdpmDb direct : le SQLite local
    // n'a pas forcément les colonnes enrichies (totalDoses/doseUnit/
    // container), or ces champs drivent les labels du sheet ("Comprimés
    // restants" vs "8 doses"). Le provider fait fallback API si la
    // version SQLite locale est trop ancienne.
    final presentation =
        await ref.read(bdpmLookupProvider(cip13).future).catchError((_) => null);
    if (!mounted) return null;
    return showModalBottomSheet<StockAdjustResult>(
      context: context,
      backgroundColor: PilooColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StockAdjustSheet(
        initial: current,
        total: total,
        presentation: presentation,
      ),
    );
  }


  List<_Boite> _filtered(List<_Boite> source) {
    final byStatut = switch (_filter) {
      _Filter.tout => source,
      _Filter.actif =>
        source.where((b) => b.state == _BoiteState.ok).toList(growable: false),
      _Filter.perime => source
          .where((b) => b.state == _BoiteState.perime)
          .toList(growable: false),
      _Filter.stockBas => source
          .where((b) => b.state == _BoiteState.stockBas)
          .toList(growable: false),
    };
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return byStatut;
    // En mode Molécule on filtre uniquement sur la DCI (les substances
    // actives jointes par ' + ') pour rester cohérent avec ce que
    // l'utilisateur voit dans la liste. Sinon on garde la recherche
    // large nom + dci + meta.
    if (_grouping == BoiteGrouping.molecule) {
      return byStatut
          .where((b) => b.dci.toLowerCase().contains(q))
          .toList(growable: false);
    }
    return byStatut
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.dci.toLowerCase().contains(q) ||
            b.meta.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final activeOfficineAsync = ref.watch(activeOfficineProvider);
    final activeOfficine = activeOfficineAsync.valueOrNull;
    final boitesAsync = activeOfficine == null
        ? const AsyncValue<List<api.Boite>>.data([])
        : ref.watch(boitesProvider(activeOfficine.id));
    // BDPM SQLite locale pour résoudre cip13 → denomination/dosage/forme
    // sans aller chercher la dénomination dans les notes (bug historique
    // où la card affichait "CIP 3400xxx" au lieu du nom).
    final bdpmDb = ref.watch(bdpmDbProvider).valueOrNull;
    final source = boitesAsync.maybeWhen(
      data: (rows) => rows
          // Boîtes vidées : on les retire de l'affichage — l'utilisateur
          // a marqué la boîte épuisée, plus aucune action utile dessus.
          // Elles restent en DB (historique, agrégats stock_bas).
          .where((b) => b.statut != api.BoiteStatutEnum.vide && (b.unitesRestantes ?? 1) > 0)
          .map((b) => _mapApiBoite(b, bdpmDb))
          .toList(growable: false),
      orElse: () => const <_Boite>[],
    );
    final isLoading = boitesAsync.isLoading && source.isEmpty;
    final filtered = _filtered(source);
    final perimeCount =
        source.where((b) => b.state == _BoiteState.perime).length;
    final stockBasCount =
        source.where((b) => b.state == _BoiteState.stockBas).length;

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
                  _OfficineSwitcher(
                    label: activeOfficine?.nom ?? 'Maison',
                    onTap: () => _showOfficineSwitcher(context, ref),
                  ),
                  Flexible(
                    child: Text(
                      '${source.length} boîte${source.length > 1 ? 's' : ''}',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: _SearchBox(
                value: _searchQuery,
                onChanged: (q) => setState(() => _searchQuery = q),
                hint: _grouping == BoiteGrouping.molecule
                    ? 'Rechercher une molécule…'
                    : 'Rechercher un médicament…',
              ),
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
                    label: 'Tout · ${source.length}',
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
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : source.isEmpty
                      ? _EmptyOfficine()
                      : _grouping == BoiteGrouping.molecule
                          // Vue inversée par molécule : 1 card par
                          // substance active présente dans les boîtes.
                          // Tap → drill-down sur les médocs qui la
                          // contiennent.
                          ? _MoleculeList(
                              boites: filtered,
                              bdpmDb: bdpmDb,
                              onBoiteTap: _onBoiteTap,
                            )
                          : _GroupedList(
                              sections: groupBoites(filtered, _grouping),
                              onBoiteTap: _onBoiteTap,
                              // Carousel par CIP seulement en mode
                              // Médicament.
                              stackByCip:
                                  _grouping == BoiteGrouping.medicament,
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mappe une `Boite` API → modèle d'affichage local.
///
/// Stratégie d'affichage du nom (priorité décroissante) :
///   1. BDPM SQLite locale (instantané, offline) : `denomination` →
///      meilleure source, donne aussi forme + dosage pour la `meta`.
///   2. Préfixe historique des notes (`NOM // notes libres`) — convention
///      utilisée par le scan-flow avant que la BDPM mobile soit dispo.
///   3. Fallback `CIP {cip13}` si rien d'autre.
///
/// Sans BDPM locale (avant 1er sync) ou cip13 hors base (médoc rare),
/// on retombe sur 2 ou 3.
_Boite _mapApiBoite(api.Boite b, BdpmDb? bdpm) {
  final parts = _splitNotes(b.notes);

  String name;
  String dci;
  String meta;
  final bdpmHit = bdpm?.findByCip13(b.cip13);
  if (bdpmHit != null) {
    // BDPM denomination = "DOLIPRANE 1000 mg, comprimé pelliculé".
    // On retire le suffixe ", <forme>" pour ne garder que le nom + dosage
    // dans la card officine — la forme reviendra comme icône (#98 follow-up).
    name = _stripFormeSuffix(bdpmHit.denomination, bdpmHit.forme);
    // dci = molécules actives BDPM (déjà triées côté serveur), concat
    // pour devenir une clé de groupement stable. Augmentin → "AMOXICILLINE
    // TRIHYDRATÉE + CLAVULANATE DE POTASSIUM". Permet à 2 Doliprane
    // de marques différentes de tomber sous la même clé "PARACÉTAMOL".
    // Fallback dosage si CIS_COMPO ne connait pas le médoc (rare).
    if (bdpmHit.substances.isNotEmpty) {
      dci = bdpmHit.substances.join(' + ');
    } else {
      dci = bdpmHit.dosage ?? name;
    }
    meta = b.lot != null ? 'lot ${b.lot}' : 'CIP ${b.cip13}';
  } else if (parts.name != null) {
    name = parts.name!;
    dci = name;
    meta = 'CIP ${b.cip13}';
  } else {
    name = 'CIP ${b.cip13}';
    dci = name;
    meta = b.lot != null ? 'lot ${b.lot}' : '—';
  }

  final state = _deriveState(b);
  final exp = state == _BoiteState.perime
      ? null
      : _formatPeremption(b.peremption);
  // Le multi-boîtes est signalé par un badge numérique sur l'icône
  // dans _BoiteCard (cf. nombreBoites depuis apiBoite). Pas de
  // duplication dans meta — la card reste lisible.
  return _Boite(
    name: name,
    dci: dci,
    meta: meta,
    icon: _iconForForme(bdpmHit?.forme),
    count: b.unitesRestantes ?? 1,
    total: b.unitesInitiales,
    exp: exp,
    state: state,
    apiBoite: b,
  );
}

/// Mappe la `forme` BDPM (texte libre) → icône Phosphor. Match par
/// keyword pour absorber les variations ("comprimé pelliculé",
/// "gélule gastro-résistant", etc.). Tout ce qui n'est pas reconnu
/// retombe sur `pill` — choix neutre qui marche pour la majorité des
/// formes solides ingérables.
IconData _iconForForme(String? forme) {
  if (forme == null || forme.isEmpty) return PhosphorIconsFill.pill;
  final f = forme.toLowerCase();
  // Ordre : du plus spécifique au plus générique pour éviter qu'une
  // forme rare se fasse capter par un mot trop large.
  if (f.contains('collyre') || f.contains('goutte')) return PhosphorIconsFill.eyedropper;
  if (f.contains('inhalation') || f.contains('aérosol') || f.contains('aerosol')) return PhosphorIconsFill.wind;
  if (f.contains('pulvérisation') || f.contains('pulverisation') || f.contains('spray')) {
    return PhosphorIconsFill.sprayBottle;
  }
  if (f.contains('suppositoire') || f.contains('ovule')) return PhosphorIconsFill.rocketLaunch;
  if (f.contains('transdermique') || f.contains('patch')) return PhosphorIconsFill.bandaids;
  if (f.contains('injectable') || f.contains('perfusion')) return PhosphorIconsFill.syringe;
  if (f.contains('crème') || f.contains('creme') || f.contains('gel') ||
      f.contains('pommade') || f.contains('application')) {
    return PhosphorIconsFill.handSoap;
  }
  if (f.contains('buvable') || f.contains('sirop') || f.contains('suspension')) {
    return PhosphorIconsFill.flask;
  }
  // Comprimé, gélule, capsule, suppositoire, ovule, dispositif… → pill
  // (phosphor 2.1.0 n'expose pas de `capsule` dédié, on garde pill pour
  // tous les solides).
  return PhosphorIconsFill.pill;
}

/// Retire le suffixe `, $forme` de la dénomination BDPM. Robust à la
/// casse et aux variations subtiles de la BDPM. Si on ne match pas, on
/// renvoie la dénomination intacte plutôt que d'inventer une troncature
/// approximative — mieux vaut un nom long qu'un nom faux.
String _stripFormeSuffix(String denomination, String? forme) {
  if (forme == null || forme.isEmpty) return denomination;
  final suffix = ', $forme';
  final lower = denomination.toLowerCase();
  if (lower.endsWith(suffix.toLowerCase())) {
    return denomination.substring(0, denomination.length - suffix.length).trim();
  }
  return denomination;
}

({String? name, String? rest}) _splitNotes(String? raw) {
  if (raw == null || raw.isEmpty) return (name: null, rest: null);
  final idx = raw.indexOf(' // ');
  if (idx <= 0) return (name: null, rest: raw);
  return (name: raw.substring(0, idx), rest: raw.substring(idx + 4));
}

_BoiteState _deriveState(api.Boite b) {
  if (b.statut == api.BoiteStatutEnum.perimee) return _BoiteState.perime;
  // Périmée d'office si la date est passée — sans attendre que le cron
  // ait mis à jour le statut côté serveur.
  final exp = DateTime(b.peremption.year, b.peremption.month, b.peremption.day);
  if (exp.isBefore(DateTime.now())) return _BoiteState.perime;
  if ((b.unitesRestantes ?? 99) <= 1) return _BoiteState.stockBas;
  return _BoiteState.ok;
}

String _formatPeremption(api.Date d) {
  final m = d.month.toString().padLeft(2, '0');
  return 'exp. $m/${d.year}';
}

Future<void> _showOfficineSwitcher(BuildContext context, WidgetRef ref) async {
  final list = ref.read(officinesListProvider).value ?? const [];
  final activeId = ref.read(activeOfficineProvider).value?.id;
  if (list.isEmpty) return;
  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: PilooColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
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
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'CHOISIR UNE OFFICINE',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: PilooColors.textTertiary,
                ),
              ),
            ),
            ...list.map((o) {
              final isActive = o.id == activeId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(o.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: PilooColors.surface,
                      borderRadius: BorderRadius.circular(PilooRadius.md),
                      border: Border.all(
                        color: isActive
                            ? PilooColors.primary
                            : PilooColors.border,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsFill.house,
                          size: 18,
                          color: PilooColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            o.nom,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PilooColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isActive)
                          const Icon(
                            PhosphorIconsFill.checkCircle,
                            size: 18,
                            color: PilooColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
  if (picked != null && picked != activeId) {
    await ref.read(activeOfficineProvider.notifier).select(picked);
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

class _SearchBox extends StatefulWidget {
  const _SearchBox({
    required this.value,
    required this.onChanged,
    this.hint = 'Rechercher…',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_SearchBox old) {
    super.didUpdateWidget(old);
    // Sync externe (ex: pré-remplissage par tap DCI) — on évite la
    // boucle infinie en comparant le texte avant set.
    if (widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
              controller: _ctrl,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: widget.hint,
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
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  PhosphorIconsRegular.xCircle,
                  size: 16,
                  color: PilooColors.textTertiary,
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

  // "Toutes" (plat) retiré 2026-05-23 — peu d'utilité face aux 2 modes
  // structurés. La logique BoiteGrouping.plat reste en domaine pour
  // compat tests, on ne l'expose juste plus à l'UI.
  static const _options = [
    (mode: BoiteGrouping.medicament, label: 'Médicament'),
    (mode: BoiteGrouping.molecule, label: 'Molécule'),
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
  const _GroupedList({
    required this.sections,
    required this.onBoiteTap,
    this.stackByCip = false,
  });

  final List<BoiteSection<_Boite>> sections;
  final void Function(_Boite boite) onBoiteTap;
  /// Quand `true`, regroupe les boîtes du même CIP en une card
  /// swipeable horizontale (1 page par lot). Désactivé pour les
  /// modes molécule/plat où l'user attend une liste à plat.
  final bool stackByCip;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (section.header != null) {
        if (s > 0) items.add(const SizedBox(height: 8));
        // Total des boîtes physiques (somme des nombre_boites). Sert
        // au badge "× N" du header — affiché seulement si > 1.
        final totalBoites = section.boites.fold<int>(
          0,
          (acc, b) => acc + (b.apiBoite?.nombreBoites ?? 1),
        );
        items.add(_SectionHeader(
          label: section.header!,
          boiteCount: totalBoites,
        ));
        items.add(const SizedBox(height: 8));
      } else if (s > 0) {
        items.add(const SizedBox(height: 10));
      }
      final renderable = stackByCip
          ? _groupSameCip(section.boites)
          : section.boites.map((b) => [b]).toList();
      for (var i = 0; i < renderable.length; i++) {
        if (i > 0) items.add(const SizedBox(height: 10));
        final group = renderable[i];
        // Compte le nombre de cards physiques rendues (= somme des
        // nombre_boites). Si > 1 → mode pile, sinon card classique.
        // Permet une seule boîte avec nombre_boites=2 d'être pile aussi
        // (matérialise les 2 boîtes physiques en 2 cards distinctes).
        final physical = group.fold<int>(
          0,
          (acc, b) => acc + (b.apiBoite?.nombreBoites ?? 1),
        );
        if (physical <= 1) {
          final boite = group.first;
          items.add(GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onBoiteTap(boite),
            child: _BoiteCard(boite: boite),
          ));
        } else {
          items.add(_BoiteStackCard(boites: group, onTap: onBoiteTap));
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: items,
    );
  }
}

/// Regroupe les boîtes consécutives du même cip13. Préserve l'ordre
/// d'origine et la stabilité : 2 paires séparées par un autre CIP
/// restent 2 paires (pas de fusion à distance).
List<List<_Boite>> _groupSameCip(List<_Boite> boites) {
  final groups = <List<_Boite>>[];
  for (final b in boites) {
    final cip = b.apiBoite?.cip13;
    if (groups.isNotEmpty &&
        cip != null &&
        groups.last.first.apiBoite?.cip13 == cip) {
      groups.last.add(b);
    } else {
      groups.add([b]);
    }
  }
  return groups;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.boiteCount = 0});

  final String label;
  /// Nombre total de boîtes physiques du groupe. 0 ou 1 → pas de
  /// badge (pas d'info utile). 2+ → badge "× N" pour signaler que
  /// le groupe contient plusieurs boîtes (utile dans le mode
  /// carrousel par CIP).
  final int boiteCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = boiteCount > 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: PilooColors.textTertiary,
            ),
          ),
        ),
        if (showBadge) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PilooColors.border),
            ),
            child: Text(
              '× $boiteCount',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PilooColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Vue "Molécule" inversée : 1 card par substance active présente
/// dans l'officine, tap → expand → liste des médocs qui contiennent
/// cette substance (y compris les combinaisons type Augmentin qui
/// apparaît à la fois sous AMOXICILLINE et CLAVULANATE).
class _MoleculeList extends StatefulWidget {
  const _MoleculeList({
    required this.boites,
    required this.bdpmDb,
    required this.onBoiteTap,
  });

  final List<_Boite> boites;
  final BdpmDb? bdpmDb;
  final void Function(_Boite boite) onBoiteTap;

  @override
  State<_MoleculeList> createState() => _MoleculeListState();
}

class _MoleculeListState extends State<_MoleculeList> {
  final Set<String> _expanded = <String>{};

  /// Map molécule → boîtes qui la contiennent. Une boîte avec 2 SA
  /// (Augmentin = amox+clav) apparaît dans 2 entrées. Tri alpha pour
  /// stabilité de l'affichage.
  Map<String, List<_Boite>> _index() {
    final out = SplayTreeMap<String, List<_Boite>>();
    for (final b in widget.boites) {
      final api = b.apiBoite;
      if (api == null) continue;
      final hit = widget.bdpmDb?.findByCip13(api.cip13);
      final subs = hit?.substances ?? const <String>[];
      if (subs.isEmpty) {
        // Fallback : groupe "Autres" pour les médocs hors CIS_COMPO
        out.putIfAbsent('— Sans molécule connue —', () => []).add(b);
        continue;
      }
      for (final s in subs) {
        out.putIfAbsent(s, () => []).add(b);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index();
    if (index.isEmpty) return _EmptyOfficine();
    final keys = index.keys.toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final mol = keys[i];
        final boites = index[mol]!;
        final isOpen = _expanded.contains(mol);
        return Padding(
          padding: EdgeInsets.only(bottom: i == keys.length - 1 ? 0 : 10),
          child: _MoleculeCard(
            molecule: mol,
            count: boites.length,
            isOpen: isOpen,
            onToggle: () => setState(() {
              if (isOpen) {
                _expanded.remove(mol);
              } else {
                _expanded.add(mol);
              }
            }),
            boites: boites,
            onBoiteTap: widget.onBoiteTap,
          ),
        );
      },
    );
  }
}

class _MoleculeCard extends StatelessWidget {
  const _MoleculeCard({
    required this.molecule,
    required this.count,
    required this.isOpen,
    required this.onToggle,
    required this.boites,
    required this.onBoiteTap,
  });

  final String molecule;
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<_Boite> boites;
  final void Function(_Boite) onBoiteTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(
          color: isOpen ? PilooColors.primary : PilooColors.border,
          width: isOpen ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          molecule,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PilooColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count boîte${count > 1 ? 's' : ''}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: PilooColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: isOpen ? 0.5 : 0,
                    child: const Icon(
                      PhosphorIconsRegular.caretDown,
                      size: 18,
                      color: PilooColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1, color: PilooColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                children: [
                  for (var j = 0; j < boites.length; j++) ...[
                    if (j > 0) const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onBoiteTap(boites[j]),
                      child: _BoiteCard(boite: boites[j]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carousel circulaire de cards — 1 card = 1 boîte physique. Pattern
/// CodePen partagé par l'user 2026-05-23 : 3 cards visibles à un
/// instant T (current + 2 derrière, décalées vers le bas), swipe
/// horizontal → la current glisse hors écran, les behind remontent
/// progressivement pour prendre la place. Animation continue (pas
/// un setState après coup).
/// Carrousel circulaire des boîtes d'un même CIP. Pattern "deck de
/// cartes" : la top est au-dessus, les suivantes sont empilées en
/// dessous (couches Z), décalées vers la droite pour qu'on voie
/// leur bord. On swipe la top vers la gauche → elle quitte, la
/// behind1 prend sa place, behind2 prend la place de behind1, etc.
/// Inspiré du CodePen `aybukeceylan/RwrRPoO`.
class _BoiteStackCard extends StatefulWidget {
  const _BoiteStackCard({required this.boites, required this.onTap});

  final List<_Boite> boites;
  final void Function(_Boite boite) onTap;

  @override
  State<_BoiteStackCard> createState() => _BoiteStackCardState();
}

class _BoiteStackCardState extends State<_BoiteStackCard>
    with SingleTickerProviderStateMixin {
  late final List<_Boite> _pages = _expandByNombreBoites(widget.boites);
  final GlobalKey _measureKey = GlobalKey();
  int _topIndex = 0;
  double _dragX = 0;
  double? _cardHeight;
  late final AnimationController _ac;

  // Décalage horizontal de chaque card derrière (en px) — visible à
  // droite de la top. depth 1 = +18, depth 2 = +36.
  static const double _stepX = 18;
  // Réduction d'échelle par niveau de profondeur (scale-down).
  static const double _stepScale = 0.05;

  static List<_Boite> _expandByNombreBoites(List<_Boite> boites) {
    final out = <_Boite>[];
    for (final b in boites) {
      final nb = b.apiBoite?.nombreBoites ?? 1;
      for (var i = 0; i < nb; i++) {
        out.add(b);
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    WidgetsBinding.instance.addPostFrameCallback(_measureCard);
  }

  void _measureCard(Duration _) {
    final ctx = _measureKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if (_cardHeight != h) {
      setState(() => _cardHeight = h);
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _dragX += d.delta.dx);
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.2;
    final velocity = d.velocity.pixelsPerSecond.dx;
    final goNext = (_dragX < -threshold || velocity < -400) &&
        _topIndex < _pages.length - 1;
    final goPrev = (_dragX > threshold || velocity > 400) && _topIndex > 0;

    if (goNext) {
      await _animateTo(-width);
      if (!mounted) return;
      setState(() {
        _topIndex++;
        _dragX = 0;
      });
    } else if (goPrev) {
      await _animateTo(width);
      if (!mounted) return;
      setState(() {
        _topIndex--;
        _dragX = 0;
      });
    } else {
      await _animateTo(0);
      if (!mounted) return;
      setState(() => _dragX = 0);
    }
  }

  Future<void> _animateTo(double target) async {
    final start = _dragX;
    _ac.reset();
    final anim = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeOut),
    );
    void listener() => setState(() => _dragX = anim.value);
    anim.addListener(listener);
    try {
      await _ac.forward();
    } finally {
      anim.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-mesure à chaque build : la hauteur peut changer si la
    // largeur disponible (donc le wrap du titre) change, ou si on
    // hot-reload sans hot-restart. Idempotent → pas de boucle.
    WidgetsBinding.instance.addPostFrameCallback(_measureCard);
    final width = MediaQuery.of(context).size.width;
    final progress = (_dragX / width).clamp(-1.0, 1.0);

    final cardH = _cardHeight ?? 100;
    // Pas de padding latéral — les behind débordent dans le padding
    // de la ListView parente (16 px) grâce à clipBehavior: Clip.none.
    // La top card prend toute la largeur disponible.
    final stackHeight = cardH + 4;

    // Liste des offsets relatifs à afficher derrière (gauche = négatif,
    // droite = positif). Ordre du plus loin vers le plus proche pour
    // le Z-order (derrière = dessiné d'abord).
    const relativeOffsets = [-2, 2, -1, 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: stackHeight,
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap(_pages[_topIndex]),
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Mesure offscreen (pas dessinée).
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -9999,
                    child: KeyedSubtree(
                      key: _measureKey,
                      child: _BoiteCard(
                        boite: _pages.first,
                        suppressMultiBadge: true,
                      ),
                    ),
                  ),
                  // Cards behind (de chaque côté), ordre Z géré par
                  // l'ordre de relativeOffsets ci-dessus.
                  for (final r in relativeOffsets)
                    if (_topIndex + r >= 0 && _topIndex + r < _pages.length)
                      _buildLayer(
                        boite: _pages[_topIndex + r],
                        relative: r,
                        progress: progress,
                      ),
                  // Top card — suit le doigt.
                  Transform.translate(
                    offset: Offset(_dragX, 0),
                    child: Transform.rotate(
                      angle: progress * 0.05,
                      alignment: Alignment.center,
                      child: _BoiteCard(
                        boite: _pages[_topIndex],
                        suppressMultiBadge: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final active = i == _topIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? PilooColors.primary : PilooColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Layer "behind" à la position relative `relative` (négatif =
  /// gauche, positif = droite). Pendant un swipe, l'effective offset
  /// devient `relative + progress` — toutes les cards glissent
  /// ensemble dans le sens du doigt.
  Widget _buildLayer({
    required _Boite boite,
    required int relative,
    required double progress,
  }) {
    // Position effective pendant le swipe : tout glisse de `progress`.
    // Ex: swipe LEFT (progress=-1) → la card à r=+1 va à r=0 (centre).
    final effective = relative + progress;
    final absEff = effective.abs();
    final x = _stepX * effective;
    final scale = 1.0 - _stepScale * absEff;
    // Plus la card est loin (|effective| grand), plus elle s'efface.
    final opacity = (1.0 - 0.25 * absEff).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(x, 0),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: _BoiteCard(boite: boite, suppressMultiBadge: true),
          ),
        ),
      ),
    );
  }
}

/// Icône de la card boîte avec un badge "× N" en haut-droite quand
/// l'user a plusieurs boîtes physiques du même lot. Pattern iOS
/// classique (notification badge) : repérable d'un coup d'œil sans
/// surcharger le contenu textuel.
class _BoiteIconWithBadge extends StatelessWidget {
  const _BoiteIconWithBadge({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.nombreBoites,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final int nombreBoites;

  @override
  Widget build(BuildContext context) {
    final showBadge = nombreBoites > 1;
    // `clipBehavior: none` indispensable pour que le badge déborde du
    // Container 44×44 sans être tronqué.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(PilooRadius.md),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: iconFg),
        ),
        if (showBadge)
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PilooColors.accent,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(11),
                // Bord en background couleur pour découper visuellement
                // le badge de la card (effet "collé par-dessus").
                border: Border.all(color: PilooColors.background, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '×$nombreBoites',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BoiteCard extends StatelessWidget {
  const _BoiteCard({required this.boite, this.suppressMultiBadge = false});

  final _Boite boite;
  /// Quand la card est rendue à l'intérieur d'un `_BoiteStackCard`,
  /// chaque boîte physique est déjà matérialisée en une card distincte
  /// — le badge "× N" devient redondant.
  final bool suppressMultiBadge;

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
          _BoiteIconWithBadge(
            icon: boite.icon,
            iconBg: iconBg,
            iconFg: iconFg,
            // Badge "× N" affiché uniquement quand l'user a plusieurs
            // boîtes physiques du même lot (cf. nombreBoites > 1).
            // Caché en mode pile (les cards sont déjà dupliquées).
            nombreBoites: suppressMultiBadge
                ? 1
                : (boite.apiBoite?.nombreBoites ?? 1),
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
                  // Affiche "6/8" si la taille est connue, sinon juste "6".
                  // Plus parlant qu'un nombre seul (on voit où on en est).
                  boite.total != null ? '${boite.count}/${boite.total}' : '${boite.count}',
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

class _EmptyOfficine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.pill,
              size: 48,
              color: PilooColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune boîte dans cette officine',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scanne une boîte ou ajoute-la manuellement avec le bouton + de la barre du bas.',
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
}

/// Résultat de l'ajustement : nouvelle valeur de stock + (optionnellement)
/// taille totale renseignée à cette occasion. La taille est remontée pour
/// que l'écran appelant fasse un PATCH `unites_initiales` en plus du PATCH
/// `unites_restantes` — au prochain ajustement les chips fractionnels
/// seront corrects sans re-demander la taille.
class StockAdjustResult {
  const StockAdjustResult({required this.restantes, this.totalUpdated});
  final int restantes;
  final int? totalUpdated;
}

class _StockAdjustSheet extends StatefulWidget {
  const _StockAdjustSheet({
    required this.initial,
    this.total,
    this.presentation,
  });

  /// Stock actuel (= unitesRestantes courant).
  final int? initial;
  /// Taille totale connue (= unitesInitiales). Quand renseignée, les chips
  /// calculent des doses correctes (3/4 d'une boîte de 8 = 6). Quand
  /// inconnue, on prompte l'user pour la saisir avant d'afficher les chips
  /// — sinon les "Plein/3/4" affichent n'importe quoi (cf. bug remonté
  /// 2026-05-22 : Plein → 32 sur une boîte de Doliprane 8).
  final int? total;
  /// Médicament BDPM associé (résolu via bdpmLookupProvider). Quand
  /// fourni : on pré-remplit le champ "Taille de la boîte" avec
  /// `presentation.totalDoses`, et on adapte tous les labels du sheet
  /// à `doseUnit/doseUnitPlural` (Comprimés vs ml vs Sachets).
  final BdpmMedicament? presentation;

  @override
  State<_StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends State<_StockAdjustSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial?.toString() ?? '');
  late final TextEditingController _totalCtrl =
      TextEditingController(
        // Priorité : valeur déjà en DB > donnée BDPM > vide.
        text: (widget.total ?? widget.presentation?.totalDoses)?.toString() ?? '',
      );

  /// Taille active = soit ce que l'user vient de saisir, soit ce que la
  /// boîte avait déjà en base.
  int? get _effectiveTotal {
    final raw = _totalCtrl.text.trim();
    if (raw.isEmpty) return widget.total;
    final n = int.tryParse(raw);
    if (n == null || n <= 0) return widget.total;
    return n;
  }

  /// Vrai si l'user a saisi un total qui diffère de celui de la boîte —
  /// on remontera alors la valeur pour persister `unitesInitiales`.
  bool get _totalChanged {
    final t = _effectiveTotal;
    return t != null && t != widget.total;
  }

  /// Wording dynamique selon `presentation` BDPM. Tombe sur des libellés
  /// génériques quand le médoc n'est pas BDPM-résolu (cas du scan inconnu
  /// ou des médocs hors BDPM). Concentre toute la pluralisation/casse
  /// ici pour ne pas la disperser dans le widget tree.
  String get _dosePlural => widget.presentation?.doseUnitPlural ?? 'comprimés';
  String get _containerWord => widget.presentation?.container ?? 'boîte';

  String get _titleLabel {
    // "Comprimés restants" / "ml restants" / "Sachets restants"
    final p = _dosePlural;
    return '${p[0].toUpperCase()}${p.substring(1)} restants';
  }

  String get _subtitleLabel {
    final examples = widget.presentation?.doseUnit != null
        ? _dosePlural
        : 'comprimés, gélules, sachets, ml…';
    return 'Combien il reste dans cette $_containerWord ($examples).';
  }

  String get _nbExactLabel => 'Nombre exact';
  String get _nbExactHint {
    final remaining = widget.presentation?.totalDoses != null
        ? (widget.presentation!.totalDoses! ~/ 2)
        : 14;
    return 'ex. $remaining';
  }

  /// Chips fractionnels uniquement quand le total est connu (saisi ou
  /// déjà en base). Aucune valeur "fallback" hardcodée : un Plein sur
  /// boîte de 8 doit valoir 8, pas 32.
  List<({String label, int units})> get _chips {
    final t = _effectiveTotal;
    if (t == null || t <= 0) return const [];
    return [
      (label: 'Plein · $t', units: t),
      (label: '3/4 · ${((t * 3) / 4).round()}', units: ((t * 3) / 4).round()),
      (label: 'Moitié · ${(t / 2).round()}', units: (t / 2).round()),
      (label: '1/4 · ${(t / 4).round()}', units: (t / 4).round()),
      (label: 'Vide', units: 0),
    ];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final n = int.tryParse(_ctrl.text.trim());
    if (n == null || n < 0) return;
    Navigator.of(context).pop(
      StockAdjustResult(
        restantes: n,
        totalUpdated: _totalChanged ? _effectiveTotal : null,
      ),
    );
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
                _titleLabel,
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitleLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: PilooColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // Affiche "Doliprane 1000 mg · 8 comprimés [✏️]" en info-row
              // tappable quand la taille est connue (BDPM ou déjà saisie
              // pour cette boîte). Sinon affiche le TextField pour la
              // saisir. Au tap édition, le TextField réapparaît.
              _PresentationRow(
                presentation: widget.presentation,
                totalCtrl: _totalCtrl,
                effectiveTotal: _effectiveTotal,
                onTotalChanged: () => setState(() {}),
              ),
              if (_chips.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Renseigne la taille pour activer les raccourcis Plein / 3/4 / Moitié.',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: PilooColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_chips.isNotEmpty) Row(
                children: [
                  for (var i = 0; i < _chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _ctrl.text = _chips[i].units.toString();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: PilooColors.surface,
                            borderRadius: BorderRadius.circular(PilooRadius.md),
                            border: Border.all(color: PilooColors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _chips[i].label,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PilooColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _nbExactLabel,
                  hintText: _nbExactHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
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
                      child: const Text('Enregistrer'),
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

/// Bloc d'info-row tappable affichant "Doliprane 1000 mg · 8 comprimés"
/// dans l'_StockAdjustSheet. Au tap : déplie un TextField pour corriger
/// la taille (cas où le BDPM est faux ou que la boîte a été reconditionnée).
///
/// Quand la taille est inconnue (pas de BDPM + pas saisie précédemment),
/// on affiche direct le TextField — sinon l'user serait coincé sans pouvoir
/// renseigner la taille la 1ère fois.
class _PresentationRow extends StatefulWidget {
  const _PresentationRow({
    required this.presentation,
    required this.totalCtrl,
    required this.effectiveTotal,
    required this.onTotalChanged,
  });

  final BdpmMedicament? presentation;
  final TextEditingController totalCtrl;
  final int? effectiveTotal;
  final VoidCallback onTotalChanged;

  @override
  State<_PresentationRow> createState() => _PresentationRowState();
}

class _PresentationRowState extends State<_PresentationRow> {
  bool _editing = false;

  String _displayLine() {
    final med = widget.presentation;
    final t = widget.effectiveTotal;
    if (med == null) return t != null ? '$t doses' : '';
    final parts = <String>[];
    parts.add(med.denomination.split(',').first.trim());
    if (med.dosage != null && med.dosage!.isNotEmpty) {
      if (!parts.first.contains(med.dosage!)) parts.add(med.dosage!);
    }
    if (t != null) {
      final unit = (t > 1
              ? (med.doseUnitPlural ?? 'doses')
              : (med.doseUnit ?? 'dose'));
      parts.add('$t $unit');
    }
    return parts.join(' · ');
  }

  /// Vrai si la taille saisie diverge de celle officielle BDPM (l'user
  /// a peut-être reconditionné ou la BDPM est obsolète — on l'avertit
  /// avec un petit chevron sans bloquer le save).
  bool get _conflictsWithBdpm {
    final bdpm = widget.presentation?.totalDoses;
    final t = widget.effectiveTotal;
    return bdpm != null && t != null && bdpm != t;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.effectiveTotal;
    final hasKnownTotal = t != null && t > 0;
    if (_editing || !hasKnownTotal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.totalCtrl,
            keyboardType: TextInputType.number,
            autofocus: _editing,
            onChanged: (_) => widget.onTotalChanged(),
            onSubmitted: (_) => setState(() => _editing = false),
            decoration: InputDecoration(
              labelText: hasKnownTotal
                  ? 'Taille de la boîte'
                  : 'Saisir la taille de la boîte (doses)',
              hintText: hasKnownTotal ? null : 'ex. 8',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_conflictsWithBdpm) BdpmConflictWarning(
            officialTotal: widget.presentation!.totalDoses!,
            unitPlural: widget.presentation?.doseUnitPlural ?? 'doses',
            onReset: () {
              widget.totalCtrl.text =
                  widget.presentation!.totalDoses!.toString();
              widget.onTotalChanged();
            },
          ),
        ],
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(PilooRadius.md),
      onTap: () => setState(() => _editing = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PilooColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.pill,
              size: 18,
              color: PilooColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayLine(),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              PhosphorIconsRegular.pencilSimple,
              size: 14,
              color: PilooColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
