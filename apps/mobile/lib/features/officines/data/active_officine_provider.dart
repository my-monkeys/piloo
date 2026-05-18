// Provider Riverpod de l'officine active.
//
// Une officine = un carnet de médicaments. L'utilisateur peut en avoir
// plusieurs (perso + patients pro + partagées par un proche). L'app
// affiche toujours UNE officine à la fois — celle-ci.
//
// Stratégie initiale :
//   1. Lit l'ID stocké dans SharedPreferences (clé `piloo.active_officine`).
//   2. Si vide ou inexistant côté serveur, prend la première officine
//      où l'user est owner.
//   3. Si aucune officine, en crée une "Maison" type=perso (cas premier
//      lancement). C'est seamless pour l'usage particulier.
//
// L'écran "Mes officines" peut switcher via `select(id)` ; ça met à jour
// l'état + persiste dans les prefs.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piloo_api_client/piloo_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:piloo/shared/api/api_client_provider.dart';

const _prefsKey = 'piloo.active_officine';

final activeOfficineProvider =
    AsyncNotifierProvider<ActiveOfficineNotifier, Officine?>(
  ActiveOfficineNotifier.new,
);

class ActiveOfficineNotifier extends AsyncNotifier<Officine?> {
  @override
  Future<Officine?> build() async {
    return _resolve();
  }

  Future<Officine?> _resolve() async {
    final api = ref.read(pilooApiClientProvider).getOfficinesApi();
    final res = await api.v1OfficinesGet();
    if (res.statusCode != 200 || res.data == null) {
      return null;
    }
    final items = res.data!.items.toList();
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_prefsKey);

    if (storedId != null) {
      final match = items.where((o) => o.id == storedId).firstOrNull;
      if (match != null) return match;
    }

    final firstOwner =
        items.where((o) => o.role == OfficineRoleEnum.owner).firstOrNull;
    if (firstOwner != null) {
      await prefs.setString(_prefsKey, firstOwner.id);
      return firstOwner;
    }

    // Aucune officine : crée "Maison" perso pour démarrer.
    final created = await api.v1OfficinesPost(
      createOfficineInput: CreateOfficineInput((b) => b
        ..nom = 'Maison'
        ..type = CreateOfficineInputTypeEnum.perso),
    );
    if (created.statusCode != 201 || created.data == null) {
      return null;
    }
    await prefs.setString(_prefsKey, created.data!.id);
    return created.data;
  }

  Future<void> select(String officineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, officineId);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_resolve);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_resolve);
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
