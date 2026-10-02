import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/db/sync_dao.dart';
import 'package:udhaarkhata/core/db/cursor_dao.dart';
import 'package:udhaarkhata/core/db/outbox_dao.dart';
import 'package:udhaarkhata/core/db/migrations.dart';
import 'package:udhaarkhata/core/sync/sync_models.dart';
import 'package:udhaarkhata/core/sync/operation.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';

const syncOperation = '00000000-0000-4000-8000-000000000011';
Map<String, Object?> syncRow({
  String? operation = syncOperation,
  int seq = 1,
  int amount = 50000,
}) => {
  'local_id': 'server_$seq',
  'server_id': 'entry_$seq',
  'server_seq': seq,
  'link_id': 'link',
  'client_operation_id': ?operation,
  'kind': 'credit',
  'amount_paise': amount,
  'effect_paise': amount,
  'occurred_at_ms': 1,
  'created_at_ms': 2,
  'sync_status': 'synced',
};
void main() {
  sqfliteFfiInit();
  final account = OpaqueId.fromJson('owner');
  late Directory root;
  late SqliteAccountDatabase database;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('d12_storage_');
    database = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: root.path,
    );
    await database.openForAccount(account);
    await database.verifyAccount(account, AccountRole.owner, 1);
    await database.transaction(
      account,
      (tx) => tx.insert('cached_links', {
        'id': 'link',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': 'owner',
        'status': 'active',
        'last_verified_at_ms': 1,
      }),
    );
  });
  tearDown(() async {
    await database.lock();
    await root.delete(recursive: true);
  });
  test('bootstrapIdentityAttachesOnce', () async {
    final store = LocalLedgerStore(database, account);
    await store.applyPage('link', [syncRow(operation: null)], 1, 2);
    await store.applyPage('link', [syncRow()], 1, 2);
    expect(
      (await store.entries('link')).single['client_operation_id'],
      syncOperation,
    );
    expect(await store.entries('link'), hasLength(1));
  });
  Map<String, Object?> body({
    String operation = syncOperation,
    int amount = 50000,
  }) => {
    'clientOperationId': operation,
    'linkId': 'link',
    'kind': 'credit',
    'amountPaise': amount,
    'note': null,
    'dueDate': null,
    'occurredAtMs': 1,
  };
  SyncEntry entry({
    String operation = syncOperation,
    int seq = 1,
    int amount = 50000,
  }) => SyncEntry.fromJson({
    'id': 'entry_$seq',
    'serverSeq': seq,
    'shopId': 'shop',
    'linkId': 'link',
    'clientOperationId': operation,
    'kind': 'credit',
    'amountPaise': amount,
    'targetAmountPaise': null,
    'effectPaise': amount,
    'note': null,
    'paymentMethod': null,
    'dueDate': null,
    'correctsEntryId': null,
    'revision': 0,
    'correctionReason': null,
    'occurredAtMs': 1,
    'createdAtMs': 2,
    'createdByUserId': 'owner',
  });
  SyncPage page({
    int seq = 1,
    int amount = 50000,
    int balance = 50000,
    int version = 1,
    String operation = syncOperation,
  }) => SyncPage.fromJson({
    'items': [
      {
        'id': 'entry_$seq',
        'serverSeq': seq,
        'shopId': 'shop',
        'linkId': 'link',
        'clientOperationId': operation,
        'kind': 'credit',
        'amountPaise': amount,
        'targetAmountPaise': null,
        'effectPaise': amount,
        'note': null,
        'paymentMethod': null,
        'dueDate': null,
        'correctsEntryId': null,
        'revision': 0,
        'correctionReason': null,
        'occurredAtMs': 1,
        'createdAtMs': 2,
        'createdByUserId': 'owner',
      },
    ],
    'link': {
      'id': 'link',
      'shopId': 'shop',
      'customerUserId': 'customer',
      'ownerUserId': 'owner',
      'displayName': 'Customer',
      'nickname': null,
      'linkedAtMs': 1,
      'status': 'active',
    },
    'nextCursor': null,
    'hasMore': false,
    'snapshotAtMs': 3,
    'highWaterSeq': seq,
    'appliedThroughSeq': seq,
    'balance': {
      'balancePaise': balance,
      'ledgerVersion': version,
      'asOfServerSeq': seq,
      'asOfAtMs': 2,
    },
  });
  Future<void> pending({
    String operation = syncOperation,
    int amount = 50000,
  }) async {
    final original = body(operation: operation, amount: amount),
        command = LocalOperation('owner', 'shop', original);
    await LocalLedgerStore(database, account).savePending(
      {
        'local_id': operation,
        'link_id': 'link',
        'client_operation_id': operation,
        'kind': 'credit',
        'amount_paise': amount,
        'effect_paise': amount,
        'occurred_at_ms': 1,
        'sync_status': 'pending',
      },
      command.payload,
      command.hash,
      1,
    );
  }

  test('ackIsAtomicAndDoesNotAdvanceCursor', () async {
    await pending();
    final dao = SyncDao(database, account, database.generation);
    await expectLater(
      dao.acknowledge('shop', body(), entry(amount: 40000)),
      throwsStateError,
    );
    expect(await OutboxDao(database, account).entries(), hasLength(1));
    await dao.acknowledge('shop', body(), entry(seq: 50));
    expect(
      await CursorDao(database, account, database.generation).sequence('link'),
      0,
    );
    expect(await OutboxDao(database, account).entries(), isEmpty);
    expect(
      (await LocalLedgerStore(database, account).entries('link'))
          .single['local_id'],
      syncOperation,
    );
  });
  test('pageRollbackLeavesCursor', () async {
    await pending();
    final dao = SyncDao(database, account, database.generation);
    await expectLater(
      dao.applyPage('shop', 'link', page(balance: 1)),
      throwsStateError,
    );
    expect(
      await CursorDao(database, account, database.generation).sequence('link'),
      0,
    );
    expect(await OutboxDao(database, account).entries(), hasLength(1));
    await dao.applyPage('shop', 'link', page());
    expect(
      await CursorDao(database, account, database.generation).sequence('link'),
      1,
    );
    expect(await LocalLedgerStore(database, account).balance('link'), {
      'synced_paise': 50000,
      'pending_paise': 0,
    });
    expect(
      await database.transaction(
        account,
        (tx) => tx.rawQuery('PRAGMA foreign_key_check'),
      ),
      isEmpty,
    );
  });
  test('sameAccountOldGenerationRejected', () async {
    final generation = database.generation;
    final dao = SyncDao(database, account, generation);
    await database.lock();
    await database.openForAccount(account);
    await expectLater(dao.applyPage('shop', 'link', page()), throwsStateError);
    await expectLater(
      database.transaction(
        account,
        (tx) => tx.query('outbox'),
        expectedGeneration: generation,
      ),
      throwsStateError,
    );
  });
  test('rejectRetainsBodyAndBlocksSuccessors', () async {
    await pending();
    const next = '00000000-0000-4000-8000-000000000012';
    await pending(operation: next, amount: 1);
    final before = await OutboxDao(database, account).entries();
    await SyncDao(
      database,
      account,
      database.generation,
    ).reject(syncOperation, 'BALANCE_CONFLICT');
    final after = await OutboxDao(database, account).entries();
    expect(after[0]['payload'], before[0]['payload']);
    expect(after[0]['request_hash'], before[0]['request_hash']);
    expect(after[0]['state'], 'needs_attention');
    expect(
      await OutboxDao(
        database,
        account,
      ).ready(DateTime.utc(2026), shopId: 'shop'),
      isEmpty,
    );
    expect(
      (await LocalLedgerStore(
        database,
        account,
      ).balance('link'))['pending_paise'],
      1,
    );
  });
  test('jitterScheduleSurvivesReopen', () async {
    await pending();
    final retry = DateTime.utc(2026, 10, 2, 12);
    await SyncDao(
      database,
      account,
      database.generation,
    ).defer(syncOperation, 2, retry, 'RATE_LIMITED');
    await database.lock();
    await database.openForAccount(account);
    expect(
      await OutboxDao(
        database,
        account,
      ).ready(retry.subtract(const Duration(seconds: 1)), shopId: 'shop'),
      isEmpty,
    );
    expect(
      await OutboxDao(database, account).ready(retry, shopId: 'shop'),
      hasLength(1),
    );
  });
  test('upgradeV1V2PreservesOutbox', () async {
    await database.lock();
    for (final version in [1, 2]) {
      final path =
          '${root.path}/account_${sha256.convert(utf8.encode('owner'))}.sqlite';
      await databaseFactoryFfi.deleteDatabase(path);
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: createLocalSchema,
        ),
      );
      await old.insert('local_account', {
        'singleton': 1,
        'user_id': 'owner',
        'role': 'owner',
        'last_verified_at_ms': 1,
      });
      await old.insert('cached_links', {
        'id': 'link',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': 'owner',
        'status': 'active',
        'last_verified_at_ms': 1,
      });
      await old.insert('cached_entries', {
        'local_id': syncOperation,
        'link_id': 'link',
        'client_operation_id': syncOperation,
        'kind': 'credit',
        'amount_paise': 1,
        'effect_paise': 1,
        'occurred_at_ms': 1,
        'sync_status': 'pending',
      });
      await old.insert('outbox', {
        'operation_id': syncOperation,
        'link_id': 'link',
        'payload': '{ "exact": 1 }',
        'request_hash': 'a' * 64,
        'created_at_ms': 1,
      });
      await old.close();
      await database.openForAccount(account);
      final saved = (await OutboxDao(database, account).entries()).single;
      expect(saved['payload'], '{ "exact": 1 }');
      expect(saved['operation_id'], syncOperation);
      expect(saved['request_hash'], 'a' * 64);
      await database.lock();
    }
  });
  test('interleavedAckDoesNotHideEarlierOtherDeviceRows', () async {
    await pending();
    final dao = SyncDao(database, account, database.generation);
    await dao.acknowledge('shop', body(), entry(seq: 50));
    const other = '00000000-0000-4000-8000-000000000014';
    final first = page(
      seq: 40,
      amount: 1,
      balance: 1,
      version: 1,
      operation: other,
    );
    await dao.applyPage('shop', 'link', first);
    expect(
      (await LocalLedgerStore(
        database,
        account,
      ).balance('link'))['synced_paise'],
      50001,
    );
    expect(
      await CursorDao(database, account, database.generation).sequence('link'),
      40,
    );
    await dao.applyPage(
      'shop',
      'link',
      page(seq: 50, balance: 50001, version: 2),
    );
    expect(
      await LocalLedgerStore(database, account).entries('link'),
      hasLength(2),
    );
  });
  test('cacheCapPreservesQueueAndCursor', () async {
    await pending();
    final normal = page();
    final oversized = SyncPage.fromJson({
      'items': [],
      'link': normal.link,
      'nextCursor': null,
      'hasMore': false,
      'snapshotAtMs': 3,
      'highWaterSeq': 10001,
      'appliedThroughSeq': 0,
      'balance': {
        'balancePaise': 1,
        'ledgerVersion': 10001,
        'asOfServerSeq': 10001,
        'asOfAtMs': 2,
      },
    });
    await expectLater(
      SyncDao(
        database,
        account,
        database.generation,
      ).applyPage('shop', 'link', oversized),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'CACHE_TOO_LARGE'),
      ),
    );
    expect(await OutboxDao(database, account).entries(), hasLength(1));
    expect(
      await CursorDao(database, account, database.generation).sequence('link'),
      0,
    );
  });
  test('knownOperationCannotBeChangedOrErased', () async {
    await LocalLedgerStore(
      database,
      account,
    ).applyPage('link', [syncRow()], 1, 2);
    for (final operation in [null, '00000000-0000-4000-8000-000000000015']) {
      await expectLater(
        database.transaction(
          account,
          (tx) =>
              tx.update('cached_entries', {'client_operation_id': operation}),
        ),
        throwsA(isA<DatabaseException>()),
      );
    }
  });
  test('authoritativeChangePreservedWhenProvisionalBecomesNegative', () async {
    final store = LocalLedgerStore(database, account);
    await store.applyPage('link', [syncRow(amount: 500)], 1, 2);
    const operation = '00000000-0000-4000-8000-000000000016';
    await store.savePending(
      {
        'local_id': operation,
        'link_id': 'link',
        'client_operation_id': operation,
        'kind': 'payment',
        'amount_paise': 200,
        'effect_paise': -200,
        'payment_method': 'cash',
        'occurred_at_ms': 1,
        'sync_status': 'pending',
      },
      '{}',
      'a' * 64,
      1,
    );
    final normal = page();
    final change = SyncPage.fromJson({
      'items': [
        {
          'id': 'entry_2',
          'serverSeq': 2,
          'shopId': 'shop',
          'linkId': 'link',
          'clientOperationId': '00000000-0000-4000-8000-000000000017',
          'kind': 'payment',
          'amountPaise': 400,
          'targetAmountPaise': null,
          'effectPaise': -400,
          'note': null,
          'paymentMethod': 'cash',
          'dueDate': null,
          'correctsEntryId': null,
          'revision': 0,
          'correctionReason': null,
          'occurredAtMs': 1,
          'createdAtMs': 2,
          'createdByUserId': 'owner',
        },
      ],
      'link': normal.link,
      'nextCursor': null,
      'hasMore': false,
      'snapshotAtMs': 3,
      'highWaterSeq': 2,
      'appliedThroughSeq': 2,
      'balance': {
        'balancePaise': 100,
        'ledgerVersion': 2,
        'asOfServerSeq': 2,
        'asOfAtMs': 2,
      },
    });
    await SyncDao(
      database,
      account,
      database.generation,
    ).applyPage('shop', 'link', change);
    expect(await store.balance('link'), {
      'synced_paise': 100,
      'pending_paise': -200,
    });
    await expectLater(
      pending(operation: '00000000-0000-4000-8000-000000000018', amount: 1),
      throwsStateError,
    );
    expect(await OutboxDao(database, account).entries(), hasLength(1));
  });
}
