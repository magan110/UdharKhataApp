import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/session_store.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/network/api_client.dart';
import 'package:udhaarkhata/core/network/contracts.dart';

class MemorySecureStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  sqfliteFfiInit();
  test('server role opens its own database; signout preserves pending rows and locks it', () async {
    final directory = await Directory.systemTemp.createTemp('auth-test');
    final db = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    final storage = MemorySecureStorage();
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('logout')) return http.Response('', 204);
        return http.Response(
          jsonEncode({
            'requestId': 'test',
            'data': {
              'account': {
                'id': 'owner_a',
                'role': 'owner',
                'displayName': 'Synthetic',
                'createdAtMs': 1,
              },
              'accessToken': 'a' * 64,
              'refreshToken': 'b' * 64,
              'accessExpiresAtMs': 9999999999999,
            },
          }),
          200,
        );
      }),
    );
    final repo = GoogleAuthRepository(
      api: api,
      baseUrl: Uri.parse('https://api.test'),
      store: SessionStore(storage),
      database: db,
      googleToken: () async => 'synthetic',
    );
    final account = await repo.signIn(AccountRole.owner);
    expect(account.role, AccountRole.owner);
    await db.transaction(
      account.id,
      (tx) => tx.insert('cached_links', {
        'id': 'link',
        'shop_id': 'shop',
        'customer_user_id': 'customer',
        'owner_user_id': 'owner_a',
        'last_verified_at_ms': 1,
        'status': 'active',
      }),
    );
    await LocalLedgerStore(db, account.id).savePending(
      {
        'local_id': 'local',
        'link_id': 'link',
        'client_operation_id': '00000000-0000-4000-8000-000000000001',
        'kind': 'credit',
        'amount_paise': 100,
        'effect_paise': 100,
        'occurred_at_ms': 1,
        'sync_status': 'pending',
      },
      'original',
      'a' * 64,
      1,
    );
    expect(await repo.pendingCount(), 1);
    final result = await repo.signOut();
    expect(result.remoteRevoked, true);
    expect(result.pendingCount, 1);
    await expectLater(
      db.transaction(account.id, (tx) => tx.query('cached_links')),
      throwsStateError,
    );
    await db.openForAccount(OpaqueId.fromJson('owner_b'));
    expect(
      await db.transaction(
        OpaqueId.fromJson('owner_b'),
        (tx) => tx.query('outbox'),
      ),
      isEmpty,
    );
    await db.openForAccount(account.id);
    expect(
      await db.transaction(account.id, (tx) => tx.query('cached_links')),
      hasLength(1),
    );
    await db.lock();
    await directory.delete(recursive: true);
  });
  test('uncertain refresh requires reauthentication and leaves cached account data locked', () async {
    final directory = await Directory.systemTemp.createTemp('auth-test');
    final db = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    final store = SessionStore(MemorySecureStorage());
    await store.save({
      'accessToken': 'a' * 64,
      'refreshToken': 'b' * 64,
      'accessExpiresAtMs': 1,
    });
    final repo = GoogleAuthRepository(
      api: ApiClient(
        MockClient((_) async => throw http.ClientException('offline')),
      ),
      baseUrl: Uri.parse('https://api.test'),
      store: store,
      database: db,
      googleToken: () async => 'synthetic',
    );
    await expectLater(repo.restoreSession(), throwsA(anything));
    expect(await store.read(), isNull);
    await db.lock();
    await directory.delete(recursive: true);
  });
  testWidgets(
    'stalled profile after rotation exits loading with a bounded network failure',
    (tester) async {
      final store = SessionStore(MemorySecureStorage());
      await store.save({
        'accessToken': 'a' * 64,
        'refreshToken': 'b' * 64,
        'accessExpiresAtMs': 1,
      });
      var profileStarted = false;
      Object? failure;
      final repo = GoogleAuthRepository(
        api: ApiClient(
          MockClient((request) async {
            if (request.url.path.endsWith('refresh')) {
              return http.Response(
                jsonEncode({
                  'requestId': 'test',
                  'data': {
                    'accessToken': 'c' * 64,
                    'refreshToken': 'd' * 64,
                    'accessExpiresAtMs': 9999999999999,
                  },
                }),
                200,
              );
            }
            profileStarted = true;
            return Completer<http.Response>().future;
          }),
        ),
        baseUrl: Uri.parse('https://api.test'),
        store: store,
        database: SqliteAccountDatabase(factory: databaseFactoryFfi),
        googleToken: () async => 'synthetic',
      );
      unawaited(
        repo.restoreSession().then<void>(
          (_) {},
          onError: (Object error, StackTrace _) {
            failure = error;
          },
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(profileStarted, true);
      await tester.pump(const Duration(seconds: 21));
      expect(failure, isNotNull);
      expect((await store.read())!['refreshToken'], 'd' * 64);
    },
  );
}
