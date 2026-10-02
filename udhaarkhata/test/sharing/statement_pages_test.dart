import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/online_reads.dart';
import 'package:udhaarkhata/features/sharing/statement_service.dart';

import 'statement_test.dart' show entry;

class PageReader extends OnlineReadRepository {
  PageReader(this.pages)
    : super(
        UnconfiguredAuthRepository(),
        OpaqueId.fromJson('account_1'),
        AccountRole.owner,
      );
  final List<OnlineReadPage> pages;
  final seen = <String?>[];
  @override
  Future<OnlineReadPage> load(
    String path,
    OnlineReadKind kind, {
    String? cursor,
    String? shopId,
    String? linkId,
  }) async {
    seen.add(cursor);
    return pages[seen.length - 1];
  }
}

LedgerBalanceSnapshot balance() => LedgerBalanceSnapshot.fromJson({
  'balancePaise': 800,
  'ledgerVersion': 2,
  'asOfServerSeq': 3,
  'asOfAtMs': 1,
});
OnlineReadPage page(
  List<HistoryEntry> entries, {
  String? next,
  int snapshot = 4,
}) => OnlineReadPage(
  records: entries,
  snapshotAtMs: snapshot,
  page: ApiPage(next == null ? null : PageCursor.fromJson(next), next != null),
  balance: balance(),
  shopName: 'Shop',
  customerName: 'Customer',
  linkId: 'link_1',
);
void main() {
  test('Fetches every page of a fixed snapshot before deriving opening and closing', () async {
    final reader = PageReader([
      page([entry('entry_1', 1, 1000, 1)], next: 'cursor_1'),
      page([entry('entry_2', 3, -200, 2)]),
    ]);
    final statement = await StatementRepository(reader).load(
      'shop_1',
      'link_1',
      DateTime.utc(2026, 1, 2),
      DateTime.utc(2026, 1, 2),
    );
    expect(reader.seen, [null, 'cursor_1']);
    expect(statement.opening, 1000);
    expect(statement.closing, 800);
  });
  test(
    'Changing snapshot or repeated continuation cursor blocks export',
    () async {
      final reader = PageReader([
        page([entry('entry_1', 1, 1000, 1)], next: 'cursor_1'),
        page([entry('entry_2', 3, -200, 2)], snapshot: 5),
      ]);
      await expectLater(
        StatementRepository(reader).load(
          'shop_1',
          'link_1',
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 2),
        ),
        throwsA(anything),
      );
      final repeated = PageReader([
        page([entry('entry_1', 1, 1000, 1)], next: 'cursor_1'),
        page([entry('entry_2', 3, -200, 2)], next: 'cursor_1'),
      ]);
      await expectLater(
        StatementRepository(repeated).load(
          'shop_1',
          'link_1',
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 2),
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'Out of bounds period fails before requesting private history',
    () async {
      final reader = PageReader([]);
      await expectLater(
        StatementRepository(reader).load(
          'shop_1',
          'link_1',
          DateTime.utc(2025, 1, 1),
          DateTime.utc(2026, 1, 2),
        ),
        throwsA(anything),
      );
      expect(reader.seen, isEmpty);
    },
  );
}
