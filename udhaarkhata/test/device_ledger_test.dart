import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/migrations.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/sync/save_local.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

class DeviceAuth extends AuthRepository {
  String? failure;
  bool inconsistent = false, paged = false, tooLarge = false;
  final paths = <String>[];
  final bodies = <Map<String, Object?>>[];
  @override
  Future<Account?> restoreSession() async => null;
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    paths.add(path);
    if (body != null) bodies.add(body);
    if (failure != null) {
      throw AppFailure(
        failure!,
        'api.networkError',
        retryable: failure == 'NETWORK_ERROR',
      );
    }
    if (!path.contains('/entries')) {
      return {
        'id': 'link',
        'shopId': 'shop',
        'customerUserId': 'customer',
        'customerDisplayName': 'Customer',
        'shopNickname': null,
        'status': 'active',
        'linkedAtMs': 1,
        'balancePaise': 50000,
        'ledgerVersion': 1,
      };
    }
    final continuation = Uri.parse(path).queryParameters['cursor'] != null;
    return {
      'shopId': 'shop',
      'linkId': 'link',
      'shopName': 'Shop',
      'customerDisplayName': 'Customer',
      'snapshotAtMs': 2,
      'balance': {
        'balancePaise': inconsistent ? 49999 : 50000,
        'ledgerVersion': tooLarge ? 10001 : 1,
        'asOfServerSeq': 1,
        'asOfAtMs': 1,
      },
      'entries': paged && !continuation
          ? [entry]
          : paged
          ? []
          : [entry],
      'page': {
        'hasMore': paged && !continuation,
        'nextCursor': paged && !continuation ? 'cursor-2' : null,
      },
    };
  }

  Map<String, Object?> get entry => {
    'id': 'server_credit',
    'serverSeq': 1,
    'shopId': 'shop',
    'linkId': 'link',
    'kind': 'credit',
    'amountPaise': 50000,
    'effectPaise': 50000,
    'note': 'Rice',
    'paymentMethod': null,
    'dueDate': null,
    'targetAmountPaise': null,
    'correctsEntryId': null,
    'revision': 0,
    'correctionReason': null,
    'occurredAtMs': 1,
    'createdAtMs': 1,
    'createdByUserId': 'owner',
  };
}

