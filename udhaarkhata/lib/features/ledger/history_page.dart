import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import '../qr/owner_qr_model.dart';
import '../../app/ui/money_format.dart';
import '../../app/ui/balance_panel.dart';
import '../../app/ui/state_panel.dart';
import 'ledger_repository.dart';
import 'device_ledger_repository.dart';
import 'local_ledger_view.dart';
import 'sync_service.dart';
import 'sync_status_view.dart';
import 'online_reads.dart';
import 'due_summary.dart';
import '../settings/settings_page.dart' show AccessRemovalButton;

String historyDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}-${two(date.month)}-${date.year.toString().padLeft(4, '0')} ${two(date.hour)}:${two(date.minute)}';
}

String dueDateText(String date) =>
    '${date.substring(8)}-${date.substring(5, 7)}-${date.substring(0, 4)}';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({
    super.key,
    required this.shopId,
    this.linkId,
    this.confirmedOnly = false,
  });
  final String shopId;
  final String? linkId;
  final bool confirmedOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(AppStrings.of(context).translate('Transaction history')),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:
            !confirmedOnly &&
                linkId != null &&
                ref.watch(ledgerRepositoryProvider) is DeviceLedgerRepository
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SyncStatusView(),
                  LocalLedgerView(shopId: shopId, linkId: linkId!),
                ],
              )
            : OnlineRecordsView(
                kind: OnlineReadKind.history,
                shopId: shopId,
                linkId: linkId,
                path: linkId == null
                    ? '/v1/me/ledgers/$shopId/entries'
                    : '/v1/shops/$shopId/customers/$linkId/entries',
              ),
      ),
    ),
  );
}

class OnlineRecordsView extends ConsumerStatefulWidget {
  const OnlineRecordsView({
    super.key,
    required this.path,
    required this.kind,
    this.shopId,
    this.linkId,
    this.previewLimit,
    this.showControls = true,
  });
  final int? previewLimit;
  final bool showControls;
  final String path;
  final OnlineReadKind kind;
  final String? shopId, linkId;
  @override
  ConsumerState<OnlineRecordsView> createState() => _OnlineRecordsViewState();
}

