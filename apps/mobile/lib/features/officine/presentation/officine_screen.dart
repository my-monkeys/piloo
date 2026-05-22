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
      ),
    );
    if (action == null || !mounted) return;
    await _runAction(apiBoite, action);
  }

  Future<void> _runAction(api.Boite boite, QuickAction action) async {
    try {
      switch (action) {
        case QuickAction.markExpired:
          await updateBoite(
            ref,
            boiteId: boite.id,
            officineId: boite.officineId,
            statut: api.UpdateBoiteInputStatutEnum.perimee,
          );
          if (mounted) PilooToast.success(context, 'Marquée périmée.');
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
      }
    } catch (e) {
      if (mounted) PilooToast.error(context, 'Action échouée : $e');
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
                      // Bottom padding 140 = tab bar (~105) + safe area
                      // home indicator (extendBody: true côté _MainShell).
                      : _GroupedList(
                          sections: groupBoites(filtered, _grouping),
                          onBoiteTap: _onBoiteTap,
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
    // dci = juste le dosage maintenant que la forme est cachée. Si pas
    // de dosage non plus, on retombe sur le nom pour ne pas afficher vide.
    dci = bdpmHit.dosage ?? '';
    if (dci.isEmpty) dci = name;
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
  // Affiche "× N" devant le lot/CIP quand plusieurs boîtes physiques
  // partagent ce (cip13, lot). L'user voit d'un coup d'œil qu'il a un
  // stock multiplié sans qu'on touche aux compteurs unitesRestantes/
  // unitesInitiales (qui restent par boîte).
  final metaWithCount =
      b.nombreBoites > 1 ? '× ${b.nombreBoites} · $meta' : meta;
  return _Boite(
    name: name,
    dci: dci,
    meta: metaWithCount,
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
  const _SearchBox({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

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
  const _GroupedList({required this.sections, required this.onBoiteTap});

  final List<BoiteSection<_Boite>> sections;
  final void Function(_Boite boite) onBoiteTap;

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
        final boite = section.boites[i];
        items.add(GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onBoiteTap(boite),
          child: _BoiteCard(boite: boite),
        ));
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
    final lowest = t >= 4 ? 1 : 0;
    return [
      (label: 'Plein · $t', units: t),
      (label: '3/4 · ${((t * 3) / 4).round()}', units: ((t * 3) / 4).round()),
      (label: 'Moitié · ${(t / 2).round()}', units: (t / 2).round()),
      (label: '1/4 · ${(t / 4).round()}', units: (t / 4).round()),
      (label: 'Vide', units: lowest == 1 ? 1 : 0),
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
