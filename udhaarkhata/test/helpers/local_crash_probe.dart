// Launched explicitly by device_ledger_crash_test; never discovered as a suite.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/db/sync_dao.dart';
import 'package:udhaarkhata/core/sync/sync_models.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/sync/save_local.dart';

void main() {
  test('commit then wait for forced process termination', () async {
    sqfliteFfiInit();
    const directory = String.fromEnvironment('D11_CRASH_DIRECTORY');
    final account = OpaqueId.fromJson('crash_owner');
    final database = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory,
    );
    await database.openForAccount(account);
    await database.verifyAccount(account, AccountRole.owner, 1);
    await database.transaction(account, (tx) async {
      await tx.insert('cached_links', {
        'id': 'link',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': account.value,
        'status': 'active',
        'last_verified_at_ms': 1,
        'display_name': 'Synthetic Customer',
        'linked_at_ms': 1,
      });
      await tx.insert('owner_ledger_snapshots', {
        'link_id': 'link',
        'balance_paise': 0,
        'ledger_version': 0,
        'server_seq': 0,
        'snapshot_at_ms': 1,
      });
    });
    await SaveLocal(LocalLedgerStore(database, account))('shop', {
      'clientOperationId': '00000000-0000-4000-8000-000000000001',
      'linkId': 'link',
      'kind': 'credit',
      'amountPaise': 50000,
      'note': null,
      'dueDate': null,
      'occurredAtMs': 1,
    });
    if (const bool.fromEnvironment('D12_CRASH_AFTER_PAGE')) {
      await SyncDao(database, account, database.generation).applyPage(
        'shop',
        'link',
        SyncPage.fromJson({
          'items': [
            {
              'id': 'entry_1',
              'serverSeq': 1,
              'shopId': 'shop',
              'linkId': 'link',
              'clientOperationId': '00000000-0000-4000-8000-000000000001',
              'kind': 'credit',
              'amountPaise': 50000,
              'targetAmountPaise': null,
              'effectPaise': 50000,
              'note': null,
              'paymentMethod': null,
              'dueDate': null,
              'correctsEntryId': null,
              'revision': 0,
              'correctionReason': null,
              'occurredAtMs': 1,
              'createdAtMs': 2,
              'createdByUserId': 'crash_owner',
            },
          ],
          'link': {
            'id': 'link',
            'shopId': 'shop',
            'customerUserId': 'customer',
            'ownerUserId': 'crash_owner',
            'displayName': 'Synthetic Customer',
            'nickname': null,
            'linkedAtMs': 1,
            'status': 'active',
          },
          'nextCursor': 'synthetic_next',
          'hasMore': true,
          'snapshotAtMs': 3,
          'highWaterSeq': 2,
          'appliedThroughSeq': 1,
          'balance': {
            'balancePaise': 100000,
            'ledgerVersion': 2,
            'asOfServerSeq': 2,
            'asOfAtMs': 2,
          },
        }),
      );
    }
    // Deliberately no close/lock: the parent SIGKILLs the actual Flutter process.
    stdout.writeln('D11_COMMITTED_PID=$pid');
    await Completer<void>().future;
  });
}
