// Fixtures Dart hardcodées pour le mode démo (#351).
//
// Pas d'appel API ici — on construit des `api.Boite`, `api.Rappel`, etc.
// avec les builders du client généré, avec des IDs synthétiques stables.
// Le but est de remplir les écrans pendant le tour guidé pour montrer
// du contenu réaliste sans toucher la prod.
//
// Convention : tous les IDs UUID v4 commencent par `00000000-0000-4000`
// (RFC 4122 valide) — facile à filtrer pour debug.
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:piloo_api_client/piloo_api_client.dart' as api;

const String demoOfficineId = '00000000-0000-4000-8000-000000000001';
const String demoUserId = '00000000-0000-4000-8000-000000000002';

/// Boîtes pré-remplies — 5 médocs courants. La diversité couvre :
/// Levothyrox (chronique, 1×/j matin), Doliprane (à la demande),
/// Augmentin (cure courte avec stock bas), Ventoline (spray),
/// Spasfon (gélules).
List<api.Boite> demoBoites() {
  final now = DateTime.now().toUtc();
  return [
    _boite(
      id: '00000000-0000-4000-8000-000000000101',
      cip13: '3400930146675',
      lot: 'L2026A',
      peremption: api.Date(2026, 11, 30),
      unitesInitiales: 90,
      unitesRestantes: 60,
      nombreBoites: 1,
      now: now,
    ),
    _boite(
      id: '00000000-0000-4000-8000-000000000102',
      cip13: '3400935955838',
      lot: 'DOL2027',
      peremption: api.Date(2027, 8, 1),
      unitesInitiales: 16,
      unitesRestantes: 12,
      nombreBoites: 2,
      now: now,
    ),
    _boite(
      id: '00000000-0000-4000-8000-000000000103',
      cip13: '3400934567890',
      lot: 'AUG2026',
      peremption: api.Date(2027, 4, 1),
      unitesInitiales: 24,
      unitesRestantes: 6,
      nombreBoites: 1,
      now: now,
    ),
    _boite(
      id: '00000000-0000-4000-8000-000000000104',
      cip13: '3400933223344',
      lot: 'VENT25',
      peremption: api.Date(2026, 3, 1), // périmé pour montrer le badge
      unitesInitiales: 200,
      unitesRestantes: 80,
      nombreBoites: 1,
      now: now,
    ),
    _boite(
      id: '00000000-0000-4000-8000-000000000105',
      cip13: '3400932112233',
      lot: 'SPA2027',
      peremption: api.Date(2027, 12, 1),
      unitesInitiales: 30,
      unitesRestantes: 18,
      nombreBoites: 1,
      now: now,
    ),
  ];
}

api.Boite _boite({
  required String id,
  required String cip13,
  String? lot,
  required api.Date peremption,
  int? unitesInitiales,
  int? unitesRestantes,
  required int nombreBoites,
  required DateTime now,
}) {
  return (api.BoiteBuilder()
        ..id = id
        ..officineId = demoOfficineId
        ..cip13 = cip13
        ..lot = lot
        ..peremption = peremption
        ..unitesInitiales = unitesInitiales
        ..unitesRestantes = unitesRestantes
        ..nombreBoites = nombreBoites
        ..statut = api.BoiteStatutEnum.active
        ..ajouteePar = demoUserId
        ..createdAt = now
        ..updatedAt = now)
      .build();
}

/// 3 prises pour aujourd'hui — matin (Levothyrox prévu), midi
/// (Doliprane prévu), soir (Augmentin déjà pris). Les datetimes
/// sont en UTC ; la timeline mobile les rend dans la tz du serveur.
List<api.PriseTimelineItem> demoPrisesToday() {
  final now = DateTime.now().toUtc();
  final base = DateTime.utc(now.year, now.month, now.day);
  return [
    _prise(
      id: '00000000-0000-4000-8000-000000000201',
      datetimePrevue: base.add(const Duration(hours: 8)),
      statut: api.PriseTimelineItemStatutEnum.prevue,
      nomTexte: 'Levothyrox 50 µg',
      indication: 'Hypothyroïdie',
      cip13: '3400930146675',
      unitesParPrise: 1,
      unite: 'comprimé',
      moments: ['matin'],
    ),
    _prise(
      id: '00000000-0000-4000-8000-000000000202',
      datetimePrevue: base.add(const Duration(hours: 12)),
      statut: api.PriseTimelineItemStatutEnum.prevue,
      nomTexte: 'Doliprane 1000 mg',
      indication: 'Douleurs',
      cip13: '3400935955838',
      unitesParPrise: 1,
      unite: 'comprimé',
      moments: ['midi'],
    ),
    _prise(
      id: '00000000-0000-4000-8000-000000000203',
      datetimePrevue: base.add(const Duration(hours: 19)),
      statut: api.PriseTimelineItemStatutEnum.prise,
      nomTexte: 'Augmentin 500 mg',
      indication: 'Antibiothérapie',
      cip13: '3400934567890',
      unitesParPrise: 1,
      unite: 'comprimé',
      moments: ['soir'],
    ),
  ];
}

api.PriseTimelineItem _prise({
  required String id,
  required DateTime datetimePrevue,
  required api.PriseTimelineItemStatutEnum statut,
  required String nomTexte,
  required String indication,
  required String cip13,
  required int unitesParPrise,
  required String unite,
  required List<String> moments,
}) {
  final posologie = MapBuilder<String, JsonObject?>({
    'unites_par_prise': JsonObject(unitesParPrise),
    'unite': JsonObject(unite),
    'frequence': JsonObject('quotidien'),
    'moments': JsonObject(moments),
  });
  final prescription = (api.PriseTimelinePrescriptionBuilder()
        ..id = id
        ..ordonnanceId = id
        ..nomTexte = nomTexte
        ..cip13 = cip13
        ..indication = indication
        ..posologie = posologie)
      .build();
  return (api.PriseTimelineItemBuilder()
        ..id = id
        ..officineId = demoOfficineId
        ..datetimePrevue = datetimePrevue
        ..statut = statut
        ..prescription = prescription.toBuilder())
      .build();
}

/// 1 partages list — l'user solo. Permet à PartagesScreen de charger
/// sans erreur même en mode démo. Le bouton "Signaler un manque" sera
/// caché vu qu'il n'y a pas d'autre membre.
api.PartagesList demoPartages() {
  final now = DateTime.now().toUtc();
  final member = (api.PartageMemberBuilder()
        ..userId = demoUserId
        ..email = 'demo@piloo.fr'
        ..displayName = 'Maxime (démo)'
        ..role = api.PartageMemberRoleEnum.owner
        ..invitedAt = now
        ..acceptedAt = now)
      .build();
  return (api.PartagesListBuilder()
        ..members = ListBuilder<api.PartageMember>([member])
        ..pendingInvitations = ListBuilder<api.PendingMemberInvitation>())
      .build();
}
