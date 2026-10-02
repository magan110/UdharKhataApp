import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/session_store.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/network/api_client.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

void main() {
  sqfliteFfiInit();
  late Directory root;
  late SqliteAccountDatabase database;
  late SessionStore store;
  late DateTime now;
  late bool offline, refreshLost, denied;
  late String user;
  late List<String> requests;
  late GoogleAuthRepository auth;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('d12_auth_');
    database = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: root.path,
    );
    store = SessionStore(MemorySecureStorage());
    now = DateTime.utc(2026, 10, 2);
    offline = false;
    refreshLost = false;
    denied = false;
    user = 'owner';
    requests = [];
    auth = GoogleAuthRepository(
      api: ApiClient(
        MockClient((r) async {
          requests.add(r.url.path);
          if (offline || (refreshLost && r.url.path.endsWith('/refresh'))) {
            throw http.ClientException('synthetic outage');
          }
          if (denied && r.url.path == '/v1/me') {
            return http.Response(
              jsonEncode({
                'requestId': 'synthetic',
                'error': {
                  'code': 'AUTH_REQUIRED',
                  'messageKey': 'auth.required',
                  'retryable': false,
                },
              }),
              401,
            );
          }
          if (r.url.path.endsWith('/logout')) return http.Response('', 204);
          return http.Response(
            jsonEncode({
              'requestId': 'synthetic',
              'data': {
                'status': 'ok',
                'account': {
                  'id': user,
                  'role': 'owner',
                  'displayName': 'Synthetic',
                  'createdAtMs': 1,
                },
                'accessToken': 'a' * 64,
                'refreshToken': 'b' * 64,
                'accessExpiresAtMs': now
                    .add(const Duration(minutes: 15))
                    .millisecondsSinceEpoch,
              },
            }),
            200,
          );
        }),
      ),
      baseUrl: Uri.parse('https://synthetic.test'),
      store: store,
      database: database,
      googleToken: () async => 'synthetic',
      clock: () => now,
    );
    await auth.signIn(AccountRole.owner);
    requests.clear();
  });
  tearDown(() async {
    await database.lock();
    await root.delete(recursive: true);
  });
  test('offlineColdStartDoesNotRotate', () async {
    await database.lock();
    offline = true;
    final restored = await auth.restoreSession();
    expect(restored!.id.value, 'owner');
    expect(requests, ['/v1/me']);
    expect(auth.offlineAccess, isTrue);
    expect(
      await database.transaction(
        restored.id,
        (tx) => tx.query('local_account'),
      ),
      hasLength(1),
    );
  });
  test('expiredAccessOfflinePreflight', () async {
    now = now.add(const Duration(hours: 1));
    offline = true;
    expect((await auth.restoreSession())!.id.value, 'owner');
    expect(requests, ['/health']);
    expect(await store.read(), isNotNull);
  });
  test('uncertainRefreshClearsGrantKeepsQueue', () async {
    await database.transaction(
      (await auth.restoreSession())!.id,
      (tx) => tx.insert('cached_links', {
        'id': 'link',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': 'owner',
        'status': 'active',
        'last_verified_at_ms': 1,
      }),
    );
    now = now.add(const Duration(hours: 1));
    requests.clear();
    refreshLost = true;
    await expectLater(auth.restoreSession(), throwsA(isA<AppFailure>()));
    expect(requests, ['/health', '/v1/auth/refresh']);
    expect(await store.read(), isNull);
    expect(await store.readLocalGrant(), isNull);
    final account = Account.fromJson({
      'id': 'owner',
      'role': 'owner',
      'displayName': 'Synthetic',
      'createdAtMs': 1,
    });
    await expectLater(
      database.transaction(account.id, (tx) => tx.query('cached_links')),
      throwsStateError,
    );
    await database.openForAccount(account.id);
    expect(
      await database.transaction(account.id, (tx) => tx.query('cached_links')),
      hasLength(1),
    );
  });
  test('thirtyDayGrantCannotRenewOffline', () async {
    final before = (await store.readLocalGrant())!.expiresAtMs;
    offline = true;
    now = now.add(const Duration(days: 29));
    expect(await auth.restoreSession(), isNotNull);
    expect((await store.readLocalGrant())!.expiresAtMs, before);
    now = now.add(const Duration(days: 1));
    await expectLater(auth.restoreSession(), throwsA(isA<AppFailure>()));
  });
  test('futureVerificationAndMissingDatabaseDenied', () async {
    offline = true;
    now = now.subtract(const Duration(minutes: 1));
    await expectLater(auth.restoreSession(), throwsA(isA<AppFailure>()));
    now = DateTime.utc(2026, 10, 2);
    await database.lock();
    for (final file in root.listSync()) {
      file.deleteSync();
    }
    await expectLater(auth.restoreSession(), throwsA(isA<AppFailure>()));
  });
  test('signoutDisablesLocalGrant', () async {
    offline = true;
    final result = await auth.signOut();
    expect(result.remoteRevoked, isFalse);
    expect(await store.readLocalGrant(), isNull);
    expect(await auth.restoreSession(), isNull);
  });
  test('explicitAuthDenialDisablesLocalGrant', () async {
    denied = true;
    expect(await auth.restoreSession(), isNull);
    expect(await store.readLocalGrant(), isNull);
    expect(await store.read(), isNull);
  });
  test('accountSwitchReplacesGrantAndLocksOldNamespace', () async {
    final a = (await auth.restoreSession())!;
    user = 'other';
    final b = await auth.signIn(AccountRole.owner);
    expect((await store.readLocalGrant())!.account.id.value, b.id.value);
    await expectLater(
      database.transaction(a.id, (tx) => tx.query('local_account')),
      throwsStateError,
    );
    offline = true;
    expect((await auth.restoreSession())!.id.value, 'other');
  });
  test('clockRollbackAfterOpenDeniesCache', () async {
    final account = (await auth.restoreSession())!;
    now = now.subtract(const Duration(minutes: 1));
    await expectLater(
      database.transaction(account.id, (tx) => tx.query('local_account')),
      throwsStateError,
    );
  });
  test('lateGenerationCannotCommitTransaction', () async {
    final account = (await auth.restoreSession())!;
    final generation = database.generation;
    final entered = Completer<void>(), release = Completer<void>();
    final transaction = database.transaction(account.id, (tx) async {
      await tx.insert('cached_links', {
        'id': 'late',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': 'owner',
        'status': 'active',
        'last_verified_at_ms': 1,
      });
      entered.complete();
      await release.future;
    }, expectedGeneration: generation);
    final assertion = expectLater(transaction, throwsStateError);
    await entered.future;
    database.invalidateGeneration();
    release.complete();
    await assertion;
    expect(
      await database.transaction(account.id, (tx) => tx.query('cached_links')),
      isEmpty,
    );
  });
}
