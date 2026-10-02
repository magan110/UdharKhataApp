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
import 'money.dart';

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
      return const Text('Please sign in to open this ledger.');
    }
    if (_online) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: () => setState(() => _online = false),
            child: const Text('View saved ledger'),
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
        if (snapshot != null) ...[
          Text(
            snapshot.link['display_name'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Customer owes you ${formatPaise(snapshot.provisionalPaise)} (provisional, including Pending).',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Synced balance: ${formatPaise(snapshot.syncedPaise)} · Last server snapshot: ${historyDate(snapshot.snapshotAtMs)}',
          ),
          const Text(
            'Pending entries are only on this device. They are not backed up to the cloud. Customer views show only server-acknowledged entries.',
          ),
          const Text(
            'Cash/UPI payments are manually recorded by the owner; bank transfers are not verified.',
          ),
          if (snapshot.entries.isEmpty) const Text('No transactions yet.'),
          for (final entry in snapshot.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(switch (entry['kind']) {
                      'credit' =>
                        'Credit ${formatPaise(entry['amount_paise'] as int)}',
                      'payment' =>
                        '${entry['payment_method'] == 'cash' ? 'Cash' : 'UPI'} payment received ${formatPaise(entry['amount_paise'] as int)}',
                      _ =>
                        'Correction ${formatPaise(entry['effect_paise'] as int)}',
                    }),
                    Text(
                      'Entry date: ${historyDate(entry['occurred_at_ms'] as int)}',
                    ),
                    Text(switch (entry['sync_status']) {
                      'synced' => 'Synced',
                      'pending' =>
                        'Pending · Waiting to sync · Only on this device',
                      _ => 'Needs attention',
                    }),
                    if (entry['note'] != null) Text(entry['note'] as String),
                    if (entry['due_date'] != null)
                      Text('Due: ${dueDateText(entry['due_date'] as String)}'),
                    if (entry['correction_reason'] != null)
                      Text('Reason: ${entry['correction_reason']}'),
                  ],
                ),
              ),
            ),
        ],
        if (_error != null)
          Text(
            errorMessage(
              _error is AppFailure
                  ? (_error as AppFailure).messageKey
                  : 'history.failed',
            ),
          ),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading local ledger',
            ),
          ),
        TextButton(
          onPressed: _loading ? null : () => _load(refresh: true),
          child: const Text('Refresh from server'),
        ),
        TextButton(
          onPressed: () => setState(() => _online = true),
          child: const Text('View confirmed server history'),
        ),
      ],
    );
  }
}

class SavedCustomersView extends ConsumerWidget {
  const SavedCustomersView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(savedCustomersProvider).asData?.value ?? [];
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Saved customer ledgers',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Saved on this device. Balances may include Pending entries.',
        ),
        for (final link in links)
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
