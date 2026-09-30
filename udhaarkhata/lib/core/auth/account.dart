import '../network/contracts.dart';

enum AccountRole { owner, customer }

final class Account {
  const Account({
    required this.id,
    required this.role,
    required this.displayName,
    required this.createdAtMs,
  });
  final OpaqueId id;
  final AccountRole role;
  final String displayName;
  final int createdAtMs;

  factory Account.fromJson(Object? value) {
    final map = jsonObject(value);
    final role = switch (map['role']) {
      'owner' => AccountRole.owner,
      'customer' => AccountRole.customer,
      _ => throw const FormatException('Invalid role'),
    };
    return Account(
      id: OpaqueId.fromJson(map['id']),
      role: role,
      displayName: jsonString(map['displayName']),
      createdAtMs: timestampMs(map['createdAtMs']),
    );
  }
}
