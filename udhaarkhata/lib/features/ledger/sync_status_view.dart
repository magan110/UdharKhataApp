import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_changes.dart';
import 'sync_service.dart';
import 'history_page.dart' show historyDate;
import 'money.dart';

String syncExplanation(String? code) => switch (code) {
  'NOT_FOUND' || 'FORBIDDEN' => 'Access is no longer available. Original entries are retained on this device.',
  'BALANCE_CONFLICT' || 'LOCAL_BALANCE_CONFLICT' => 'The balance changed. Review the confirmed ledger before recording another entry.',
  'CACHE_TOO_LARGE' => 'This ledger is too large for offline entry. View confirmed server history online.',
  'FEATURE_UNAVAILABLE' =>
    'Sync is unavailable on this server. Saved entries remain on this device.',
  'AUTH_REQUIRED' => 'Please sign in again to continue syncing.',
  'LEGACY_RECOVERY_REQUIRED' =>
    'Recover the earlier online attempt before syncing new entries.',
  'NETWORK_ERROR' =>
    'Offline. Saved entries will sync when a connection is available.',
  'RATE_LIMITED' ||
  'CAPACITY_UNAVAILABLE' => 'Sync will retry after the server waiting period.',
  _ => 'Sync could not finish. Original entries are retained; try again later.',
};
final _syncDetailsProvider =
    FutureProvider.autoDispose<
      ({int? verified, List<Map<String, Object?>> attention})
    >((ref) async {
      ref.watch(cacheRevisionProvider);
      final service = ref.watch(syncServiceProvider);
      if (service == null) {
        return (verified: null, attention: <Map<String, Object?>>[]);
      }
      return (
        verified: await service.verifiedAt(),
        attention: await service.attention(),
      );
    }, retry: (_, _) => null);

class SyncStatusView extends ConsumerWidget {
  const SyncStatusView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(syncServiceProvider);
    if (service == null) return const SizedBox.shrink();
    final state =
        ref.watch(syncRunStateProvider).asData?.value ?? service.state;
    final details = ref.watch(_syncDetailsProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (service.repository.auth.offlineAccess)
          const Text('Offline · Saved account access on this device'),
        if (details?.verified != null)
          Text('Last verified: ${historyDate(details!.verified!)}'),
        Text(
          '${state.pendingCount} Pending · ${state.needsAttentionCount} Needs attention',
        ),
        if (state.lastSuccessfulAtMs != null)
          Text('Last sync: ${historyDate(state.lastSuccessfulAtMs!)}'),
        const Text(
          'Pending entries are only on this device and are not backed up to the cloud.',
        ),
        if (state.errorCode != null) Text(syncExplanation(state.errorCode)),
        TextButton(
          onPressed: state.running
              ? null
              : () => unawaited(service.synchronize()),
          child: Text(state.running ? 'Syncing…' : 'Sync now'),
        ),
        for (final entry in details?.attention ?? <Map<String, Object?>>[])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry['kind'] == 'credit' ? 'Credit' : 'Payment'} ${formatPaise(entry['amount_paise'] as int)} · Needs attention',
                  ),
                  Text(
                    'Entry date: ${historyDate(entry['occurred_at_ms'] as int)}',
                  ),
                  if (entry['payment_method'] != null)
                    Text('Method: ${entry['payment_method']}'),
                  if (entry['note'] != null) Text(entry['note'] as String),
                  const Text(
                    'Original entry is retained. Review it before recording another entry.',
                  ),
                  Text(syncExplanation(entry['error_code'] as String?)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
