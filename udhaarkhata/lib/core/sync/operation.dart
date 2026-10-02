import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String newOperationId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final class LocalOperation {
  LocalOperation(String accountId, String shopId, Map<String, Object?> body) {
    final keys = body.keys.toList()..sort();
    payload = jsonEncode({for (final key in keys) key: body[key]});
    if (utf8.encode(payload).length > 4096) {
      throw const FormatException('Financial command too large');
    }
    // Local integrity hash, deliberately separate from the server receipt hash.
    hash = sha256
        .convert(utf8.encode(jsonEncode([accountId, shopId, payload])))
        .toString();
  }
  late final String payload, hash;
}
