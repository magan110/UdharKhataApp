import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:udhaarkhata/core/network/api_client.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/error_classifier.dart';
import 'package:udhaarkhata/core/sync/retry_policy.dart';

void main() {
  test('malformed503RetainsStatus', () async {
    final api = ApiClient(
      MockClient((_) async => http.Response('<html>gateway</html>', 503)),
    );
    try {
      await api.get(Uri.parse('https://synthetic.test'), jsonObject);
      fail('Expected failure');
    } on AppFailure catch (failure) {
      // First pin the absent behavior through existing diagnostic classification.
      expect(failure.code, 'SERVER_ERROR');
      expect(failure.retryable, isTrue);
      expect(failure.httpStatus, 503);
    }
  });
  test('rateLimitHttpDateAndSeconds', () async {
    for (final header in ['7200', 'Fri, 02 Oct 2026 18:00:00 GMT']) {
      final before = DateTime.now().toUtc();
      final api = ApiClient(
        MockClient(
          (_) async =>
              http.Response('gateway', 429, headers: {'retry-after': header}),
        ),
      );
      try {
        await api.post(Uri.parse('https://synthetic.test'), {});
        fail('Expected throttle');
      } on AppFailure catch (failure) {
        expect(failure.httpStatus, 429);
        expect(failure.code, 'RATE_LIMITED');
        if (header == '7200') {
          expect(
            failure.retryAfter!.difference(before).inSeconds,
            greaterThanOrEqualTo(7200),
          );
        } else {
          expect(failure.retryAfter, DateTime.utc(2026, 10, 2, 18));
        }
      }
    }
  });
  test('jitterBoundsAndRestartSchedule', () {
    final now = DateTime.utc(2026, 10, 2);
    final low = RetryPolicy(clock: () => now, random: () => 0);
    final high = RetryPolicy(clock: () => now, random: () => 1);
    expect(low.nextRetry(0).difference(now), const Duration(seconds: 1));
    expect(high.nextRetry(0).difference(now), const Duration(seconds: 2));
    expect(
      low.nextRetry(1000000).difference(now),
      const Duration(seconds: 150),
    );
    expect(high.nextRetry(1000000).difference(now), const Duration(minutes: 5));
    expect(high.nextRetry(-10).difference(now), const Duration(seconds: 2));
  });
  test('retryAfterExceedsFiveMinutes', () {
    final now = DateTime.utc(2026, 10, 2);
    final deadline = now.add(const Duration(hours: 2));
    final policy = RetryPolicy(clock: () => now, random: () => 0);
    expect(policy.nextRetry(9, retryAfter: deadline), deadline);
  });
  test('authIsNotMoneyRejection', () {
    expect(
      classifySyncFailure(const AppFailure('AUTH_REQUIRED', 'auth.required')),
      SyncFailureKind.authentication,
    );
    expect(
      classifySyncFailure(
        const AppFailure('BALANCE_CONFLICT', 'payment.conflict'),
      ),
      SyncFailureKind.permanent,
    );
    expect(
      classifySyncFailure(
        const AppFailure('INVALID_RESPONSE', 'api.invalidResponse'),
      ),
      SyncFailureKind.transient,
    );
    expect(
      classifySyncFailure(
        const AppFailure('CAPACITY_UNAVAILABLE', 'api.capacity'),
      ),
      SyncFailureKind.transient,
    );
    expect(
      classifySyncFailure(
        const AppFailure('HTTP_ERROR', 'api.error', httpStatus: 403),
      ),
      SyncFailureKind.permanent,
    );
    expect(
      classifySyncFailure(
        const AppFailure('UNKNOWN', 'api.error', httpStatus: 502),
      ),
      SyncFailureKind.transient,
    );
  });
}
