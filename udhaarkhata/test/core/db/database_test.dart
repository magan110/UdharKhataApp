import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteAccountDatabase store;
  final account = OpaqueId.fromJson('owner_A');
  final other = OpaqueId.fromJson('owner_a');
  const operation = '00000000-0000-4000-8000-000000000001';
  final pending = <String, Object?>{
    'local_id': 'local1',
    'link_id': 'link',
    'client_operation_id': operation,
    'kind': 'credit',
    'amount_paise': 50000,
    'effect_paise': 50000,
    'occurred_at_ms': 1,
    'sync_status': 'pending',
  };
  Future<void> seed() async {
    await store.openForAccount(account);
    await store.verifyAccount(account, AccountRole.owner, 1);
    await store.transaction(
      account,
      (db) => db.insert('cached_links', {
        'id': 'link',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': account.value,
        'verified_qr_id': 'qr',
        'status': 'active',
        'last_verified_at_ms': 1,
      }),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('udhaar_d03_');
    store = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
  });
  tearDown(() async {
    await store.lock();
    await directory.delete(recursive: true);
  });

  test(
    'restored entries without operation IDs persist and replay by server ID',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      final restored = {
        ...pending,
        'local_id': 'restored',
        'server_id': 'server1',
        'server_seq': 1,
        'sync_status': 'synced',
      }..remove('client_operation_id');
      await repository.applyPage('link', [restored], 1, 2);
      await repository.applyPage(
        'link',
        [
          {...restored, 'local_id': 'other_local'},
        ],
        1,
        2,
      );
      expect(await repository.entries('link'), [restored]);
      expect(await repository.balance('link'), {
        'synced_paise': 50000,
        'pending_paise': 0,
      });
    },
  );
  test('incomplete acknowledgment cannot clear an outbox command', () async {
    await seed();
    final repository = LocalLedgerStore(store, account);
    await repository.savePending(
      {...pending, 'note': 'Original'},
      '{}',
      'a' * 64,
      1,
    );
    final synced = {
      ...pending,
      'server_id': 'server1',
      'server_seq': 1,
      'sync_status': 'synced',
    };
    final incomplete = {...synced}
      ..remove('kind')
      ..remove('amount_paise')
      ..remove('effect_paise');
    for (final row in [incomplete, synced]) {
      await expectLater(
        repository.applyPage('link', [row], 1, 2),
        throwsStateError,
      );
      expect(
        (await store.transaction(account, (db) => db.query('outbox'))).length,
        1,
      );
      expect(await repository.cursor('link'), isNull);
    }
  });
  test(
    'an established server identity or sequence cannot be reassigned',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      final synced = {
        ...pending,
        'server_id': 'server1',
        'server_seq': 1,
        'sync_status': 'synced',
      };
      await repository.applyPage('link', [synced], 1, 2);
      await expectLater(
        repository.applyPage(
          'link',
          [
            {...synced, 'server_id': 'server2'},
          ],
          1,
          2,
        ),
        throwsStateError,
      );
      await expectLater(
        repository.applyPage(
          'link',
          [
            {...synced, 'server_seq': 2},
          ],
          2,
          2,
        ),
        throwsStateError,
      );
    },
  );
  test('maximum length account IDs can open an isolated database', () async {
    await store.openForAccount(OpaqueId.fromJson('A' * 128));
    expect(
      await store.transaction(
        OpaqueId.fromJson('A' * 128),
        (db) => db.query('local_account'),
      ),
      hasLength(1),
    );
  });
  test('entry and original outbox survive close and reopen', () async {
    await seed();
    final repository = LocalLedgerStore(store, account);
    await repository.savePending(pending, '{"amountPaise":50000}', 'a' * 64, 1);
    await store.lock();
    await store.openForAccount(account);
    expect(await repository.entries('link'), [pending]);
    final outbox = await store.transaction(account, (db) => db.query('outbox'));
    expect(outbox.single['operation_id'], operation);
    expect(outbox.single['payload'], '{"amountPaise":50000}');
    expect(await repository.balance('link'), {
      'synced_paise': 0,
      'pending_paise': 50000,
    });
    expect(
      await store.transaction(
        account,
        (db) => db.rawQuery('PRAGMA foreign_key_check'),
      ),
      isEmpty,
    );
  });
  test(
    'failed outbox insert rolls back entry and provisional balance',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      await expectLater(
        repository.savePending(pending, '{}', 'invalid', 1),
        throwsA(isA<DatabaseException>()),
      );
      expect(await repository.entries('link'), isEmpty);
      expect(await repository.balance('link'), {
        'synced_paise': 0,
        'pending_paise': 0,
      });
    },
  );
  test(
    'cache page and cursor roll back together and successful page replays',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      final synced = {
        ...pending,
        'server_id': 'server1',
        'server_seq': 1,
        'sync_status': 'synced',
      };
      await expectLater(
        repository.applyPage('link', [synced], 1, -1),
        throwsA(isA<DatabaseException>()),
      );
      expect(await repository.entries('link'), isEmpty);
      expect(await repository.cursor('link'), isNull);
      await repository.applyPage('link', [synced], 1, 2);
      await repository.applyPage('link', [synced], 1, 2);
      expect(await repository.entries('link'), [synced]);
      expect(await repository.cursor('link'), {
        'sequence': 1,
        'last_sync_at_ms': 2,
      });
      expect(await repository.balance('link'), {
        'synced_paise': 50000,
        'pending_paise': 0,
      });
    },
  );
  test(
    'account switch locks stale repository and preserves original pending',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      await repository.savePending(pending, '{}', 'a' * 64, 1);
      await store.openForAccount(other);
      await expectLater(repository.entries('link'), throwsStateError);
      expect(await LocalLedgerStore(store, other).entries('link'), isEmpty);
      await store.openForAccount(account);
      expect(await repository.entries('link'), [pending]);
      await store.lock();
      await expectLater(repository.entries('link'), throwsStateError);
    },
  );
  test(
    'repeat open retains schema version and pending; downgrade fails closed',
    () async {
      await seed();
      await LocalLedgerStore(
        store,
        account,
      ).savePending(pending, '{}', 'a' * 64, 1);
      expect(
        await store.transaction(
          account,
          (db) => db.rawQuery('PRAGMA user_version'),
        ),
        [
          {'user_version': 1},
        ],
      );
      await store.transaction(
        account,
        (db) => db.execute('PRAGMA user_version=2'),
      );
      await store.lock();
      await expectLater(store.openForAccount(account), throwsStateError);
    },
  );
  test(
    'malformed rows, money overflow and command mutation are rejected',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      for (final changes in <Map<String, Object?>>[
        {'amount_paise': null},
        {'amount_paise': 1.5},
        {'effect_paise': 9007199254740992},
        {'kind': 'invalid'},
        {'effect_paise': 1},
      ]) {
        await expectLater(
          repository.savePending({...pending, ...changes}, '{}', 'a' * 64, 1),
          throwsA(isA<DatabaseException>()),
        );
      }
      await expectLater(
        repository.savePending(
          {...pending, 'link_id': 'missing'},
          '{}',
          'a' * 64,
          1,
        ),
        throwsStateError,
      );
      await repository.savePending(pending, '{}', 'a' * 64, 1);
      await expectLater(
        store.transaction(
          account,
          (db) => db.update('outbox', {'payload': 'changed'}),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        store.transaction(
          account,
          (db) => db.update('cached_entries', {'amount_paise': 1}),
        ),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test('customers and unverified links cannot queue owner commands', () async {
    await seed();
    await store.verifyAccount(account, AccountRole.customer, 2);
    final repository = LocalLedgerStore(store, account);
    await expectLater(
      repository.savePending(pending, '{}', 'a' * 64, 1),
      throwsStateError,
    );
  });
  test(
    'acknowledgment preserves local identity and removes outbox atomically',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      await repository.savePending(pending, '{}', 'a' * 64, 1);
      await repository.applyPage(
        'link',
        [
          {
            ...pending,
            'local_id': 'server1',
            'server_id': 'server1',
            'server_seq': 1,
            'sync_status': 'synced',
          },
        ],
        1,
        2,
      );
      expect((await repository.entries('link')).single['local_id'], 'local1');
      expect(
        await store.transaction(account, (db) => db.query('outbox')),
        isEmpty,
      );
      expect(await repository.balance('link'), {
        'synced_paise': 50000,
        'pending_paise': 0,
      });
    },
  );
  test(
    'page rejects backward or skipping cursors and retains pending on conflict',
    () async {
      await seed();
      final repository = LocalLedgerStore(store, account);
      await repository.savePending(pending, '{}', 'a' * 64, 1);
      final synced = {
        ...pending,
        'server_id': 'server1',
        'server_seq': 1,
        'sync_status': 'synced',
      };
      await expectLater(
        repository.applyPage('link', [synced], 2, 2),
        throwsStateError,
      );
      expect(await repository.cursor('link'), isNull);
      await expectLater(
        repository.applyPage(
          'link',
          [
            {...synced, 'amount_paise': 1},
          ],
          1,
          2,
        ),
        throwsStateError,
      );
      expect(
        (await repository.entries('link')).single['sync_status'],
        'pending',
      );
      expect(
        (await store.transaction(account, (db) => db.query('outbox'))).length,
        1,
      );
      await repository.applyPage('link', [synced], 1, 2);
      await expectLater(
        repository.applyPage('link', [], 0, 2),
        throwsStateError,
      );
    },
  );
}
