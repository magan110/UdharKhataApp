import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

class CreditAuth extends AuthRepository {
  bool loseResponse = true, wrongScope = false;
  Future<void>? wait;
  final requests = <Map<String, Object?>>[];
  @override
  Future<Account?> restoreSession() async => null;
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add(Map.of(body!));
    await wait;
    if (loseResponse) {
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    }
    return {
      'entry': {
        'id': 'entry',
        'shopId': wrongScope ? 'other' : 'shop',
        'linkId': 'link',
        'kind': 'credit',
        'amountPaise': body['amountPaise'],
        'effectPaise': body['amountPaise'],
        'note': body['note'],
        'dueDate': body['dueDate'],
        'occurredAtMs': body['occurredAtMs'],
        'createdAtMs': 1,
        'serverSeq': 1,
      },
      'balance': {
        'balancePaise': 50000,
        'ledgerVersion': 1,
        'asOfServerSeq': 1,
        'asOfAtMs': 1,
      },
      'replayed': true,
    };
  }
}

void main() {
  final shop = OpaqueId.fromJson('shop'), link = OpaqueId.fromJson('link');
  test('credit confirmation survives restart, retries identical body and blocks replacement', () async {
    final auth = CreditAuth(), storage = MemorySecureStorage();
    final repo = CloudLedgerRepository(
      auth,
      OpaqueId.fromJson('owner'),
      storage,
    );
    final attempt = await repo.begin(
      shop,
      link,
      'Customer',
      50000,
      ' Rice ',
      null,
    );
    expect(storage.values.values.single, contains(attempt.operationId));
    await expectLater(repo.submit(shop, attempt), throwsA(isA<AppFailure>()));
    final restarted = CloudLedgerRepository(
      auth,
      OpaqueId.fromJson('owner'),
      storage,
    );
    final saved = (await restarted.pending(shop, link))!;
    expect(jsonEncode(saved.body), jsonEncode(attempt.body));
    await expectLater(
      restarted.begin(shop, link, 'Customer', 1, null, null),
      throwsA(isA<AppFailure>()),
    );
    auth.loseResponse = false;
    expect((await restarted.submit(shop, saved)).balancePaise, 50000);
    expect(auth.requests[0], auth.requests[1]);
    expect(await restarted.pending(shop, link), null);
  });
  test('wrong response scope retains uncertain command and other account cannot use it', () async {
    final auth = CreditAuth()
          ..loseResponse = false
          ..wrongScope = true,
        storage = MemorySecureStorage();
    final repo = CloudLedgerRepository(
      auth,
      OpaqueId.fromJson('owner'),
      storage,
    );
    final attempt = await repo.begin(shop, link, 'Customer', 50000, null, null);
    await expectLater(repo.submit(shop, attempt), throwsA(isA<AppFailure>()));
    expect(await repo.pending(shop, link), isNotNull);
    final other = CloudLedgerRepository(
      auth,
      OpaqueId.fromJson('other'),
      storage,
    );
    expect(await other.pending(shop, link), null);
    await expectLater(other.submit(shop, attempt), throwsA(isA<AppFailure>()));
    expect(auth.requests.length, 1);
  });
}
