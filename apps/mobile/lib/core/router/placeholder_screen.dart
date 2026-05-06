// Écran placeholder utilisé tant que les écrans M1 ne sont pas implémentés
// (#58 splash, #59 type compte, #60 inscription, etc.). Affiche le nom de
// la route + les paramètres reçus pour faciliter le dev et debug.
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    this.subtitle,
    this.params = const {},
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Map<String, String> params;
  final List<({String label, VoidCallback onPressed})> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (params.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Paramètres : ${params.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              ...actions.map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FilledButton(onPressed: a.onPressed, child: Text(a.label)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
