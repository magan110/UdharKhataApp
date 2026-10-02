import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/sync/operation.dart';

const operationA = '00000000-0000-4000-8000-000000000021';
const operationB = '00000000-0000-4000-8000-000000000022';
Map<String, Object?> command({
  String operation = operationA,
  String link = 'link',
  int amount = 50000,
}) => {
  'clientOperationId': operation,
  'linkId': link,
  'kind': 'credit',
  'amountPaise': amount,
  'note': null,
  'dueDate': null,
  'occurredAtMs': 1,
};
Map<String, Object?> serverEntry({
  String operation = operationA,
  String link = 'link',
  int seq = 1,
  int amount = 50000,
}) => {
  'id': 'entry_$seq',
  'serverSeq': seq,
  'shopId': 'shop',
  'linkId': link,
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
};
Map<String, Object?> feed({
  String link = 'link',
  List<Map<String, Object?>>? items,
  int balance = 50000,
  int version = 1,
  int high = 1,
  int through = 1,
  String? cursor,
}) => {
  'items': items ?? [serverEntry(link: link)],
  'link': {
    'id': link,
    'shopId': 'shop',
    'customerUserId': 'customer_$link',
    'ownerUserId': 'owner',
    'displayName': 'Synthetic',
    'nickname': null,
    'linkedAtMs': 1,
    'status': 'active',
  },
  'nextCursor': cursor,
  'hasMore': cursor != null,
  'snapshotAtMs': 3,
  'highWaterSeq': high,
  'appliedThroughSeq': through,
  'balance': {
    'balancePaise': balance,
    'ledgerVersion': version,
    'asOfServerSeq': high,
    'asOfAtMs': 2,
  },
};

final class SyncTestAuth extends AuthRepository {
  SyncTestAuth(this.database);
  final SqliteAccountDatabase database;
  final requests = <({String path, Map<String, Object?>? body})>[];
  Future<Object?> Function(String, Map<String, Object?>?)? handler;
  @override
  int get sessionGeneration => database.generation;
  @override
  Future<Account?> restoreSession() async => Account(
    id: OpaqueId.fromJson('owner'),
    role: AccountRole.owner,
    displayName: 'Synthetic',
    createdAtMs: 1,
  );
  @override
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add((path: path, body: body));
    return handler!(path, body);
  }
}

final class SyncFixture {
  late Directory root;
  late SqliteAccountDatabase database;
  late SyncTestAuth auth;
  final accountId = OpaqueId.fromJson('owner');
  Future<void> open() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('d12_sync_');
    database = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: root.path,
    );
    await database.openForAccount(accountId);
    await database.verifyAccount(accountId, AccountRole.owner, 1);
    auth = SyncTestAuth(database);
    await addLink('link');
  }

  Future<void> addLink(String id) =>
      database.transaction(accountId, (tx) async {
        await tx.insert('cached_links', {
          'id': id,
          'shop_id': 'shop',
          'customer_user_id': 'customer_$id',
          'owner_user_id': 'owner',
          'status': 'active',
          'last_verified_at_ms': 1,
        });
        await tx.insert('owner_ledger_snapshots', {
          'link_id': id,
          'balance_paise': 0,
          'ledger_version': 0,
          'server_seq': 0,
          'snapshot_at_ms': 1,
        });
      });
  Future<void> queue({
    String operation = operationA,
    String link = 'link',
    int amount = 50000,
  }) async {
    final body = command(operation: operation, link: link, amount: amount),
        op = LocalOperation('owner', 'shop', body);
    await LocalLedgerStore(database, accountId).savePending(
      {
        'local_id': operation,
        'link_id': link,
        'client_operation_id': operation,
        'kind': 'credit',
        'amount_paise': amount,
        'effect_paise': amount,
        'occurred_at_ms': 1,
        'sync_status': 'pending',
      },
      op.payload,
      op.hash,
      1,
      requireSnapshot: true,
      expectedShopId: 'shop',
    );
  }

  Future<void> close() async {
    await database.lock();
    await root.delete(recursive: true);
  }
}
