import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';

String parseOwnerQr(String payload) {
  if (payload.length > 128) throw const AppFailure('QR_INVALID', 'qr.invalid');
  final version = RegExp(r'^udhaar://customer/v([0-9]+)/').firstMatch(payload);
  if (version != null && version[1] != '1') {
    throw const AppFailure('QR_UNSUPPORTED', 'qr.unsupported');
  }
  final match = RegExp(r'^udhaar://customer/v1/([0-9a-f]{64})$')
      .firstMatch(payload);
  if (match == null || match[0] != payload) {
    throw const AppFailure('QR_INVALID', 'qr.invalid');
  }
  return match[1]!;
}

final class ResolvedCustomer {
  const ResolvedCustomer(this.publicId, this.displayName, this.linkId);
  final String publicId, displayName;
  final OpaqueId? linkId;
  factory ResolvedCustomer.fromJson(String publicId, Object? value) {
    final row = jsonObject(value), state = row['state'];
    final id = row['linkId'];
    if ((state != 'new' && state != 'linked') ||
        (state == 'new' && id != null) ||
        (state == 'linked' && id == null)) {
      throw const FormatException('Invalid resolution');
    }
    return ResolvedCustomer(
      publicId,
      jsonString(row['customerDisplayName']),
      id == null ? null : OpaqueId.fromJson(id),
    );
  }
}

final class CustomerLink {
  const CustomerLink({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.displayName,
    required this.nickname,
    required this.linkedAtMs,
    required this.balance,
    required this.version,
  });
  final OpaqueId id, shopId, customerId;
  final String displayName;
  final String? nickname;
  final int linkedAtMs, version;
  final MoneyPaise balance;
  factory CustomerLink.fromJson(Object? value) {
    final row = jsonObject(value);
    if (row['status'] != 'active') throw const FormatException('Inactive link');
    final version = timestampMs(row['ledgerVersion']);
    final balance = MoneyPaise.fromJson(row['balancePaise']);
    if (balance.value < 0) throw const FormatException('Invalid balance');
    return CustomerLink(
      id: OpaqueId.fromJson(row['id']),
      shopId: OpaqueId.fromJson(row['shopId']),
      customerId: OpaqueId.fromJson(row['customerUserId']),
      displayName: jsonString(row['customerDisplayName']),
      nickname: row['shopNickname'] == null
          ? null
          : jsonString(row['shopNickname']),
      linkedAtMs: timestampMs(row['linkedAtMs']),
      balance: balance,
      version: version,
    );
  }
}

final class CustomerLinks {
  const CustomerLinks(this.customers, this.hasMore);
  final List<CustomerLink> customers;
  final bool hasMore;
}

final class LinkAttempt {
  const LinkAttempt(
    this.operationId,
    this.publicId,
    this.displayName,
    this.nickname,
  );
  final String operationId, publicId, displayName;
  final String? nickname;
  Map<String, Object?> get body => {
    'clientOperationId': operationId,
    'publicQrId': publicId,
    'shopNickname': nickname,
  };
  factory LinkAttempt.fromJson(Object? value) {
    final row = jsonObject(value),
        operationId = jsonString(row['clientOperationId']);
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(operationId)) {
      throw const FormatException('Invalid operation ID');
    }
    final publicId = jsonString(row['publicQrId']);
    parseOwnerQr('udhaar://customer/v1/$publicId');
    final nickname = row['shopNickname'];
    if (nickname != null &&
        (nickname is! String || nickname.isEmpty || nickname.length > 120)) {
      throw const FormatException('Invalid nickname');
    }
    return LinkAttempt(
      operationId,
      publicId,
      jsonString(row['customerDisplayName']),
      nickname as String?,
    );
  }
}
