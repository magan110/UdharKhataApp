import 'package:flutter/material.dart';

class StatePanel extends StatelessWidget {
  const StatePanel({super.key, required this.title, required this.message, this.loading = false, this.actionLabel, this.onAction});
  final String title, message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
    Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
    const SizedBox(height: 8), Semantics(liveRegion: true, child: Text(message)),
    if (loading) Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(semanticsLabel: title))),
    if (actionLabel != null && onAction != null) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton(onPressed: onAction, child: Text(actionLabel!))),
  ]));
}
