import 'dart:io';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/qr_link_dao.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/qr/owner_qr_model.dart';

import 'customer_shops_test.dart' show ProfileAuth;
import 'device_ledger_test.dart' show DeviceAuth;

import 'package:udhaarkhata/features/ledger/online_reads.dart';

import 'owner_link_test.dart' show linkJson, LinkAuth;
import 'auth_session_test.dart' show MemorySecureStorage;

import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';
import 'package:udhaarkhata/features/qr/resolve_controller.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late SqliteAccountDatabase db;
  final owner = OpaqueId.fromJson('owner');
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qr_cache_');
    db = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: dir.path,
    );
    await db.openForAccount(owner);
    await db.verifyAccount(owner, AccountRole.owner, 1);
  });
  tearDown(() async {
    await db.lock();
    await dir.delete(recursive: true);
  });
  test(
    'verified QR requires acknowledged snapshot and account/shop/active scope',
    () async {
      final dao = QrLinkDao(db, owner), qr = 'a' * 64;
      final link = CustomerLink.fromJson(linkJson);
      await dao.cache(qr, link);
      expect(await dao.lookup('shop', publicId: qr), null);
      await db.transaction(
        owner,
        (tx) => tx.insert('owner_ledger_snapshots', {
          'link_id': link.id.value,
          'balance_paise': 0,
          'ledger_version': 0,
          'server_seq': 0,
          'snapshot_at_ms': 1,
        }),
      );
      expect((await dao.lookup('shop', publicId: qr))!.id.value, link.id.value);
      expect(await dao.lookup('other-shop', publicId: qr), null);
      expect(await dao.lookup('shop', publicId: 'b' * 64), null);
      await dao.invalidate('shop', publicId: qr);
      expect(await dao.lookup('shop', publicId: qr), null);
      await dao.cache('b' * 64, link);
      await db.transaction(
        owner,
        (tx) => tx.update('cached_links', {'status': 'access_removed'}),
      );
      expect(await dao.lookup('shop', publicId: 'b' * 64), null);
      await db.openForAccount(OpaqueId.fromJson('another-owner'));
      expect(() => dao.lookup('shop', publicId: qr), throwsStateError);
    },
  );
  test('known offline scan opens cached ledger, terminal revoked response invalidates QR', () async {
    final dao = QrLinkDao(db, owner), qr = 'a' * 64;
    final link = CustomerLink.fromJson(linkJson);
    await dao.cache(qr, link);
    await db.transaction(
      owner,
      (tx) => tx.insert('owner_ledger_snapshots', {
        'link_id': link.id.value,
        'balance_paise': 0,
        'ledger_version': 0,
        'server_seq': 0,
        'snapshot_at_ms': 1,
      }),
    );
    final auth = OfflineQrAuth();
    final controller = ResolveController(
      CloudOwnerLinkRepository(
        auth,
        owner,
        MemorySecureStorage(),
        qrCache: dao,
      ),
      OpaqueId.fromJson('shop'),
    );
    await controller.initialize();
    await controller.scan('udhaar://customer/v1/$qr');
    expect(controller.stage, ScanStage.linked);
    expect(controller.link!.id.value, link.id.value);
    expect(
      auth.requests.every((r) => !(r['path'] as String).endsWith('/customers')),
      true,
    );
    controller.rescan();
    auth.revoked = true;
    await controller.scan('udhaar://customer/v1/$qr');
    expect(controller.stage, ScanStage.failed);
    expect((controller.error as AppFailure).code, 'QR_REVOKED');
    expect(await dao.lookup('shop', publicId: qr), null);
    controller.dispose();
  });
  test('customer offline cache is server-only, dated, account scoped and locked on sign-out', () async {
    await db.verifyAccount(owner, AccountRole.customer, 1);
    final auth = ProfileAuth()
      ..profile = {
        'links': [
          {
            'id': 'link',
            'shopId': 'shop',
            'shopName': 'Shop',
            'balancePaise': 250,
          },
        ],
        'linksHasMore': false,
      };
    final storage = MemorySecureStorage();
    final repo = OnlineReadRepository(
      auth,
      owner,
      AccountRole.customer,
      storage: storage,
      cacheDatabase: db,
    );
    final online = await repo.load('/v1/me/ledgers', OnlineReadKind.shops);
    expect(online.offline, false);
    auth.offline = true;
    final cached = await repo.load('/v1/me/ledgers', OnlineReadKind.shops);
    expect(cached.offline, true);
    expect(cached.snapshotAtMs, online.snapshotAtMs);
    expect((cached.records.single as ShopLedger).balance, 250);
    await db.openForAccount(OpaqueId.fromJson('other-customer'));
    await db.verifyAccount(
      OpaqueId.fromJson('other-customer'),
      AccountRole.customer,
      1,
    );
    final other = OnlineReadRepository(
      auth,
      OpaqueId.fromJson('other-customer'),
      AccountRole.customer,
      storage: storage,
      cacheDatabase: db,
    );
    await expectLater(
      other.load('/v1/me/ledgers', OnlineReadKind.shops),
      throwsA(isA<AppFailure>()),
    );
    await db.lock();
    expect(
      () => repo.load('/v1/me/ledgers', OnlineReadKind.shops),
      throwsStateError,
    );
  });
  for (final code in ['CAPACITY_UNAVAILABLE', 'QR_INVALID', 'FORBIDDEN']) {
    test('$code known QR policy and unknown never creates a link', () async {
      final dao = QrLinkDao(db, owner), qr = 'a' * 64;
      final link = CustomerLink.fromJson(linkJson);
      await dao.cache(qr, link);
      await db.transaction(
        owner,
        (tx) => tx.insert('owner_ledger_snapshots', {
          'link_id': link.id.value,
          'balance_paise': 0,
          'ledger_version': 0,
          'server_seq': 0,
          'snapshot_at_ms': 1,
        }),
      );
      final auth = OfflineQrAuth()..failureCode = code;
      final repo = CloudOwnerLinkRepository(
        auth,
        owner,
        MemorySecureStorage(),
        qrCache: dao,
      );
      if (code == 'CAPACITY_UNAVAILABLE') {
        expect(
          (await repo.resolve(OpaqueId.fromJson('shop'), qr)).linkId!.value,
          link.id.value,
        );
        await expectLater(
          repo.resolve(OpaqueId.fromJson('shop'), 'b' * 64),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.messageKey,
              'guidance',
              'link.internetNeeded',
            ),
          ),
        );
      } else {
        await expectLater(
          repo.resolve(OpaqueId.fromJson('shop'), qr),
          throwsA(isA<AppFailure>().having((e) => e.code, 'terminal', code)),
        );
        expect(await dao.lookup('shop', publicId: qr), null);
        if (code == 'FORBIDDEN') {
          expect(await dao.lookup('shop', linkId: link.id.value), null);
        }
      }
      expect(await repo.pending(OpaqueId.fromJson('shop')), null);
      expect(await db.transaction(owner, (tx) => tx.query('outbox')), isEmpty);
    });
  }
  test('replacement phone downloads acknowledged server view without pending restore', () async {
    final auth = ProfileAuth()
      ..profile = {
        'links': [
          {
            'id': 'link',
            'shopId': 'shop',
            'shopName': 'Shop',
            'balancePaise': 250,
          },
        ],
        'linksHasMore': false,
      };
    final phone = await Directory.systemTemp.createTemp('replacement_phone_');
    final fresh = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: phone.path,
    );
    try {
      await fresh.openForAccount(owner);
      await fresh.verifyAccount(owner, AccountRole.customer, 1);
      final repo = OnlineReadRepository(
        auth,
        owner,
        AccountRole.customer,
        storage: EnumerableSecureStorage(),
        cacheDatabase: fresh,
      );
      auth.offline = true;
      await expectLater(
        repo.load('/v1/me/ledgers', OnlineReadKind.shops),
        throwsA(isA<AppFailure>()),
      );
      auth.offline = false;
      expect(
        ((await repo.load(
                  '/v1/me/ledgers',
                  OnlineReadKind.shops,
                )).records.single
                as ShopLedger)
            .balance,
        250,
      );
      expect(
        await fresh.transaction(owner, (tx) => tx.query('outbox')),
        isEmpty,
      );
      auth.offline = true;
      expect(
        (await repo.load('/v1/me/ledgers', OnlineReadKind.shops)).offline,
        true,
      );
      await repo.clearShopCache('shop');
      await expectLater(
        repo.load('/v1/me/ledgers', OnlineReadKind.shops),
        throwsA(isA<AppFailure>()),
      );
    } finally {
      await fresh.lock();
      await phone.delete(recursive: true);
    }
  });
  test(
    'known relationship denial clears list and every cached history page',
    () async {
      await db.verifyAccount(owner, AccountRole.customer, 1);
      final auth = CacheDenialAuth();
      final storage = EnumerableSecureStorage();
      final repo = OnlineReadRepository(
        auth,
        owner,
        AccountRole.customer,
        storage: storage,
        cacheDatabase: db,
      );
      await repo.load('/v1/me/ledgers', OnlineReadKind.shops);
      await repo.load(
        '/v1/me/ledgers/shop/entries',
        OnlineReadKind.history,
        shopId: 'shop',
      );
      await repo.load(
        '/v1/me/ledgers/shop/entries',
        OnlineReadKind.history,
        shopId: 'shop',
        cursor: 'next_page',
      );
      expect(storage.values.length, 3);
      final response = Completer<Object?>();
      auth.delayedShops = response.future;
      final olderRead = repo.load('/v1/me/ledgers', OnlineReadKind.shops);
      final olderRejected = expectLater(
        olderRead,
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'revoked', 'FORBIDDEN'),
        ),
      );
      auth.denied = true;
      await expectLater(
        repo.load(
          '/v1/me/ledgers/shop/entries',
          OnlineReadKind.history,
          shopId: 'shop',
        ),
        throwsA(isA<AppFailure>().having((e) => e.code, 'denial', 'NOT_FOUND')),
      );
      response.complete({
        'links': [
          {
            'id': 'link',
            'shopId': 'shop',
            'shopName': 'Shop',
            'balancePaise': 50000,
            'ledgerVersion': 1,
          },
        ],
        'snapshotAtMs': 2,
        'page': {'hasMore': false, 'nextCursor': null},
      });
      await olderRejected;
      expect(storage.values, isEmpty);
      auth.delayedShops = null;
      auth.denied = false;
      auth.failure = 'NETWORK_ERROR';
      await expectLater(
        repo.load('/v1/me/ledgers', OnlineReadKind.shops),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.load(
          '/v1/me/ledgers/shop/entries',
          OnlineReadKind.history,
          shopId: 'shop',
        ),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.load(
          '/v1/me/ledgers/shop/entries',
          OnlineReadKind.history,
          shopId: 'shop',
          cursor: 'next_page',
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('customer account cannot cache owner QR relationships', () async {
    await db.verifyAccount(owner, AccountRole.customer, 1);
    expect(
      () =>
          QrLinkDao(db, owner).cache('a' * 64, CustomerLink.fromJson(linkJson)),
      throwsStateError,
    );
  });
}

class OfflineQrAuth extends LinkAuth {
  bool revoked = false;
  String failureCode = 'NETWORK_ERROR';
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add({'path': path, 'body': body});
    throw revoked
        ? const AppFailure('QR_REVOKED', 'qr.invalid')
        : AppFailure(
            failureCode,
            'api.networkError',
            retryable:
                failureCode == 'NETWORK_ERROR' ||
                failureCode == 'CAPACITY_UNAVAILABLE',
          );
  }
}

class EnumerableSecureStorage extends MemorySecureStorage {
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

class CacheDenialAuth extends DeviceAuth {
  bool denied = false;
  Future<Object?>? delayedShops;
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (Uri.parse(path).path == '/v1/me/ledgers' && delayedShops != null) {
      return delayedShops!;
    }
    if (denied) throw const AppFailure('NOT_FOUND', 'api.notFound');
    if (failure != null) return super.cloudRequest(account, path, body: body);
    if (Uri.parse(path).path == '/v1/me/ledgers') {
      return {
        'links': [
          {
            'id': 'link',
            'shopId': 'shop',
            'shopName': 'Shop',
            'balancePaise': 50000,
            'ledgerVersion': 1,
          },
        ],
        'snapshotAtMs': 2,
        'page': {'hasMore': false, 'nextCursor': null},
      };
    }
    return super.cloudRequest(account, path, body: body);
  }
}