class _OnlineRecordsViewState extends ConsumerState<OnlineRecordsView>
    with WidgetsBindingObserver {
  OnlineReadRepository? _repository;
  OnlineReadPage? _snapshot;
  final _records = <Object>[];
  String? _cursor;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(syncRunStateProvider, (previous, next) {
      final state = next.asData?.value;
      if (widget.kind == OnlineReadKind.summary &&
          state?.lastSuccessfulAtMs != null &&
          state!.lastSuccessfulAtMs !=
              previous?.asData?.value.lastSuccessfulAtMs) {
        _load(restart: true);
      }
    });
    ref.listenManual(onlineReadRepositoryProvider, (_, next) {
      _repository = next;
      _load(restart: true);
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(covariant OnlineRecordsView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.kind != widget.kind) {
      _load(restart: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(restart: true);
  }

  Future<void> _load({bool restart = false}) async {
    if (_loading && !restart) return;
    final generation = ++_generation, repo = _repository;
    setState(() {
      _loading = true;
      _error = null;
      if (restart) {
        _snapshot = null;
        _records.clear();
        _cursor = null;
      }
    });
    try {
      if (repo == null) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final next = await repo.load(
        widget.path,
        widget.kind,
        cursor: _cursor,
        shopId: widget.shopId,
        linkId: widget.linkId,
      );
      if (!mounted ||
          generation != _generation ||
          !identical(repo, ref.read(onlineReadRepositoryProvider))) {
        return;
      }
      final previous = _snapshot;
      if (previous != null &&
          (next.snapshotAtMs != previous.snapshotAtMs ||
              next.linkId != previous.linkId ||
              next.balance?.balancePaise != previous.balance?.balancePaise ||
              next.balance?.ledgerVersion != previous.balance?.ledgerVersion ||
              next.balance?.asOfServerSeq != previous.balance?.asOfServerSeq)) {
        throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
      }
      final all = [..._records, ...next.records];
      final ids = <String>{};
      var seq = 0, sum = 0;
      for (final record in all) {
        final id = switch (record) {
          HistoryEntry e => e.id,
          CustomerLink c => c.id.value,
          ShopLedger s => s.id,
          _ => throw const FormatException('Invalid record'),
        };
        if (!ids.add(id)) {
          throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
        }
        if (record is HistoryEntry) {
          if (record.seq <= seq) {
            throw const AppFailure(
              'INVALID_RESPONSE',
              'history.invalidResponse',
            );
          }
          seq = record.seq;
          sum += record.effect;
        }
      }
      if (widget.kind == OnlineReadKind.history &&
          next.page?.hasMore == false &&
          (sum != next.balance!.balancePaise ||
              all.length != next.balance!.ledgerVersion)) {
        throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
      }
      if (next.page?.nextCursor?.value != null &&
          next.page!.nextCursor!.value == _cursor) {
        throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
      }
      setState(() {
        _snapshot = next;
        _records
          ..clear()
          ..addAll(all);
        _cursor = next.page?.nextCursor?.value;
      });
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          !identical(repo, ref.read(onlineReadRepositoryProvider))) {
        return;
      }
      setState(() {
        _error = error;
        if (error is AppFailure &&
            [
              'AUTH_REQUIRED',
              'NOT_FOUND',
              'FORBIDDEN',
              'CURSOR_INVALID',
            ].contains(error.code)) {
          _snapshot = null;
          _records.clear();
          _cursor = null;
        }
      });
      if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String get _refresh => switch (widget.kind) {
    OnlineReadKind.shops => 'Refresh shops',
    OnlineReadKind.customers => 'Refresh customers',
    OnlineReadKind.summary => 'Refresh totals',
    _ => 'Refresh history',
  };
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(onlineReadRepositoryProvider),
        snapshot = _snapshot;
    if (!identical(current, _repository)) {
      return Text(
        AppStrings.of(context).translate('Please sign in to continue.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot != null) ...[
          if (snapshot.offline)
            Text(
              '${AppStrings.of(context).translate('Last successful sync')}: ${historyDate(snapshot.snapshotAtMs)} · ${AppStrings.of(context).translate('Offline: newer owner changes may be missing.')}',
            ),
          if (widget.kind == OnlineReadKind.summary) ...[
            BalancePanel(amountPaise: snapshot.total!, directionLabel: AppStrings.of(context).translate('Total customers owe you'), source: BalanceSource.confirmed, snapshotAtMs: snapshot.snapshotAtMs, offline: snapshot.offline),
            Text(AppStrings.of(context).translate('Excludes entries waiting to sync.')),
            Text(
              '${snapshot.customerCount} ${AppStrings.of(context).translate('customer ledgers, including retained ledgers.')}',
            ),
          ],
          if (widget.kind == OnlineReadKind.history) ...[
            Text(
              current?.role == AccountRole.owner
                  ? snapshot.customerName!
                  : snapshot.shopName!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              current?.role == AccountRole.owner
                  ? AppStrings.of(context).text(
                      'owner.owes',
                      values: {
                        'amount': formatDisplayPaise(snapshot.balance!.balancePaise),
                      },
                    )
                  : AppStrings.of(context).text(
                      'customer.owes',
                      values: {
                        'shop': snapshot.shopName!,
                        'amount': formatDisplayPaise(snapshot.balance!.balancePaise),
                      },
                    ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              AppStrings.of(context).translate(
                'Confirmed server entries. Payments are manually recorded by the owner; bank transfers are not verified.',
              ),
            ),
          ],
          Text(
            '${AppStrings.of(context).translate('Server snapshot')}: ${historyDate(snapshot.snapshotAtMs)} · ${AppStrings.of(context).translate('Refresh for newer changes.')}',
          ),
          if (_records.isEmpty && widget.kind != OnlineReadKind.summary)
            Text(
              AppStrings.of(context).translate(switch (widget.kind) {
                OnlineReadKind.history => 'No transactions yet.',
                OnlineReadKind.shops => 'No shops are linked to this account.',
                _ => 'No customers yet. Scan a customer QR to add them.',
              }),
            ),
          if (widget.kind == OnlineReadKind.history &&
              widget.linkId == null) ...[
            DueSummary(shopId: widget.shopId!, customer: true),
            AccessRemovalButton(shopId: widget.shopId!),
            TextButton(
              onPressed: () =>
                  context.push('/customer/disputes/${widget.shopId}'),
              child: Text(AppStrings.of(context).translate('View disputes')),
            ),
          ],
          for (final record in widget.previewLimit == null ? _records : _records.take(widget.previewLimit!)) _record(context, record),
        ],
        if (_error != null && widget.kind == OnlineReadKind.summary && snapshot == null)
          StatePanel(title: AppStrings.of(context).translate('Confirmed total unavailable'), message: AppStrings.of(context).translate('Refresh for newer changes.')),
        if (_error is AppFailure && widget.previewLimit != null && widget.kind == OnlineReadKind.customers && ((_error as AppFailure).retryable || (_error as AppFailure).code == 'NETWORK_ERROR'))
          SavedCustomersView(previewLimit: widget.previewLimit),
        if (_error != null) ...[
          if (snapshot != null)
            Text(
              AppStrings.of(context).translate(
                'Showing the earlier server snapshot. The latest page could not be verified.',
              ),
            ),
          Text(
            errorMessage(
              _error is AppFailure
                  ? (_error as AppFailure).messageKey
                  : 'history.failed',
              languageCode: AppStrings.of(context).languageCode,
            ),
          ),
          if (_cursor != null)
            TextButton(
              onPressed: _loading ? null : () => _load(),
              child: Text(AppStrings.of(context).translate('Retry page')),
            ),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading server records',
              ),
            ),
          ),
        if (widget.showControls && _cursor != null && _error == null)
          TextButton(
            onPressed: _loading ? null : () => _load(),
            child: Text(AppStrings.of(context).translate('Load more')),
          ),
        if (widget.showControls) TextButton(
          onPressed: _loading ? null : () => _load(restart: true),
          child: Text(AppStrings.of(context).translate(_refresh)),
        ),
      ],
    );
  }

  Widget _record(BuildContext context, Object record) => switch (record) {
    HistoryEntry e => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(switch (e.kind) {
              'credit' =>
                '${AppStrings.of(context).translate('Credit')} ${formatDisplayPaise(e.amount)}',
              'payment' =>
                '${AppStrings.of(context).translate(e.method == 'cash' ? 'Cash' : 'UPI')} ${AppStrings.of(context).translate('Payment received').toLowerCase()} ${formatDisplayPaise(e.amount)}',
              _ =>
                '${AppStrings.of(context).translate('Correction')} ${e.effect < 0 ? '-' : '+'}${formatDisplayPaise(e.effect.abs())}',
            }, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${AppStrings.of(context).translate('Entry date')}: ${historyDate(e.occurredAtMs)}',
            ),
            Text(
              '${AppStrings.of(context).translate('Recorded')}: ${historyDate(e.createdAtMs)} · ${AppStrings.of(context).translate('Confirmed')} · ${AppStrings.of(context).translate('Created by shop owner')}',
            ),
            if (e.note != null) Text(e.note!),
            if (e.dueDate != null)
              Text(
                '${AppStrings.of(context).translate('Due')}: ${dueDateText(e.dueDate!)}',
              ),
            if (widget.linkId == null && e.kind != 'correction')
              TextButton(
                onPressed: () => context.push(
                  '/customer/disputes/${widget.shopId}?entry=${e.id}',
                ),
                child: Text(
                  AppStrings.of(context).translate('Raise or view dispute'),
                ),
              ),
            if (e.reason != null)
              Text(
                '${AppStrings.of(context).translate('Reason')}: ${e.reason} · Original entry: ${e.targetId}',
              ),
          ],
        ),
      ),
    ),
    CustomerLink c => ListTile(
      title: Text(c.nickname ?? c.displayName),
      subtitle: Text(
        AppStrings.of(
          context,
        ).text('owner.owes', values: {'amount': formatDisplayPaise(c.balance.value)}),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await context.push('/owner/customer/${c.shopId.value}/${c.id.value}');
        if (mounted) _load(restart: true);
      },
    ),
    ShopLedger s => ListTile(
      title: Text(s.name),
      subtitle: Text(
        '${AppStrings.of(context).text('customer.owes', values: {'shop': s.name, 'amount': formatDisplayPaise(s.balance)})} · ${AppStrings.of(context).translate('Last server read')}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/customer/history/${s.shopId}'),
    ),
    _ => const SizedBox.shrink(),
  };
}
