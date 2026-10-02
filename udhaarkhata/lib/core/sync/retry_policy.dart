import 'dart:math';

final class RetryPolicy {
  const RetryPolicy({required this.clock, required this.random});
  final DateTime Function() clock;
  final double Function() random;

  DateTime nextRetry(int attempts, {DateTime? retryAfter}) {
    final seconds = min(300, 2 * (1 << attempts.clamp(0, 8)));
    final jitter = random().clamp(0.0, 1.0);
    final next = clock().add(
      Duration(milliseconds: (seconds * 1000 * (0.5 + jitter * 0.5)).round()),
    );
    return retryAfter != null && retryAfter.isAfter(next) ? retryAfter : next;
  }
}
