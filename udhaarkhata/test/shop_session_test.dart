import 'dart:convert';
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
import 'package:udhaarkhata/features/shop/shop_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

void main() {
  sqfliteFfiInit();
  test('shop calls renew and persist credentials once; stale account cannot access the next account', () async {
    final directory = await Directory.systemTemp.createTemp('shop-auth');
    final db = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    final store = SessionStore(MemorySecureStorage());
    var user = 'a', refreshes = 0, shopCalls = 0;
    var refreshFails = false, protectedFails = false;
    final repo = GoogleAuthRepository(
      api: ApiClient(
        MockClient((request) async {
          Object? data;
          if (request.url.path == '/health') {
            data = {'status': 'ok'};
          } else if (request.url.path.endsWith('google')) {
            data = {
              'account': {
                'id': user,
                'role': 'owner',
                'displayName': 'Synthetic',
                'createdAtMs': 1,
              },
              'accessToken': 'a' * 64,
              'refreshToken': 'b' * 64,
              'accessExpiresAtMs': 1,
            };
          } else if (request.url.path.endsWith('refresh')) {
            if (refreshFails) {
              throw http.ClientException('lost refresh response');
            }
            refreshes++;
            data = {
              'accessToken': 'c' * 64,
              'refreshToken': 'd' * 64,
              'accessExpiresAtMs': 9999999999999,
            };
          } else {
            if (protectedFails) {
              return http.Response(
                jsonEncode({
                  'requestId': 'test',
                  'error': {
                    'code': 'AUTH_REQUIRED',
                    'messageKey': 'auth.required',
                    'retryable': false,
                  },
                }),
                401,
              );
            }
            shopCalls++;
            expect(request.headers['Authorization'], 'Bearer ${'c' * 64}');
            data = request.method == 'GET'
                ? {'shop': null}
                : {
                    'id': 'shop',
                    'name': 'Kiran',
                    'status': 'active',
                    'createdAtMs': 1,
                  };
          }
          return http.Response(
            jsonEncode({'data': data, 'requestId': 'test'}),
            200,
          );
        }),
      ),
      baseUrl: Uri.parse('https://api.test'),
      store: store,
      database: db,
      googleToken: () async => 'synthetic',
    );
    try {
      final a = await repo.signIn(AccountRole.owner);
      final shops = CloudShopRepository(repo, a.id);
      expect(await shops.currentShop(), null);
      expect((await shops.createShop('Kiran')).name, 'Kiran');
      expect(refreshes, 1);
      expect((await store.read())!['refreshToken'], 'd' * 64);
      user = 'b';
      await repo.signIn(AccountRole.owner);
      await expectLater(
        shops.currentShop(),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'AUTH_REQUIRED'),
        ),
      );
      expect(shopCalls, 2);
      final b = await repo.signIn(AccountRole.owner);
      refreshFails = true;
      await expectLater(
        CloudShopRepository(repo, b.id).currentShop(),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'AUTH_REQUIRED'),
        ),
      );
      expect(await store.read(), null);
      await expectLater(
        db.transaction(b.id, (tx) => tx.query('cached_links')),
        throwsStateError,
      );
      refreshFails = false;
      protectedFails = true;
      await repo.signIn(AccountRole.owner);
      await expectLater(
        CloudShopRepository(repo, b.id).currentShop(),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', 'AUTH_REQUIRED'),
        ),
      );
      expect(await store.read(), null);
      await expectLater(
        db.transaction(b.id, (tx) => tx.query('cached_links')),
        throwsStateError,
      );
    } finally {
      await db.lock();
      await directory.delete(recursive: true);
    }
  });
}
