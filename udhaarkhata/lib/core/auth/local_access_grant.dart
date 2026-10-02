import 'account.dart';
import '../network/contracts.dart';

final class LocalAccessGrant {
  const LocalAccessGrant(this.account, this.verifiedAtMs, this.expiresAtMs);
  final Account account;
  final int verifiedAtMs, expiresAtMs;
  factory LocalAccessGrant.fromJson(Object? value) {
    final map = jsonObject(value);
    final grant = LocalAccessGrant(
      Account.fromJson(map['account']),
      timestampMs(map['verifiedAtMs']),
      timestampMs(map['expiresAtMs']),
    );
    if (grant.expiresAtMs - grant.verifiedAtMs !=
        const Duration(days: 30).inMilliseconds) {
      throw const FormatException('Invalid local access lifetime');
    }
    return grant;
  }
  bool validAt(DateTime now) =>
      now.millisecondsSinceEpoch >= verifiedAtMs &&
      now.millisecondsSinceEpoch < expiresAtMs;
  Map<String, Object?> get json => {
    'account': {
      'id': account.id.value,
      'role': account.role.name,
      'displayName': account.displayName,
      'createdAtMs': account.createdAtMs,
    },
    'verifiedAtMs': verifiedAtMs,
    'expiresAtMs': expiresAtMs,
  };
}
