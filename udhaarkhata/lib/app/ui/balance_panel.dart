import 'package:flutter/material.dart';
import '../app_strings.dart';
import '../../features/ledger/history_page.dart' show historyDate;
import 'app_tokens.dart';
import 'money_format.dart';

enum BalanceSource { confirmed, provisional }
class BalancePanel extends StatelessWidget {
  const BalancePanel({super.key, required this.amountPaise, required this.directionLabel, required this.source, this.syncedPaise, required this.snapshotAtMs, this.partialSyncAtMs, this.offline = false});
  final int amountPaise, snapshotAtMs;
  final int? syncedPaise, partialSyncAtMs;
  final String directionLabel;
  final BalanceSource source;
  final bool offline;
  @override
  Widget build(BuildContext context) {
    final l = AppStrings.of(context);
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTokens.tint, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(directionLabel, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8), Text(formatDisplayPaise(amountPaise), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTokens.primary)),
      Text(l.translate(source == BalanceSource.confirmed ? 'Confirmed balance' : '(provisional, including Pending).')),
      if (syncedPaise != null) Text('${l.translate('Synced balance')}: ${formatDisplayPaise(syncedPaise!)}'),
      Text('${l.translate('Server snapshot')}: ${historyDate(snapshotAtMs)}', style: Theme.of(context).textTheme.bodySmall),
      if (offline) Text(l.translate('Offline: newer owner changes may be missing.')),
      if (partialSyncAtMs != null && partialSyncAtMs != snapshotAtMs) Text('${l.translate('Partial refresh')}: ${historyDate(partialSyncAtMs!)} · ${l.translate('Complete snapshot remains dated above.')}'),
    ]));
  }
}
