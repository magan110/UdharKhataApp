import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/account.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import '../qr/owner_qr_model.dart';
import 'money.dart';

enum OnlineReadKind { history, customers, shops, summary }

final onlineReadRepositoryProvider = Provider<OnlineReadRepository?>((ref) {
  final account = ref.watch(sessionProvider).value;
  return account == null
      ? null
      : OnlineReadRepository(
          ref.watch(authRepositoryProvider),
          account.id,
          account.role,
        );
});

class HistoryEntry {
  HistoryEntry(Object? value, String shopId, String linkId) {
    final row = jsonObject(value);
    id = OpaqueId.fromJson(row['id']).value;
    seq = timestampMs(row['serverSeq']);
    kind = jsonString(row['kind']);
    effect = MoneyPaise.fromJson(row['effectPaise']).value;
    occurredAtMs = timestampMs(row['occurredAtMs']);
    createdAtMs = timestampMs(row['createdAtMs']);
    OpaqueId.fromJson(row['createdByUserId']);
    revision = timestampMs(row['revision']);
    note = _nullableText(row['note'], 500);
    dueDate = _nullableText(row['dueDate'], 10);
    method = _nullableText(row['paymentMethod'], 4);
    reason = _nullableText(row['correctionReason'], 500);
    if (row['shopId'] != shopId ||
        row['linkId'] != linkId ||
        seq == 0 ||
        !validDueDate(dueDate)) {
      throw const FormatException('Wrong history scope');
    }
    if (kind == 'credit' || kind == 'payment') {
      amount = MoneyPaise.fromJson(row['amountPaise']).value;
      if (amount < 1 ||
          effect != (kind == 'credit' ? amount : -amount) ||
          row['targetAmountPaise'] != null ||
          row['correctsEntryId'] != null ||
          reason != null ||
          revision != 0 ||
          (kind == 'credit'
              ? method != null
              : !['cash', 'upi'].contains(method) || dueDate != null)) {
        throw const FormatException('Invalid original entry');
      }
    } else if (kind == 'correction') {
      amount = MoneyPaise.fromJson(row['targetAmountPaise']).value;
      targetId = OpaqueId.fromJson(row['correctsEntryId']).value;
      if (amount < 0 ||
          row['amountPaise'] != null ||
          method != null ||
          dueDate != null ||
          reason == null ||
          revision < 1) {
        throw const FormatException('Invalid correction');
      }
    } else {
      throw const FormatException('Invalid entry kind');
    }
  }
  late final String id, kind;
  late final int seq, amount, effect, occurredAtMs, createdAtMs, revision;
  late final String? note, dueDate, method, reason;
  String? targetId;
}

String? _nullableText(Object? value, int max) {
  if (value == null) return null;
  final text = jsonString(value);
  if (text.length > max) throw const FormatException('Oversized text');
  return text;
}

class ShopLedger {
  ShopLedger(Object? value) {
    final row = jsonObject(value);
    id = OpaqueId.fromJson(row['id']).value;
    shopId = OpaqueId.fromJson(row['shopId']).value;
    name = jsonString(row['shopName']);
    balance = MoneyPaise.fromJson(row['balancePaise']).value;
    timestampMs(row['ledgerVersion']);
    if (balance < 0 || name.length > 120) {
      throw const FormatException('Invalid shop');
    }
  }
  late final String id, shopId, name;
  late final int balance;
}

class OnlineReadPage {
  const OnlineReadPage({
    required this.records,
    required this.snapshotAtMs,
    this.page,
    this.balance,
    this.shopName,
    this.customerName,
    this.linkId,
    this.total,
    this.customerCount,
  });
  final List<Object> records;
  final int snapshotAtMs;
  final ApiPage? page;
  final LedgerBalanceSnapshot? balance;
  final String? shopName, customerName, linkId;
  final int? total, customerCount;
}

class OnlineReadRepository {
  const OnlineReadRepository(this.auth, this.accountId, this.role);
  final AuthRepository auth;
  final OpaqueId accountId;
  final AccountRole role;
  Future<OnlineReadPage> load(
    String path,
    OnlineReadKind kind, {
    String? cursor,
    String? shopId,
    String? linkId,
  }) async {
    try {
      final query = kind == OnlineReadKind.summary
          ? path
          : Uri(
              path: path,
              queryParameters: {
                'limit': '50',
                if (cursor != null) 'cursor': PageCursor.fromJson(cursor).value,
              },
            ).toString();
      final row = jsonObject(await auth.cloudRequest(accountId, query));
      if (kind == OnlineReadKind.summary) {
        final total = MoneyPaise.fromJson(row['totalBalancePaise']).value;
        if (row['id'] != shopId || total < 0) {
          throw const FormatException('Wrong summary scope');
        }
        return OnlineReadPage(
          records: const [],
          snapshotAtMs: timestampMs(row['asOfAtMs']),
          total: total,
          customerCount: timestampMs(row['customerCount']),
        );
      }
      final page = ApiPage.fromJson(row['page']),
          snapshot = timestampMs(row['snapshotAtMs']);
      if (!page.hasMore && page.nextCursor != null) {
        throw const FormatException('Unexpected cursor');
      }
      final rows =
          row[switch (kind) {
            OnlineReadKind.history => 'entries',
            OnlineReadKind.customers => 'customers',
            _ => 'links',
          }];
      if (rows is! List || rows.length > 50 || (page.hasMore && rows.isEmpty)) {
        throw const FormatException('Invalid page');
      }
      switch (kind) {
        case OnlineReadKind.history:
          final scopeLink = OpaqueId.fromJson(row['linkId']).value;
          if (row['shopId'] != shopId ||
              (linkId != null && scopeLink != linkId)) {
            throw const FormatException('Wrong ledger');
          }
          final balance = LedgerBalanceSnapshot.fromJson(row['balance']);
          final entries = [
            for (final item in rows) HistoryEntry(item, shopId!, scopeLink),
          ];
          var previous = 0;
          for (final entry in entries) {
            if (entry.seq <= previous || entry.seq > balance.asOfServerSeq) {
              throw const FormatException('Invalid sequence');
            }
            previous = entry.seq;
          }
          return OnlineReadPage(
            records: entries,
            snapshotAtMs: snapshot,
            page: page,
            balance: balance,
            shopName: jsonString(row['shopName']),
            customerName: jsonString(row['customerDisplayName']),
            linkId: scopeLink,
          );
        case OnlineReadKind.customers:
          final customers = [
            for (final item in rows) CustomerLink.fromJson(item),
          ];
          if (customers.any((c) => c.shopId.value != shopId)) {
            throw const FormatException('Wrong customers');
          }
          return OnlineReadPage(
            records: customers,
            snapshotAtMs: snapshot,
            page: page,
          );
        case OnlineReadKind.shops:
          return OnlineReadPage(
            records: [for (final item in rows) ShopLedger(item)],
            snapshotAtMs: snapshot,
            page: page,
          );
        case OnlineReadKind.summary:
          throw const FormatException('Invalid read');
      }
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
    }
  }
}
