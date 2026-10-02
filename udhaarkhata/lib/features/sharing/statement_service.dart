import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../ledger/online_reads.dart';

const maxStatementEntries = 5000;
const maxStatementDays = 366;

class AuditedStatement {
  const AuditedStatement({
    required this.shopName,
    required this.customerName,
    required this.from,
    required this.to,
    required this.snapshotAtMs,
    required this.opening,
    required this.closing,
    required this.cloudBalance,
    required this.entries,
  });
  final String shopName, customerName;
  final DateTime from, to;
  final int snapshotAtMs, opening, closing, cloudBalance;
  final List<HistoryEntry> entries;
}

DateTime statementDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);
AuditedStatement reconcileStatement({
  required List<HistoryEntry> completeHistory,
  required LedgerBalanceSnapshot balance,
  required String shopName,
  required String customerName,
  required int snapshotAtMs,
  required DateTime from,
  required DateTime to,
}) {
  final start = statementDay(from), end = statementDay(to);
  if (end.isBefore(start) ||
      end.difference(start).inDays >= maxStatementDays ||
      completeHistory.length > maxStatementEntries) {
    throw const AppFailure('EXPORT_LIMIT', 'statement.bounds');
  }
  var sum = 0, previous = 0, opening = 0, closing = 0;
  final selected = <HistoryEntry>[], ids = <String>{};
  for (final e in completeHistory) {
    if (e.seq <= previous || e.seq > balance.asOfServerSeq || !ids.add(e.id)) {
      throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
    }
    previous = e.seq;
    sum += e.effect;
    // Periods use immutable UTC posting dates; backdated occurrence stays visible.
    final day = DateTime.fromMillisecondsSinceEpoch(e.createdAtMs, isUtc: true);
    if (day.isBefore(start)) opening += e.effect;
    if (day.isBefore(end.add(const Duration(days: 1)))) closing += e.effect;
    if (!day.isBefore(start) &&
        day.isBefore(end.add(const Duration(days: 1)))) {
      selected.add(e);
    }
  }
  if (sum != balance.balancePaise ||
      completeHistory.length != balance.ledgerVersion ||
      previous != balance.asOfServerSeq) {
    throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
  }
  return AuditedStatement(
    shopName: shopName,
    customerName: customerName,
    from: start,
    to: end,
    snapshotAtMs: snapshotAtMs,
    opening: opening,
    closing: closing,
    cloudBalance: balance.balancePaise,
    entries: List.unmodifiable(selected),
  );
}

class StatementRepository {
  const StatementRepository(this.reader);
  final OnlineReadRepository reader;
  Future<AuditedStatement> load(
    String shopId,
    String linkId,
    DateTime from,
    DateTime to,
  ) async {
    final start = statementDay(from), end = statementDay(to);
    if (end.isBefore(start) ||
        end.difference(start).inDays >= maxStatementDays) {
      throw const AppFailure('EXPORT_LIMIT', 'statement.bounds');
    }
    OpaqueId.fromJson(shopId);
    OpaqueId.fromJson(linkId);
    final entries = <HistoryEntry>[], cursors = <String>{};
    OnlineReadPage? first;
    String? cursor;
    do {
      final page = await reader.load(
        '/v1/shops/$shopId/customers/$linkId/statement',
        OnlineReadKind.history,
        cursor: cursor,
        shopId: shopId,
        linkId: linkId,
      );
      first ??= page;
      if (page.snapshotAtMs != first.snapshotAtMs ||
          page.balance!.asOfServerSeq != first.balance!.asOfServerSeq ||
          page.balance!.balancePaise != first.balance!.balancePaise ||
          page.balance!.ledgerVersion != first.balance!.ledgerVersion) {
        throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
      }
      entries.addAll(page.records.cast<HistoryEntry>());
      if (entries.length > maxStatementEntries) {
        throw const AppFailure('EXPORT_LIMIT', 'statement.bounds');
      }
      cursor = page.page!.hasMore ? page.page!.nextCursor?.value : null;
      if (page.page!.hasMore && (cursor == null || !cursors.add(cursor))) {
        throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
      }
    } while (cursor != null);
    return reconcileStatement(
      completeHistory: entries,
      balance: first.balance!,
      shopName: first.shopName!,
      customerName: first.customerName!,
      snapshotAtMs: first.snapshotAtMs,
      from: from,
      to: to,
    );
  }
}
