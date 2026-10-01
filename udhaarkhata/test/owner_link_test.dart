import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/qr/owner_qr_model.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

class LinkAuth extends AuthRepository {
  final requests = <Map<String, Object?>>[];
  bool loseResponse = false;
  Object? response;
  @override
  Future<Account?> restoreSession() async => null;
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add({'account': account.value, 'path': path, 'body': body});
    if (loseResponse) {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    }
    return response ?? linkJson;
  }
}

final linkJson = <String, Object?>{
  'id': 'link',
  'shopId': 'shop',
  'customerUserId': 'customer',
  'customerDisplayName': 'Synthetic Customer',
  'shopNickname': null,
  'status': 'active',
  'linkedAtMs': 1,
  'balancePaise': 0,
  'ledgerVersion': 0,
};
void main() {
  final shop = OpaqueId.fromJson('shop'),
      account = OpaqueId.fromJson('owner'),
      id = 'a' * 64;
  test('pending confirmation keys cannot alias accounts and shops with underscores', () async {
    final storage = MemorySecureStorage(), auth = LinkAuth();
    final first = CloudOwnerLinkRepository(
      auth,
      OpaqueId.fromJson('owner_a'),
      storage,
    );
    await first.begin(
      OpaqueId.fromJson('b'),
      ResolvedCustomer(id, 'Customer', null),
      null,
    );
    expect(
      await CloudOwnerLinkRepository(
        auth,
        OpaqueId.fromJson('owner'),
        storage,
      ).pending(OpaqueId.fromJson('a_b')),
      null,
    );
  });
  test('scanner parser accepts exact bounded v1 payload and distinguishes unsupported from invalid', () {
    expect(parseOwnerQr('udhaar://customer/v1/$id'), id);
    expect(
      () => parseOwnerQr('udhaar://customer/v2/$id'),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'QR_UNSUPPORTED'),
      ),
    );
    for (final value in [
      'https://evil/$id',
      'udhaar://customer/v1/$id?token=x',
      'udhaar://customer/v1/${id.toUpperCase()}',
      'x' * 10000,
      'udhaar://customer/v1/$id\n',
    ]) {
      expect(
        () => parseOwnerQr(value),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'QR_INVALID')),
      );
    }
  });
  test('resolve only reads; durable confirmation survives restart and retries identical body', () async {
    final auth = LinkAuth(), storage = MemorySecureStorage();
    final repo = CloudOwnerLinkRepository(auth, account, storage);
    auth.response = {
      'state': 'new',
      'customerDisplayName': 'Synthetic Customer',
      'linkId': null,
    };
    final resolved = await repo.resolve(shop, id);
    expect(auth.requests.single['path'], '/v1/customer-qr/resolve');
    expect(await repo.pending(shop), null);
    final attempt = await repo.begin(shop, resolved, ' Local Name ');
    expect(
      attempt.operationId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    auth.loseResponse = true;
    await expectLater(repo.submit(shop, attempt), throwsA(isA<AppFailure>()));
    final body = auth.requests.last['body'];
    final restored = CloudOwnerLinkRepository(auth, account, storage);
    final pending = await restored.pending(shop);
    expect(pending!.operationId, attempt.operationId);
    expect(pending.nickname, 'Local Name');
    expect(
      await CloudOwnerLinkRepository(
        auth,
        OpaqueId.fromJson('other'),
        storage,
      ).pending(shop),
      null,
    );
    expect(await restored.pending(OpaqueId.fromJson('different')), null);
    auth.loseResponse = false;
    auth.response = {...linkJson, 'shopNickname': 'Local Name'};
    expect((await restored.submit(shop, pending)).id.value, 'link');
    expect(auth.requests.last['body'], body);
    expect(await restored.pending(shop), null);
    expect(jsonEncode(storage.values), isNot(contains('accessToken')));
  });
  test('invalid response cannot discard an uncertain confirmation or show another shop', () async {
    final auth = LinkAuth(),
        repo = CloudOwnerLinkRepository(auth, account, MemorySecureStorage());
    final attempt = await repo.begin(
      shop,
      ResolvedCustomer(id, 'Customer', null),
      null,
    );
    auth.response = {...linkJson, 'shopId': 'other'};
    await expectLater(
      repo.submit(shop, attempt),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
    expect((await repo.pending(shop))!.operationId, attempt.operationId);
  });
  test(
    'request is never posted if durable confirmation cannot be stored',
    () async {
      final auth = LinkAuth(),
          repo = CloudOwnerLinkRepository(auth, account, FailingLinkStorage());
      await expectLater(
        repo.begin(shop, ResolvedCustomer(id, 'Customer', null), null),
        throwsA(isA<StateError>()),
      );
      expect(auth.requests, isEmpty);
    },
  );
  test('new scan cannot replace an unresolved confirmation', () async {
    final repo = CloudOwnerLinkRepository(
      LinkAuth(),
      account,
      MemorySecureStorage(),
    );
    final first = await repo.begin(
      shop,
      ResolvedCustomer(id, 'Customer', null),
      null,
    );
    await expectLater(
      repo.begin(shop, ResolvedCustomer('b' * 64, 'Other', null), null),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'LINK_PENDING')),
    );
    expect((await repo.pending(shop))!.operationId, first.operationId);
  });
}

class FailingLinkStorage extends MemorySecureStorage {
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
  }) async => throw StateError('storage unavailable');
}
