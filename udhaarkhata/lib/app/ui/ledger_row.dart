import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../../features/ledger/history_page.dart' show historyDate;
import 'money_format.dart';
import 'status_chip.dart';

class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.typeLabel,
    required this.effectPaise,
    required this.occurredAtMs,
    required this.status,
    required this.details,
  });
  final String typeLabel;
  final int effectPaise, occurredAtMs;
  final EntryDisplayStatus status;
  final Widget details;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      maintainState: true,
      tilePadding: const EdgeInsets.all(16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(typeLabel, style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${effectPaise > 0 ? '+' : ''}${formatDisplayPaise(effectPaise)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(historyDate(occurredAtMs)),
          const SizedBox(height: 8),
          StatusChip(status: status),
          Text(AppStrings.of(context).translate('Details')),
        ],
      ),
      children: [details],
    ),
  );
}
