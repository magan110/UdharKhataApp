import 'contracts.dart';

final class AppFailure implements Exception {
  const AppFailure(
    this.code,
    this.messageKey, {
    this.retryable = false,
    this.requestId,
  });
  final String code;
  final String messageKey;
  final bool retryable;
  final String? requestId;

  factory AppFailure.fromJson(Object? value) {
    final map = jsonObject(value);
    final error = jsonObject(map['error']);
    final retryable = error['retryable'];
    if (retryable is! bool) throw const FormatException('Invalid error');
    return AppFailure(
      jsonString(error['code']),
      jsonString(error['messageKey']),
      retryable: retryable,
      requestId: OpaqueId.fromJson(map['requestId']).value,
    );
  }

  // Never include response bodies, credentials, notes or amounts in diagnostics.
  @override
  String toString() => 'AppFailure($code)';
}
