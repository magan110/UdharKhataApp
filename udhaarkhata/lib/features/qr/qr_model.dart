import '../../core/network/contracts.dart';

final class CustomerQr {
  CustomerQr._(this.publicId);
  final String publicId;
  String get payload => 'udhaar://customer/v1/$publicId';
  factory CustomerQr.fromJson(Object? value) {
    final row = jsonObject(value), id = jsonString(row['publicQrId']);
    if (row['version'] != 1 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(id) ||
        row['payload'] != 'udhaar://customer/v1/$id') {
      throw const FormatException('Invalid customer QR');
    }
    return CustomerQr._(id);
  }
  Map<String, Object?> toJson() => {
    'version': 1,
    'publicQrId': publicId,
    'payload': payload,
  };
}

final class QrRecord {
  const QrRecord(this.qr, this.checkedAtMs, {this.noticeKey});
  final CustomerQr qr;
  final int checkedAtMs;
  final String? noticeKey;
}

final class QrView {
  const QrView(this.record, {required this.cached, this.needsSignIn = false});
  final QrRecord record;
  final bool cached;
  final bool needsSignIn;
}
