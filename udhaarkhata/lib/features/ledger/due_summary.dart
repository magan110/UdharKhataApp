import 'dart:async';

import '../../app/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import 'device_ledger_repository.dart';
import 'ledger_repository.dart';
import 'money.dart';
import 'history_page.dart' show historyDate;
import 'local_changes.dart';

class DueSnapshot {
  DueSnapshot(Object? value, String date) {
    final row = jsonObject(value);
    if (row['asOfDate'] != date) throw const FormatException('Wrong due date');
    balancePaise = MoneyPaise.fromJson(row['balancePaise']).value;
    overduePaise = MoneyPaise.fromJson(row['overduePaise']).value;
    asOfServerSeq = timestampMs(row['asOfServerSeq']);
    asOfMs = timestampMs(row['asOfMs']);
    if (balancePaise < 0 || overduePaise < 0 || overduePaise > balancePaise) {
      throw const FormatException('Invalid due summary');
    }
  }
  late final int balancePaise, overduePaise, asOfServerSeq, asOfMs;
}

class DueSummary extends ConsumerStatefulWidget {
  const DueSummary({
    super.key,
    required this.shopId,
    this.linkId,
    this.customer = false,
  });
  final String shopId;
  final String? linkId;
  final bool customer;
  @override
  ConsumerState<DueSummary> createState() => _DueSummaryState();
}

class _DueSummaryState extends ConsumerState<DueSummary> {
  DueSnapshot? _summary;
  Timer? _expiry;
  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  String? _error;
  bool _busy = false;
  Future<void> _load() async {
    final account = ref.read(sessionProvider).value;
    final auth = ref.read(authRepositoryProvider);
    final repo = ref.read(ledgerRepositoryProvider);
    if (account == null || _busy) return;
    final generation = auth.sessionGeneration;
    setState(() {
      _busy = true;
      _summary = null;
      _error = null;
    });
    try {
      if (!widget.customer && repo is DeviceLedgerRepository) {
        final snapshot = await repo.snapshot(
          OpaqueId.fromJson(widget.shopId),
          OpaqueId.fromJson(widget.linkId),
        );
        if (snapshot == null ||
            snapshot.syncBlockedCode != null ||
            snapshot.entries.any((e) => e['sync_status'] != 'synced')) {
          throw StateError(
            'Refresh complete ledger and resolve Pending entries before viewing due totals.',
          );
        }
      }
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final path = widget.customer
          ? '/v1/me/ledgers/${widget.shopId}/due'
          : '/v1/shops/${widget.shopId}/customers/${widget.linkId}/due';
      final summary = DueSnapshot(
        await auth.cloudRequest(account.id, '$path?asOfDate=$date'),
        date,
      );
      if (!widget.customer && repo is DeviceLedgerRepository) {
        final snapshot = await repo.snapshot(
          OpaqueId.fromJson(widget.shopId),
          OpaqueId.fromJson(widget.linkId),
        );
        final high = snapshot?.entries
            .where((e) => e['sync_status'] == 'synced')
            .fold<int>(
              0,
              (high, e) => (e['server_seq'] as int) > high
                  ? e['server_seq'] as int
                  : high,
            );
        if (snapshot == null ||
            snapshot.syncBlockedCode != null ||
            snapshot.entries.any((e) => e['sync_status'] != 'synced') ||
            high != summary.asOfServerSeq ||
            snapshot.syncedPaise != summary.balancePaise) {
          throw StateError(
            'Ledger snapshot changed. Refresh before showing due totals.',
          );
        }
      }
      if (DateTime.now().millisecondsSinceEpoch - summary.asOfMs > 60000) {
        throw StateError('Summary is stale. Refresh online.');
      }
      if (mounted &&
          generation == auth.sessionGeneration &&
          ref.read(sessionProvider).value?.id.value == account.id.value) {
        setState(() => _summary = summary);
        _expiry?.cancel();
        _expiry = Timer(
          Duration(
            milliseconds:
                (60000 -
                        (DateTime.now().millisecondsSinceEpoch -
                            summary.asOfMs))
                    .clamp(0, 60000),
          ),
          () {
            if (mounted) setState(() => _summary = null);
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Due totals unavailable. Refresh online with a complete acknowledged ledger and no Pending or Needs attention entries.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, _) {
      if (mounted) setState(() => _summary = null);
    });
    ref.listen(cacheRevisionProvider, (_, _) {
      if (mounted) setState(() => _summary = null);
    });
    final summary =
        _summary != null &&
            DateTime.now().millisecondsSinceEpoch - _summary!.asOfMs <= 60000
        ? _summary
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null) ...[
          Text(
            '${AppStrings.of(context).translate('Outstanding')}: ${formatPaise(summary.balancePaise)}',
          ),
          Text(
            '${AppStrings.of(context).translate('Overdue')}: ${formatPaise(summary.overduePaise)}',
          ),
          Text(
            '${AppStrings.of(context).translate('Acknowledged server summary')}: ${historyDate(summary.asOfMs)}',
          ),
        ],
        if (_error != null) Text(AppStrings.of(context).translate(_error!)),
        TextButton(
          onPressed: _busy ? null : _load,
          child: Text(AppStrings.of(context).translate('Refresh due summary')),
        ),
      ],
    );
  }
}
