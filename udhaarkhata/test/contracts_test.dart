import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';

void main() {
  final fixtures = jsonObject(
    jsonDecode(File('../contracts/d02-fixtures.json').readAsStringSync()),
  );
  final valid = jsonObject(fixtures['valid']);
  test(
    'Dart accepts the same primitives and account fixture as TypeScript',
    () {
      expect(OpaqueId.fromJson(valid['id']).value, valid['id']);
      expect(MoneyPaise.fromJson(valid['moneyPaise']).value, 50000);
      expect(timestampMs(valid['timestampMs']), valid['timestampMs']);
      expect(PageCursor.fromJson(valid['cursor']).value, valid['cursor']);
      expect(Account.fromJson(fixtures['account']).role, AccountRole.owner);
      expect(MoneyPaise.fromJson(-50000).value, -50000);
      expect(MoneyPaise.fromJson(maxSafeInteger).value, maxSafeInteger);
    },
  );
  test('Dart rejects the same malformed primitive fixtures as TypeScript', () {
    final parsers = <String, Object Function(Object?)>{
      'invalidMoney': MoneyPaise.fromJson,
      'invalidIds': OpaqueId.fromJson,
      'invalidTimestamps': timestampMs,
      'invalidCursors': PageCursor.fromJson,
    };
    for (final entry in parsers.entries) {
      for (final value in fixtures[entry.key] as List<Object?>) {
        expect(() => entry.value(value), throwsFormatException);
      }
    }
    expect(() => OpaqueId.fromJson('x' * 129), throwsFormatException);
    expect(() => PageCursor.fromJson('x' * 2049), throwsFormatException);
    expect(
      () => Account.fromJson({
        ...jsonObject(fixtures['account']),
        'role': 'admin',
      }),
      throwsFormatException,
    );
  });
  test('success, page, and error envelopes decode from shared fixtures', () {
    final success = ApiSuccess.fromJson(fixtures['success'], jsonObject);
    expect(success.data['status'], 'ok');
    expect(success.requestId, 'req_synthetic');
    final page = ApiSuccess.fromJson(
      fixtures['page'],
      (value) => value as List<Object?>,
    );
    expect(page.page?.hasMore, false);
    expect(page.page?.nextCursor, isNull);
    final error = AppFailure.fromJson(fixtures['error']);
    expect(error.code, 'AUTH_REQUIRED');
    expect(error.messageKey, 'auth.required');
    expect(error.retryable, false);
  });
  test('malformed envelopes and inconsistent paging cannot silently pass', () {
    expect(() => ApiSuccess.fromJson({}, jsonObject), throwsFormatException);
    expect(() => jsonObject([]), throwsFormatException);
    expect(() => jsonString(null), throwsFormatException);
    expect(() => ApiPage.fromJson({'hasMore': 'yes'}), throwsFormatException);
    expect(
      () => ApiPage.fromJson({'hasMore': true, 'nextCursor': null}),
      throwsFormatException,
    );
    final page = ApiPage.fromJson({
      'hasMore': true,
      'nextCursor': valid['cursor'],
    });
    expect(page.nextCursor?.value, valid['cursor']);
    expect(
      () => AppFailure.fromJson({
        'error': {'retryable': 'yes'},
      }),
      throwsFormatException,
    );
  });
}
