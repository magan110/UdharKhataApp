import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../core/db/ledger_dao.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import 'device_ledger_repository.dart';
import 'history_page.dart' show historyDate, dueDateText, OnlineRecordsView;
import 'online_reads.dart';
import 'ledger_repository.dart';
import '../../app/ui/balance_panel.dart';
import '../../app/ui/ledger_row.dart';
import '../../app/ui/status_chip.dart';
import 'local_changes.dart';
import 'entry_detail.dart';
import 'due_summary.dart';
import 'sync_status_view.dart';

class LocalLedgerView extends ConsumerStatefulWidget {
  const LocalLedgerView({
    super.key,
    required this.shopId,
    required this.linkId,
  });
  final String shopId, linkId;
  @override
  ConsumerState<LocalLedgerView> createState() => _LocalLedgerViewState();
}

class _LocalLedgerViewState extends ConsumerState<LocalLedgerView> {
  DeviceLedgerRepository? _repository;
  CachedOwnerLedger? _snapshot;
  Object? _error;
  bool _loading = true, _online = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    ref.listenManual(cacheRevisionProvider, (_, _) => _load());
    ref.listenManual(ledgerRepositoryProvider, (_, repo) {
      _repository = repo is DeviceLedgerRepository ? repo : null;
      _load();
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(covariant LocalLedgerView old) {
    super.didUpdateWidget(old);
    if (old.shopId != widget.shopId || old.linkId != widget.linkId) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final generation = ++_generation, repo = _repository;
    setState(() {
      _loading = true;
      _error = null;
      _snapshot = null;
    });
    try {
      if (repo == null) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final shop = OpaqueId.fromJson(widget.shopId),
          link = OpaqueId.fromJson(widget.linkId);
      await repo.prepareCustomer(shop, link, refresh: refresh);
      final snapshot = await repo.snapshot(shop, link);
      if (mounted &&
          generation == _generation &&
          identical(repo, ref.read(ledgerRepositoryProvider))) {
        setState(() => _snapshot = snapshot);
      }
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          !identical(repo, ref.read(ledgerRepositoryProvider))) {
        return;
      }
      setState(() => _error = error);
      // Only transient failures may show the earlier, clearly dated cache.
      if (error is AppFailure &&
          (error.retryable || error.code == 'NETWORK_ERROR')) {
        final snapshot = await repo?.snapshot(
          OpaqueId.fromJson(widget.shopId),
          OpaqueId.fromJson(widget.linkId),
        );
        if (mounted &&
            generation == _generation &&
            identical(repo, ref.read(ledgerRepositoryProvider))) {
          setState(() => _snapshot = snapshot);
        }
      }
      if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(ledgerRepositoryProvider), snapshot = _snapshot;
    if (!identical(current, _repository)) {
      return Text(
        AppStrings.of(context).translate('Please sign in to open this ledger.'),
      );
    }
    if (_online) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: () => setState(() => _online = false),
            child: Text(AppStrings.of(context).translate('View saved ledger')),
          ),
          OnlineRecordsView(
            path:
                '/v1/shops/${widget.shopId}/customers/${widget.linkId}/entries',
            kind: OnlineReadKind.history,
            shopId: widget.shopId,
            linkId: widget.linkId,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: _loading ? null : () => _load(refresh: true),
          child: Text(AppStrings.of(context).translate('Refresh from server')),
        ),

        if (snapshot != null) ...[
          Text(
            snapshot.link['display_name'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          BalancePanel(
            amountPaise: snapshot.provisionalPaise,
            directionLabel: AppStrings.of(context)
                .translate('Customer owes you'),
            source: BalanceSource.provisional,
            syncedPaise: snapshot.syncedPaise,
            snapshotAtMs: snapshot.snapshotAtMs,
            partialSyncAtMs: snapshot.partialSyncAtMs,
          ),
          if (snapshot.syncBlockedCode != null)
            Text(
              AppStrings.of(context)
                  .translate(syncExplanation(snapshot.syncBlockedCode)),
            ),
          if (snapshot.provisionalPaise < 0)
            Text(
              AppStrings.of(context).translate(
                'The server balance changed. Review Pending entries before recording another entry.',
              ),
            ),
          Text(
            AppStrings.of(context).translate(
              'Pending entries are only on this device. They are not backed up to the cloud. Customer views show only server-acknowledged entries.',
            ),
          ),
          Text(
            AppStrings.of(context).translate(
              'Cash/UPI payments are manually recorded by the owner; bank transfers are not verified.',
            ),
          ),
          DueSummary(shopId: widget.shopId, linkId: widget.linkId),
          if (snapshot.entries.isEmpty)
            Text(AppStrings.of(context).translate('No transactions yet.')),
          for (final entry in snapshot.entries)
            LedgerRow(
              typeLabel: AppStrings.of(context).translate(
                entry['kind'] == 'credit'
                    ? 'Credit'
                    : entry['kind'] == 'payment'
                    ? (entry['payment_method'] == 'cash'
                          ? 'Cash payment received'
                          : 'UPI payment received')
                    : 'Correction',
              ),
              effectPaise: entry['effect_paise'] as int,
              occurredAtMs: entry['occurred_at_ms'] as int,
              status: entry['sync_status'] == 'synced'
                  ? EntryDisplayStatus.synced
                  : entry['sync_status'] == 'pending'
                  ? EntryDisplayStatus.pending
                  : EntryDisplayStatus.attention,
              details: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entry['created_at_ms'] != null)
                    Text(
                      '${AppStrings.of(context).translate('Recorded')}: ${historyDate(entry['created_at_ms'] as int)} · ${AppStrings.of(context).translate('Created by shop owner')}',
                    ),
                  if (entry['sync_status'] == 'needs_attention')
                    Text(
                      AppStrings.of(context).translate(
                        'Original entry is retained. Review it before recording another entry.',
                      ),
                    ),
                  if (entry['blocked_by_earlier'] == 1)
                    Text(
                      AppStrings.of(context).translate(
                        'Blocked by an earlier entry. Review the original entry first.',
                      ),
                    ),
                  if (entry['error_code'] != null)
                    Text(
                      AppStrings.of(context).translate(
                        syncExplanation(entry['error_code'] as String),
                      ),
                    ),
                  if (entry['note'] != null) Text(entry['note'] as String),
                  if (entry['due_date'] != null)
                    Text(
                      '${AppStrings.of(context).translate('Due')}: ${dueDateText(entry['due_date'] as String)}',
                    ),
                  if (['credit', 'payment'].contains(entry['kind']))
                    EntryDetail(
                      shopId: widget.shopId,
                      linkId: widget.linkId,
                      entry: entry,
                      entries: snapshot.entries,
                    ),
                  if (entry['correction_reason'] != null)
                    Text(
                      '${AppStrings.of(context).translate('Reason')}: ${entry['correction_reason']}',
                    ),
                ],
              ),
            ),
        ],
        if (_error != null)
          Text(
            errorMessage(
              _error is AppFailure
                  ? (_error as AppFailure).messageKey
                  : 'history.failed',
              languageCode: AppStrings.of(context).languageCode,
            ),
          ),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading local ledger',
            ),
          ),
        TextButton(
          onPressed: () => setState(() => _online = true),
          child: Text(
            AppStrings.of(context).translate('View confirmed server history'),
          ),
        ),
      ],
    );
  }
}

class SavedCustomersView extends ConsumerWidget {
  const SavedCustomersView({super.key, this.previewLimit});
  final int? previewLimit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(savedCustomersProvider).asData?.value ?? [];
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).translate('Saved customer ledgers'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          AppStrings.of(context).translate(
            'Saved on this device. Balances may include Pending entries.',
          ),
        ),
        for (final link
            in previewLimit == null ? links : links.take(previewLimit!))
          ListTile(
            title: Text(
              link['nickname'] as String? ?? link['display_name'] as String,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push(
                '/owner/customer/${link['shop_id']}/${link['id']}',
              );
              if (context.mounted) ref.invalidate(savedCustomersProvider);
            },
          ),
      ],
    );
  }
}
