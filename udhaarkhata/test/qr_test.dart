import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/session_store.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/network/api_client.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/qr/qr_model.dart';
import 'package:udhaarkhata/features/qr/qr_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

class QrAuth extends AuthRepository {
  String id = 'a' * 64;
  bool offline = false, lost = false;
  bool rateLimited = false;
  int rotations = 0;
  @override
  Future<Account?> restoreSession() async => null;
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (offline) throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    if (path.endsWith('rotate')) {
      if (rateLimited) {
        throw const AppFailure('RATE_LIMITED', 'api.rateLimited');
      }
      rotations++;
      id = 'b' * 64;
      if (lost) throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    }
    return {
      'version': 1,
      'publicQrId': id,
      'payload': 'udhaar://customer/v1/$id',
    };
  }
}

void main() {
  sqfliteFfiInit();
  test('rejected rotation recovers current QR and retains an explicit failure notice', () async {
    final auth = QrAuth(),
        repo = CloudQrRepository(
          auth,
          OpaqueId.fromJson('customer'),
          MemorySecureStorage(),
        );
    final original = await repo.current();
    auth.rateLimited = true;
    final result = await repo.rotate();
    expect(result.qr.publicId, original.qr.publicId);
    expect(result.noticeKey, 'api.rateLimited');
  });
  test('offline refresh after real access expiry preserves QR without preserving uncertain credentials', () async {
    final directory = await Directory.systemTemp.createTemp('qr-expiry');
    final db = SqliteAccountDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    final storage = MemorySecureStorage(), store = SessionStore(storage);
    var offline = false;
    final auth = GoogleAuthRepository(
      api: ApiClient(
        MockClient((request) async {
          if (offline) throw http.ClientException('offline');
          final data = request.url.path.endsWith('google')
              ? {
                  'account': {
                    'id': 'customer',
                    'role': 'customer',
                    'displayName': 'Synthetic',
                    'createdAtMs': 1,
                  },
                  'accessToken': 'a' * 64,
                  'refreshToken': 'b' * 64,
                  'accessExpiresAtMs': 9999999999999,
                }
              : {
                  'version': 1,
                  'publicQrId': 'c' * 64,
                  'payload': 'udhaar://customer/v1/${'c' * 64}',
                };
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
      final account = await auth.signIn(AccountRole.customer);
      final repo = CloudQrRepository(auth, account.id, storage);
      await repo.current();
      final container = ProviderContainer(
        overrides: [qrRepositoryProvider.overrideWithValue(repo)],
      );
      try {
        await container.read(qrProvider.future);
        await store.save({
          'accessToken': 'a' * 64,
          'refreshToken': 'b' * 64,
          'accessExpiresAtMs': 1,
        });
        offline = true;
        await container.read(qrProvider.notifier).refresh();
        expect(container.read(qrProvider).hasError, false);
        expect(container.read(qrProvider).hasValue, true);
        expect(container.read(qrProvider).value!.cached, true);
        expect(container.read(qrProvider).value!.needsSignIn, true);
        expect(await store.read(), null);
        await expectLater(
          db.transaction(account.id, (tx) => tx.query('cached_links')),
          throwsStateError,
        );
      } finally {
        container.dispose();
      }
    } finally {
      await db.lock();
      await directory.delete(recursive: true);
    }
  });
  test('QR decoder accepts only the exact versioned lookup payload', () {
    final id = 'a' * 64;
    expect(
      CustomerQr.fromJson({
        'version': 1,
        'publicQrId': id,
        'payload': 'udhaar://customer/v1/$id',
      }).payload,
      'udhaar://customer/v1/$id',
    );
    for (final payload in [
      'https://evil/$id',
      'udhaar://customer/v2/$id',
      'udhaar://customer/v1/$id?token=secret',
    ]) {
      expect(
        () => CustomerQr.fromJson({
          'version': 1,
          'publicQrId': id,
          'payload': payload,
        }),
        throwsFormatException,
      );
    }
  });
  test('cached QR survives repository recreation, stays account isolated, and lost rotation recovers by read', () async {
    final storage = MemorySecureStorage(),
        auth = QrAuth(),
        a = OpaqueId.fromJson('a'),
        b = OpaqueId.fromJson('b');
    final repo = CloudQrRepository(auth, a, storage);
    expect(await repo.cached(), null);
    final first = await repo.current();
    auth.offline = true;
    expect(
      (await CloudQrRepository(auth, a, storage).cached())!.qr.payload,
      first.qr.payload,
    );
    expect(await CloudQrRepository(auth, b, storage).cached(), null);
    await expectLater(repo.rotate(), throwsA(isA<AppFailure>()));
    await expectLater(
      repo.cached(),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'QR_RECOVERY_REQUIRED'),
      ),
    );
    auth.offline = false;
    await repo
        .rotate(); // Pending rotation must recover by GET, not rotate again.
    expect(auth.rotations, 0);
    auth.lost = true;
    final rotated = await repo.rotate();
    expect(auth.rotations, 1);
    expect(rotated.qr.publicId, 'b' * 64);
    expect(jsonEncode(storage.values), isNot(contains('accessToken')));
  });
}
