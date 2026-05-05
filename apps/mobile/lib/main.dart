import 'package:flutter/material.dart';

import 'core/theme/theme.dart';

void main() {
  runApp(const PilooApp());
}

class PilooApp extends StatelessWidget {
  const PilooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piloo',
      theme: pilooLightTheme(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Piloo')),
        body: const Center(child: Text('Carnet médicaments')),
      ),
    );
  }
}
