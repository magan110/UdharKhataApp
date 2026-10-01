const maxSafeInteger = 9007199254740991;

Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected object');
  }
  return value;
}

String jsonString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Expected nonempty string');
  }
  return value;
}

final class OpaqueId {
  const OpaqueId._(this.value);
  final String value;

  factory OpaqueId.fromJson(Object? value) {
    final text = jsonString(value);
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(text)) {
      throw const FormatException('Invalid ID');
    }
    return OpaqueId._(text);
  }
}

final class MoneyPaise {
  const MoneyPaise._(this.value);
  final int value;

  factory MoneyPaise.fromJson(Object? value) {
    if (value is! int || value.abs() > maxSafeInteger) {
      throw const FormatException('Invalid integer paise');
    }
    return MoneyPaise._(value);
  }
}

int timestampMs(Object? value) {
  if (value is! int || value < 0 || value > maxSafeInteger) {
    throw const FormatException('Invalid timestamp');
  }
  return value;
}

final class PageCursor {
  const PageCursor._(this.value);
  final String value;

  factory PageCursor.fromJson(Object? value) {
    final text = jsonString(value);
    if (text.length > 2048 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(text)) {
      throw const FormatException('Invalid cursor');
    }
    return PageCursor._(text);
  }
}

final class ApiPage {
  const ApiPage(this.nextCursor, this.hasMore);
  final PageCursor? nextCursor;
  final bool hasMore;

  factory ApiPage.fromJson(Object? value) {
    final map = jsonObject(value);
    final hasMore = map['hasMore'];
    if (hasMore is! bool) throw const FormatException('Invalid page');
    final cursor = map['nextCursor'] == null
        ? null
        : PageCursor.fromJson(map['nextCursor']);
    if (hasMore && cursor == null) {
      throw const FormatException('Missing next cursor');
    }
    return ApiPage(cursor, hasMore);
  }
}

final class ApiSuccess<T> {
  const ApiSuccess(this.data, this.requestId, this.page);
  final T data;
  final String requestId;
  final ApiPage? page;

  factory ApiSuccess.fromJson(Object? value, T Function(Object?) decode) {
    final map = jsonObject(value);
    if (!map.containsKey('data')) throw const FormatException('Missing data');
    return ApiSuccess(
      decode(map['data']),
      OpaqueId.fromJson(map['requestId']).value,
      map['page'] == null ? null : ApiPage.fromJson(map['page']),
    );
  }
}

// Authorized balance snapshot returned by reads or a rejected payment.
final class LedgerBalanceSnapshot {
  const LedgerBalanceSnapshot._(
    this.balancePaise,
    this.ledgerVersion,
    this.asOfServerSeq,
    this.asOfAtMs,
  );
  final int balancePaise, ledgerVersion, asOfServerSeq, asOfAtMs;
  factory LedgerBalanceSnapshot.fromJson(Object? value) {
    final row = jsonObject(value),
        balance = MoneyPaise.fromJson(row['balancePaise']).value;
    if (balance < 0) throw const FormatException('Invalid balance');
    return LedgerBalanceSnapshot._(
      balance,
      timestampMs(row['ledgerVersion']),
      timestampMs(row['asOfServerSeq']),
      timestampMs(row['asOfAtMs']),
    );
  }
}
