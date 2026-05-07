// Riverpod providers BDPM (#84).
//
// `bdpmDbProvider` ouvre la SQLite locale en read-only si elle existe.
// Retourne null si aucun fichier (1er lancement avant download #78).
// Les écrans qui dépendent du lookup CIP13 doivent gérer le cas null.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'bdpm_db.dart';

/// Chemin canonique du fichier SQLite BDPM dans l'app sandbox.
Future<String> bdpmLocalPath() async {
  final docs = await getApplicationDocumentsDirectory();
  return '${docs.path}/bdpm/medicaments.sqlite';
}

/// Provider override-able dans les tests pour injecter un BdpmDb fake.
final bdpmDbProvider = FutureProvider<BdpmDb?>((ref) async {
  final path = await bdpmLocalPath();
  if (!File(path).existsSync()) return null;
  final db = BdpmDb.open(path);
  ref.onDispose(db.close);
  return db;
});
