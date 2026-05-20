import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'shared/sync/sync_providers.dart';

class PilooApp extends ConsumerStatefulWidget {
  const PilooApp({super.key});

  @override
  ConsumerState<PilooApp> createState() => _PilooAppState();
}

class _PilooAppState extends ConsumerState<PilooApp> {
  // Le router est instancié une fois pour la durée de vie de l'app — il
  // détient l'état de navigation (shell, history) qui doit persister
  // pendant tout le cycle de vie.
  late final _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Boot du SyncWorker (#18) : la lecture du FutureProvider
    // l'instancie et appelle start() (subscription connectivity_plus).
    // On ignore l'AsyncValue retournée — l'erreur ne doit pas bloquer
    // l'app (la sync est best-effort).
    ref.watch(syncWorkerProvider);
    return MaterialApp.router(
      title: 'Piloo',
      theme: pilooLightTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