void main() {
  sqfliteFfiInit();
  final account = OpaqueId.fromJson('owner'),
      shop = OpaqueId.fromJson('shop'),
      link = OpaqueId.fromJson('link');
  late Directory directory;
  late SqliteAccountDatabase database;
  late DeviceAuth auth;
  late MemorySecureStorage secure;
  late DeviceLedgerRepository repo;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('udhaar_d11_');
    database = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    await database.openForAccount(account);
    await database.verifyAccount(account, AccountRole.owner, 1);
    auth = DeviceAuth();
    secure = MemorySecureStorage();
    repo = DeviceLedgerRepository(auth, account, secure, database);
  });
  tearDown(() async {
    await database.lock();
    await directory.delete(recursive: true);
  });
  test('local credit/payment commit without HTTP and replay the provisional balance', () async {
    await repo.prepareCustomer(shop, link);
    final reads = auth.paths.length;
    auth.failure = 'NETWORK_ERROR';
    final credit = await repo.begin(
      shop,
      link,
      'Customer',
      20000,
      ' Salt ',
      '2026-10-05',
    );
    final payment = await repo.beginPayment(
      shop,
      link,
      'Customer',
      10000,
      'upi',
    );
    final snapshot = (await repo.snapshot(shop, link))!;
    expect(snapshot.syncedPaise, 50000);
    expect(snapshot.pendingPaise, 10000);
    expect(snapshot.provisionalPaise, 60000);
    expect(snapshot.entries.map((e) => e['sync_status']), [
      'synced',
      'pending',
      'pending',
    ]);
    expect(auth.paths.length, reads);
    expect(auth.bodies, isEmpty);
    final queue = await repo.outbox();
    expect(queue.map((e) => e['operation_id']), [
      credit.operationId,
      payment.operationId,
    ]);
    expect(jsonDecode(queue.first['payload'] as String), credit.body);
    expect(jsonDecode(queue.last['payload'] as String), payment.body);
    expect(queue.first['request_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
  });
  test('reopened database preserves queue order, identity and cached customer offline', () async {
    await repo.prepareCustomer(shop, link);
    final one = await repo.begin(shop, link, 'Customer', 1, null, null);
    final two = await repo.beginPayment(shop, link, 'Customer', 2, 'cash');
    await database.lock();
    database = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    await database.openForAccount(account);
    await database.verifyAccount(account, AccountRole.owner, 2);
    repo = DeviceLedgerRepository(auth, account, secure, database);
    auth.failure = 'NETWORK_ERROR';
    expect((await repo.prepareCustomer(shop, link)).displayName, 'Customer');
    expect((await repo.outbox()).map((e) => e['operation_id']), [
      one.operationId,
      two.operationId,
    ]);
    expect((await repo.snapshot(shop, link))!.provisionalPaise, 49999);
  });
  test(
    'offline overpayment and concurrent payments roll back every failed write',
    () async {
      await repo.prepareCustomer(shop, link);
      await expectLater(
        repo.beginPayment(shop, link, 'Customer', 50001, 'cash'),
        throwsA(isA<AppFailure>()),
      );
      expect(await repo.outbox(), isEmpty);
      final results = await Future.wait(
        [30000, 30000].map((amount) async {
          try {
            await repo.beginPayment(shop, link, 'Customer', amount, 'cash');
            return true;
          } on AppFailure {
            return false;
          }
        }),
      );
      expect(results.where((ok) => ok), hasLength(1));
      expect(await repo.outbox(), hasLength(1));
      expect((await repo.snapshot(shop, link))!.provisionalPaise, 20000);
    },
  );
  test('forced outbox failure rolls back entry and balance', () async {
    await repo.prepareCustomer(shop, link);
    await database.transaction(
      account,
      (tx) => tx.execute(
        "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'disk failure'); END",
      ),
    );
    await expectLater(
      repo.begin(shop, link, 'Customer', 100, null, null),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repo.outbox(), isEmpty);
    expect((await repo.snapshot(shop, link))!.entries, hasLength(1));
    expect((await repo.snapshot(shop, link))!.provisionalPaise, 50000);
  });
  test(
    'inconsistent server snapshot never becomes an offline payment baseline',
    () async {
      auth.inconsistent = true;
      await expectLater(
        repo.prepareCustomer(shop, link),
        throwsA(isA<AppFailure>()),
      );
      expect(await repo.snapshot(shop, link), isNull);
      await expectLater(
        repo.beginPayment(shop, link, 'Customer', 1, 'cash'),
        throwsA(isA<AppFailure>()),
      );
      expect(await repo.outbox(), isEmpty);
    },
  );
  test('account switch locks cached reads and local writes, retains original queue', () async {
    await repo.prepareCustomer(shop, link);
    await repo.begin(shop, link, 'Customer', 1, null, null);
    final other = OpaqueId.fromJson('other');
    await database.openForAccount(other);
    await database.verifyAccount(other, AccountRole.owner, 2);
    await expectLater(repo.snapshot(shop, link), throwsStateError);
    await expectLater(
      repo.begin(shop, link, 'Customer', 1, null, null),
      throwsA(anything),
    );
    final otherRepo = DeviceLedgerRepository(auth, other, secure, database);
    expect(await otherRepo.snapshot(shop, link), isNull);
    expect(await otherRepo.outbox(), isEmpty);
    await database.openForAccount(account);
    expect(await repo.outbox(), hasLength(1));
  });
  test('explicit access denial locks cached customer without discarding pending money', () async {
    await repo.prepareCustomer(shop, link);
    await repo.begin(shop, link, 'Customer', 1, null, null);
    auth.failure = 'FORBIDDEN';
    await expectLater(
      repo.prepareCustomer(shop, link, refresh: true),
      throwsA(isA<AppFailure>()),
    );
    expect(await repo.snapshot(shop, link), isNull);
    expect(await repo.outbox(), hasLength(1));
    await expectLater(
      repo.begin(shop, link, 'Customer', 1, null, null),
      throwsA(isA<AppFailure>()),
    );
  });
  test('unresolved legacy command blocks replacement and retains original identity', () async {
    await repo.prepareCustomer(shop, link);
    final legacy = CloudLedgerRepository(auth, account, secure);
    final saved = await legacy.begin(shop, link, 'Customer', 500, null, null);
    await expectLater(
      repo.begin(shop, link, 'Customer', 1, null, null),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      repo.beginPayment(shop, link, 'Customer', 1, 'cash'),
      throwsA(isA<AppFailure>()),
    );
    expect((await repo.pending(shop, link))!.operationId, saved.operationId);
    expect(await repo.outbox(), isEmpty);
  });
  test(
    'complete paged bootstrap caches acknowledged entries exactly once',
    () async {
      auth.paged = true;
      await repo.prepareCustomer(shop, link);
      expect(auth.paths.where((p) => p.contains('/entries')), hasLength(2));
      await repo.prepareCustomer(shop, link, refresh: true);
      expect((await repo.snapshot(shop, link))!.entries, hasLength(1));
      expect(await repo.outbox(), isEmpty);
    },
  );
  test(
    'unknown, wrong-shop and customer-role local commands cannot save',
    () async {
      await expectLater(
        repo.begin(shop, link, 'Customer', 1, null, null),
        throwsA(isA<AppFailure>()),
      );
      await repo.prepareCustomer(shop, link);
      await expectLater(
        repo.begin(
          OpaqueId.fromJson('other_shop'),
          link,
          'Customer',
          1,
          null,
          null,
        ),
        throwsA(isA<AppFailure>()),
      );
      await database.verifyAccount(account, AccountRole.customer, 2);
      await expectLater(
        repo.beginPayment(shop, link, 'Customer', 1, 'cash'),
        throwsStateError,
      );
      expect(await repo.outbox(), isEmpty);
    },
  );
  test(
    'oversized history refuses offline bootstrap without partial cache',
    () async {
      auth.tooLarge = true;
      await expectLater(
        repo.prepareCustomer(shop, link),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'CACHE_TOO_LARGE'),
        ),
      );
      expect(await repo.snapshot(shop, link), isNull);
      expect(auth.paths.where((p) => p.contains('/entries')), hasLength(1));
    },
  );
  test('atomic local writer verifies the shop as well as the link', () async {
    await repo.prepareCustomer(shop, link);
    await expectLater(
      SaveLocal(LocalLedgerStore(database, account))('other_shop', {
        'clientOperationId': '00000000-0000-4000-8000-000000000001',
        'linkId': 'link',
        'kind': 'credit',
        'amountPaise': 1,
        'note': null,
        'dueDate': null,
        'occurredAtMs': 1,
      }),
      throwsStateError,
    );
    expect(await repo.outbox(), isEmpty);
  });
  test('v1 migration preserves existing pending/outbox bytes', () async {
    await database.lock();
    final oldPath = '${directory.path}/old.sqlite';
    final old = await databaseFactoryFfi.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(version: 1, onCreate: createLocalSchema),
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
      'local_id': 'local',
      'link_id': 'link',
      'client_operation_id': '00000000-0000-4000-8000-000000000001',
      'kind': 'credit',
      'amount_paise': 1,
      'effect_paise': 1,
      'occurred_at_ms': 1,
      'sync_status': 'pending',
    });
    await old.insert('outbox', {
      'operation_id': '00000000-0000-4000-8000-000000000001',
      'link_id': 'link',
      'payload': '{}',
      'request_hash': 'a' * 64,
      'created_at_ms': 1,
    });
    final before = await old.query('outbox');
    await old.close();
    final upgraded = await databaseFactoryFfi.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(
        version: localSchemaVersion,
        onUpgrade: upgradeLocalSchema,
      ),
    );
    expect(await upgraded.query('outbox'), before);
    expect(await upgraded.query('cached_entries'), hasLength(1));
    expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await upgraded.close();
  });
}
