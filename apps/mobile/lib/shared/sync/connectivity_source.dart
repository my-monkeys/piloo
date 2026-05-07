// Source de connectivité abstraite pour le worker de sync (#91).
//
// On abstrait `connectivity_plus` derrière un `Stream<bool>` (true =
// online, false = offline) pour pouvoir tester le worker avec un
// `StreamController` sans dépendre du plugin natif.
//
// L'implémentation `realtime` utilise `Connectivity().onConnectivityChanged`
// + un check initial pour émettre le premier état dès la souscription.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract class ConnectivitySource {
  /// Émet `true` quand au moins un transport (wifi, mobile, ethernet…)
  /// est disponible, `false` quand seul `none` reste. Le premier
  /// événement après souscription reflète l'état courant.
  Stream<bool> get onChange;
}

class RealConnectivitySource implements ConnectivitySource {
  RealConnectivitySource([Connectivity? connectivity])
      : _c = connectivity ?? Connectivity();

  final Connectivity _c;

  @override
  Stream<bool> get onChange async* {
    yield _isOnline(await _c.checkConnectivity());
    yield* _c.onConnectivityChanged.map(_isOnline);
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
