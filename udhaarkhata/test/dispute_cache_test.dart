import 'package:udhaarkhata/features/ledger/online_reads.dart';
import 'package:udhaarkhata/features/settings/privacy_repository.dart';

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/disputes/dispute_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'helpers/sync_fixture.dart';

class DisputeStorage extends MemorySecureStorage {
  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.of(values);
}

Map<String, Object?> item(String id) => {
  'id': id,
  'shopId': 'shop',
  'entryId': 'entry',
  'customerUserId': 'owner',
  'status': 'open',
  'reason': 'Review amount',
  'resolutionNote': null,
  'createdAtMs': 1,
  'resolvedAtMs': null,
};
void main() {
  late SyncFixture fixture;
  late DisputeStorage storage;
  late CloudDisputeRepository repository;
  setUp(() async {
    fixture = SyncFixture();
    await fixture.open();
    await fixture.database.verifyAccount(
      fixture.accountId,
      AccountRole.customer,
      1,
    );
    storage = DisputeStorage();
    repository = CloudDisputeRepository(
      fixture.auth,
      fixture.accountId,
      storage: storage,
      cacheDatabase: fixture.database,
    );
    fixture.auth.handler = (path, body) async => {
      'items': [item('dispute')],
      'hasMore': false,
      'nextCursor': null,
    };
  });
  tearDown(() async => fixture.close());
  void offline() {
    fixture.auth.handler = (path, body) async => throw const AppFailure(
      'NETWORK_ERROR',
      'api.networkError',
      retryable: true,
    );
  }

  test(
    'verified account offline status is read only and request scoped to shop',
    () async {
      expect((await repository.load('shop', true)).offline, false);
      expect(fixture.auth.requests.single.path, '/v1/me/disputes?shopId=shop');
      offline();
      expect((await repository.load('shop', true)).offline, true);
      expect((await repository.load('shop', true)).items.single.id, 'dispute');
    },
  );
  test('expired local grant cannot reveal cached dispute', () async {
    await repository.load('shop', true);
    var now = DateTime.utc(2026, 10, 2);
    fixture.database.requireLocalAccess(
      now.add(const Duration(hours: 1)),
      () => now,
    );
    now = now.add(const Duration(hours: 2));
    offline();
    await expectLater(repository.load('shop', true), throwsStateError);
    await expectLater(
      repository.statusForEntry(OpaqueId.fromJson('entry')),
      throwsStateError,
    );
  });
  test('locked database denies cached status', () async {
    await repository.load('shop', true);
    await fixture.database.lock();
    offline();
    await expectLater(repository.load('shop', true), throwsStateError);
  });
  test(
    'account switch during request prevents storing or returning snapshot',
    () async {
      fixture.auth.handler = (path, body) async {
        await fixture.database.openForAccount(OpaqueId.fromJson('other'));
        return {
          'items': [item('dispute')],
          'hasMore': false,
          'nextCursor': null,
        };
      };
      await expectLater(repository.load('shop', true), throwsStateError);
      expect(storage.values, isEmpty);
    },
  );
  test('removed relation clears disk and in-memory cached status', () async {
    await repository.load('shop', true);
    await repository.clearCache('shop');
    offline();
    expect(storage.values, isEmpty);
    expect(await repository.statusForEntry(OpaqueId.fromJson('entry')), null);
    await expectLater(
      repository.load('shop', true),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'terminal permission denial invalidates snapshots before offline use',
    () async {
      await repository.load('shop', true);
      fixture.auth.handler = (path, body) async =>
          throw const AppFailure('FORBIDDEN', 'auth.forbidden');
      await expectLater(
        repository.load('shop', true),
        throwsA(isA<AppFailure>()),
      );
      expect(storage.values, isEmpty);
      offline();
      await expectLater(
        repository.load('shop', true),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('relation removal during pending online read prevents late cache repopulation', () async {
    final response = Completer<Object?>();
    fixture.auth.handler = (path, body) => response.future;
    final pending = repository.load('shop', true);
    await repository.clearCache('shop');
    response.complete({
      'items': [item('dispute')],
      'hasMore': false,
      'nextCursor': null,
    });
    await expectLater(pending, throwsA(isA<AppFailure>()));
    expect(storage.values, isEmpty);
  });
  test('pagination fetches every page and refuses duplicate cursor', () async {
    fixture.auth.handler = (path, body) async => path.contains('before=')
        ? {
            'items': [item('older')],
            'hasMore': false,
            'nextCursor': null,
          }
        : {
            'items': [item('newer')],
            'hasMore': true,
            'nextCursor': 'newer',
          };
    expect((await repository.load('shop', true)).items, hasLength(2));
    expect(fixture.auth.requests.last.path, contains('before=newer'));
    fixture.auth.handler = (path, body) async => {
      'items': [item('newer')],
      'hasMore': true,
      'nextCursor': 'newer',
    };
    await expectLater(
      repository.load('shop', true),
      throwsA(isA<AppFailure>()),
    );
    expect(storage.values, isEmpty);
  });
  test('history revocation clears previously cached disputes', () async {
    await repository.load('shop', true);
    final reads = OnlineReadRepository(
      fixture.auth,
      fixture.accountId,
      AccountRole.customer,
      storage: storage,
      cacheDatabase: fixture.database,
    );
    fixture.auth.handler = (path, body) async =>
        throw const AppFailure('NOT_FOUND', 'api.notFound');
    await expectLater(
      reads.load(
        '/v1/me/ledgers/shop/entries',
        OnlineReadKind.history,
        shopId: 'shop',
      ),
      throwsA(isA<AppFailure>()),
    );
    offline();
    await expectLater(
      repository.load('shop', true),
      throwsA(isA<AppFailure>()),
    );
    expect(storage.values, isEmpty);
  });

  test(
    'confirmed removal clears captured caches after caller leaves',
    () async {
      await repository.load('shop', true);
      final reply = Completer<Object?>();
      fixture.auth.handler = (path, body) => reply.future;
      final privacy = PrivacyRepository(fixture.auth, fixture.accountId);
      final pending = privacy.removeAccess('shop');
      // No widget, ref or mounted state is needed after launching the command.
      reply.complete({});
      await pending;
      expect(storage.values, isEmpty);
      offline();
      await expectLater(
        repository.load('shop', true),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'cold session denial clears persisted disputes before repository exists',
    () async {
      await repository.load('shop', true);
      final fresh = SyncFixture();
      await fresh.open();
      try {
        await fresh.database.verifyAccount(
          fresh.accountId,
          AccountRole.customer,
          1,
        );
        final reads = OnlineReadRepository(
          fresh.auth,
          fresh.accountId,
          AccountRole.customer,
          storage: storage,
          cacheDatabase: fresh.database,
        );
        fresh.auth.handler = (path, body) async =>
            throw const AppFailure('NOT_FOUND', 'api.notFound');
        await expectLater(
          reads.load('/v1/me/shops', OnlineReadKind.shops),
          throwsA(isA<AppFailure>()),
        );
        expect(storage.values, isEmpty);
        final disputes = CloudDisputeRepository(
          fresh.auth,
          fresh.accountId,
          storage: storage,
          cacheDatabase: fresh.database,
        );
        fresh.auth.handler = (path, body) async => throw const AppFailure(
          'NETWORK_ERROR',
          'api.networkError',
          retryable: true,
        );
        await expectLater(
          disputes.load('shop', true),
          throwsA(isA<AppFailure>()),
        );
      } finally {
        await fresh.close();
      }
    },
  );

  test(
    'revoked inflight history cannot return its formerly authorized page',
    () async {
      final reads = OnlineReadRepository(
        fixture.auth,
        fixture.accountId,
        AccountRole.customer,
        storage: storage,
        cacheDatabase: fixture.database,
      );
      final response = Completer<Object?>();
      fixture.auth.handler = (path, body) => response.future;
      final load = reads.load('/v1/me/shops', OnlineReadKind.shops);
      final rejected = expectLater(load, throwsA(isA<AppFailure>()));
      await reads.revocation.revoke();
      response.complete({
        'links': [],
        'snapshotAtMs': 1,
        'page': {'hasMore': false, 'nextCursor': null},
      });
      await rejected;
      expect(storage.values, isEmpty);
    },
  );
}
