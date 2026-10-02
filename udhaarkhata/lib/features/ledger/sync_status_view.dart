import '../../app/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_changes.dart';
import 'sync_service.dart';
import 'history_page.dart' show historyDate;
import 'money.dart';

String syncExplanation(String? code) => switch (code) {
  'NOT_FOUND' || 'FORBIDDEN' => 'Access is no longer available. Original entries are retained on this device.',
  'REVISION_CONFLICT' || 'BALANCE_CONFLICT' || 'LOCAL_BALANCE_CONFLICT' => 'The balance changed. Review the confirmed ledger before recording another entry.',
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
      ({int? verified, int? oldest, List<Map<String, Object?>> attention})
    >((ref) async {
      ref.watch(cacheRevisionProvider);
      final service = ref.watch(syncServiceProvider);
      if (service == null) {
        return (
          verified: null,
          oldest: null,
          attention: <Map<String, Object?>>[],
        );
      }
      final pending = (await service.repository.outbox()).where(
        (row) => row['state'] == 'pending',
      );
      int? oldest;
      for (final row in pending) {
        final time = row['created_at_ms'] as int;
        if (oldest == null || time < oldest) oldest = time;
      }
      return (
        oldest: oldest,
        verified: await service.verifiedAt(),
        attention: await service.attention(),
      );
    }, retry: (_, _) => null);

class SyncStatusView extends ConsumerWidget {
  const SyncStatusView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(syncServiceProvider);
    if (service == null) return SizedBox.shrink();
    final state =
        ref.watch(syncRunStateProvider).asData?.value ?? service.state;
    final details = ref.watch(_syncDetailsProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (service.repository.auth.offlineAccess)
          Text(
            AppStrings.of(context)
                .translate('Offline · Saved account access on this device'),
          ),
        if (details?.verified != null)
          Text(
            AppStrings.of(context).format(
              'Last verified: {time}',
              values: {'time': historyDate(details!.verified!)},
            ),
          ),
        Text(
          AppStrings.of(context).format(
            '{pending} Pending · {attention} Needs attention',
            values: {
              'pending': '${state.pendingCount}',
              'attention': '${state.needsAttentionCount}',
            },
          ),
        ),
        if (details?.oldest != null)
          Text(
            AppStrings.of(context).format(
              'Oldest Pending saved: {time}',
              values: {'time': historyDate(details!.oldest!)},
            ),
          ),
        if (state.lastSuccessfulAtMs != null)
          Text(
            AppStrings.of(context).format(
              'Last sync: {time}',
              values: {'time': historyDate(state.lastSuccessfulAtMs!)},
            ),
          ),
        Text(
          AppStrings.of(context).translate(
            'Pending entries are only on this device and are not backed up to the cloud.',
          ),
        ),
        if (state.errorCode != null)
          Text(
            AppStrings.of(context).translate(syncExplanation(state.errorCode)),
          ),
        TextButton(
          onPressed: state.running
              ? null
              : () => unawaited(service.synchronize()),
          child: Text(
            AppStrings.of(context)
                .translate(state.running ? 'Syncing…' : 'Sync now'),
          ),
        ),
        for (final entry in details?.attention ?? <Map<String, Object?>>[])
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppStrings.of(context).translate(entry['kind'] == 'credit'
                        ? 'Credit'
                        : entry['kind'] == 'correction'
                        ? 'Correction'
                        : 'Payment')} ${formatPaise((entry['amount_paise'] ?? entry['target_amount_paise']) as int)} · ${AppStrings.of(context).translate('Needs attention')}',
                  ),
                  Text(
                    AppStrings.of(context).format(
                      'Entry date: {time}',
                      values: {
                        'time': historyDate(entry['occurred_at_ms'] as int),
                      },
                    ),
                  ),
                  if (entry['payment_method'] != null)
                    Text(
                      '${AppStrings.of(context).translate('Method')}: ${entry['payment_method']}',
                    ),
                  if (entry['note'] != null) Text(entry['note'] as String),
                  if (entry['correction_reason'] != null)
                    Text(entry['correction_reason'] as String),
                  Text(
                    AppStrings.of(context).translate(
                      'Original entry is retained. Review it before recording another entry.',
                    ),
                  ),
                  Text(
                    AppStrings.of(context).translate(
                      syncExplanation(entry['error_code'] as String?),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
