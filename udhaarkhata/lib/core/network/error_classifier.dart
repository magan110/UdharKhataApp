import 'app_failure.dart';

enum SyncFailureKind { transient, authentication, permanent }

SyncFailureKind classifySyncFailure(AppFailure failure) {
  if (failure.httpStatus == 401 ||
      ['AUTH_REQUIRED', 'IDENTITY_INVALID'].contains(failure.code)) {
    return SyncFailureKind.authentication;
  }
  if (failure.httpStatus == 429 ||
      (failure.httpStatus ?? 0) >= 500 ||
      [
        'NETWORK_ERROR',
        'INVALID_RESPONSE',
        'RATE_LIMITED',
        'CAPACITY_UNAVAILABLE',
        'SERVER_ERROR',
      ].contains(failure.code)) {
    return SyncFailureKind.transient;
  }
  return failure.retryable
      ? SyncFailureKind.transient
      : SyncFailureKind.permanent;
}
