import 'contracts.dart';

final class AppFailure implements Exception {
  const AppFailure(
    this.code,
    this.messageKey, {
    this.retryable = false,
    this.requestId,
    this.balance,
    this.httpStatus,
    this.retryAfter,
  });
  final int? httpStatus;
  final DateTime? retryAfter;
  final String code;
  final String messageKey;
  final bool retryable;
  final String? requestId;
  final LedgerBalanceSnapshot? balance;

  factory AppFailure.fromJson(
    Object? value, {
    int? httpStatus,
    DateTime? retryAfter,
  }) {
    final map = jsonObject(value);
    final error = jsonObject(map['error']);
    final retryable = error['retryable'];
    if (retryable is! bool) throw const FormatException('Invalid error');
    final code = jsonString(error['code']);
    final balance = code == 'BALANCE_CONFLICT' && error['details'] != null
        ? LedgerBalanceSnapshot.fromJson(
            jsonObject(error['details'])['balance'],
          )
        : null;
    return AppFailure(
      code,
      jsonString(error['messageKey']),
      retryable: retryable,
      requestId: OpaqueId.fromJson(map['requestId']).value,
      balance: balance,
      httpStatus: httpStatus,
      retryAfter: retryAfter,
    );
  }

  // Never include response bodies, credentials, notes or amounts in diagnostics.
  @override
  String toString() => 'AppFailure($code)';
}
