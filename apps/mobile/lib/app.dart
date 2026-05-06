import 'package:flutter/material.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';

class PilooApp extends StatefulWidget {
  const PilooApp({super.key});

  @override
  State<PilooApp> createState() => _PilooAppState();
}

class _PilooAppState extends State<PilooApp> {
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
    return MaterialApp.router(
      title: 'Piloo',
      theme: pilooLightTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
