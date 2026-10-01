import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;

class PaymentAuth extends AuthRepository {
  bool loseResponse = true, wrongScope = false, reject = false;
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
    if (reject) {
      throw const AppFailure('BALANCE_CONFLICT', 'payment.balanceConflict');
    }
    if (loseResponse) {
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    }
    return {
      'entry': {
        'id': 'entry',
        'shopId': wrongScope ? 'other' : 'shop',
        'linkId': 'link',
        'kind': 'payment',
        'amountPaise': body['amountPaise'],
        'effectPaise': -(body['amountPaise'] as int),
        'paymentMethod': body['paymentMethod'],
        'note': null,
        'dueDate': null,
        'occurredAtMs': body['occurredAtMs'],
        'createdAtMs': 1,
        'serverSeq': 2,
      },
      'balance': {
        'balancePaise': 30000,
        'ledgerVersion': 2,
        'asOfServerSeq': 2,
        'asOfAtMs': 1,
      },
      'replayed': true,
    };
  }
}

void main() {
  final shop = OpaqueId.fromJson('shop'),
      link = OpaqueId.fromJson('link'),
      owner = OpaqueId.fromJson('owner');
  test('payment lost response survives restart and identical retry; unresolved payment blocks new credit/payment', () async {
    final auth = PaymentAuth(),
        storage = MemorySecureStorage(),
        repo = CloudLedgerRepository(auth, owner, storage);
    final attempt = await repo.beginPayment(
      shop,
      link,
      'Customer',
      20000,
      'cash',
    );
    await expectLater(
      repo.submitPayment(shop, attempt),
      throwsA(isA<AppFailure>()),
    );
    final restarted = CloudLedgerRepository(auth, owner, storage),
        saved = (await restarted.pendingPayment(shop, link))!;
    expect(saved.rejected, false);
    expect(jsonEncode(saved.attempt.body), jsonEncode(attempt.body));
    await expectLater(
      restarted.beginPayment(shop, link, 'Customer', 1, 'upi'),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      restarted.begin(shop, link, 'Customer', 1, null, null),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      restarted.reviewRejectedPayment(shop, link),
      throwsA(isA<AppFailure>()),
    );
    auth.loseResponse = false;
    expect(
      (await restarted.submitPayment(shop, saved.attempt)).balancePaise,
      30000,
    );
    expect(auth.requests[0], auth.requests[1]);
    expect(await restarted.pendingPayment(shop, link), null);
  });
  test('known overpayment remains saved after restart; explicit review archives rejection before corrected command', () async {
    final auth = PaymentAuth()..reject = true,
        storage = MemorySecureStorage(),
        repo = CloudLedgerRepository(auth, owner, storage);
    final attempt = await repo.beginPayment(
      shop,
      link,
      'Customer',
      50000,
      'upi',
    );
    await expectLater(
      repo.submitPayment(shop, attempt),
      throwsA(isA<AppFailure>()),
    );
    final restarted = CloudLedgerRepository(auth, owner, storage);
    expect((await restarted.pendingPayment(shop, link))!.rejected, true);
    await expectLater(
      restarted.submitPayment(shop, attempt),
      throwsA(isA<AppFailure>()),
    );
    expect(auth.requests.length, 1);
    await restarted.reviewRejectedPayment(shop, link);
    expect(
      storage.values.values.any((text) => text.contains(attempt.operationId)),
      true,
    );
    final corrected = await restarted.beginPayment(
      shop,
      link,
      'Customer',
      20000,
      'cash',
    );
    expect(corrected.operationId, isNot(attempt.operationId));
    expect(corrected.amountPaise, 20000);
  });
  test('pending credit blocks payment; invalid values do not save; account and receipt scope isolate payments', () async {
    final auth = PaymentAuth()
          ..loseResponse = false
          ..wrongScope = true,
        storage = MemorySecureStorage(),
        repo = CloudLedgerRepository(auth, owner, storage);
    for (final amount in [0, -1, 10000001]) {
      await expectLater(
        repo.beginPayment(shop, link, 'Customer', amount, 'cash'),
        throwsA(isA<AppFailure>()),
      );
    }
    await expectLater(
      repo.beginPayment(shop, link, 'Customer', 1, 'bank'),
      throwsA(isA<AppFailure>()),
    );
    expect(storage.values, isEmpty);
    final attempt = await repo.beginPayment(
      shop,
      link,
      'Customer',
      20000,
      'upi',
    );
    await expectLater(
      repo.submitPayment(shop, attempt),
      throwsA(isA<AppFailure>()),
    );
    expect(await repo.pendingPayment(shop, link), isNotNull);
    final other = CloudLedgerRepository(
      auth,
      OpaqueId.fromJson('other'),
      storage,
    );
    expect(await other.pendingPayment(shop, link), null);
    await expectLater(
      other.submitPayment(shop, attempt),
      throwsA(isA<AppFailure>()),
    );
    expect(auth.requests.length, 1);
    final separate = CloudLedgerRepository(auth, owner, MemorySecureStorage());
    await separate.begin(shop, link, 'Customer', 50000, null, null);
    await expectLater(
      separate.beginPayment(shop, link, 'Customer', 20000, 'cash'),
      throwsA(isA<AppFailure>()),
    );
  });
}
