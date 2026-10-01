import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/network/contracts.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import 'owner_qr_model.dart';

abstract interface class OwnerLinkRepository {
  Future<ResolvedCustomer> resolve(OpaqueId shopId, String publicId);
  Future<CustomerLinks> customers(OpaqueId shopId);
  Future<CustomerLink> customer(OpaqueId shopId, OpaqueId linkId);
  Future<LinkAttempt?> pending(OpaqueId shopId);
  Future<LinkAttempt> begin(
    OpaqueId shopId,
    ResolvedCustomer customer,
    String? nickname,
  );
  Future<CustomerLink> submit(OpaqueId shopId, LinkAttempt attempt);
}

final ownerLinkRepositoryProvider = Provider<OwnerLinkRepository?>((ref) {
  final account = ref.watch(sessionProvider).value;
  return account == null
      ? null
      : CloudOwnerLinkRepository(
          ref.watch(authRepositoryProvider),
          account.id,
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          ),
        );
});
final customerLinksProvider = FutureProvider.autoDispose
    .family<CustomerLinks, String>((ref, shopId) {
      final repo = ref.watch(ownerLinkRepositoryProvider);
      if (repo == null) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      return repo.customers(OpaqueId.fromJson(shopId));
    }, retry: (_, _) => null);

class CloudOwnerLinkRepository implements OwnerLinkRepository {
  CloudOwnerLinkRepository(this.auth, this.accountId, this.storage);
  final AuthRepository auth;
  final OpaqueId accountId;
  final FlutterSecureStorage storage;
  Future<void> _queue = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _key(OpaqueId shopId) =>
      'owner_link_${sha256.convert(utf8.encode(jsonEncode([accountId.value, shopId.value])))}';
  Future<T> _decode<T>(
    Future<Object?> value,
    T Function(Object?) decode,
  ) async {
    try {
      return decode(await value);
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
  }

  CustomerLink _link(OpaqueId shopId, Object? value) {
    final link = CustomerLink.fromJson(value);
    if (link.shopId.value != shopId.value) {
      throw const FormatException('Wrong link scope');
    }
    return link;
  }

  @override
  Future<ResolvedCustomer> resolve(OpaqueId shopId, String publicId) {
    parseOwnerQr('udhaar://customer/v1/$publicId');
    return _decode(
      auth.cloudRequest(
        accountId,
        '/v1/customer-qr/resolve',
        body: {'shopId': shopId.value, 'publicQrId': publicId},
      ),
      (value) => ResolvedCustomer.fromJson(publicId, value),
    );
  }

  @override
  Future<CustomerLinks> customers(OpaqueId shopId) => _decode(
    auth.cloudRequest(accountId, '/v1/shops/${shopId.value}/customers'),
    (value) {
      final row = jsonObject(value),
          rows = row['customers'],
          hasMore = row['hasMore'];
      if (rows is! List || rows.length > 100 || hasMore is! bool) {
        throw const FormatException('Invalid customer list');
      }
      return CustomerLinks(
        rows.map((r) => _link(shopId, r)).toList(growable: false),
        hasMore,
      );
    },
  );
  @override
  Future<CustomerLink> customer(OpaqueId shopId, OpaqueId linkId) => _decode(
    auth.cloudRequest(
      accountId,
      '/v1/shops/${shopId.value}/customers/${linkId.value}',
    ),
    (value) {
      final link = _link(shopId, value);
      if (link.id.value != linkId.value) {
        throw const FormatException('Wrong link');
      }
      return link;
    },
  );
  @override
  Future<LinkAttempt?> pending(OpaqueId shopId) async {
    final text = await storage.read(key: _key(shopId));
    if (text == null) return null;
    try {
      return LinkAttempt.fromJson(jsonDecode(text));
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'link.savedRequestInvalid');
    }
  }

  String _uuid() {
    final random = Random.secure(),
        bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Future<LinkAttempt> begin(
    OpaqueId shopId,
    ResolvedCustomer customer,
    String? nickname,
  ) => _serial(() async {
    if (await pending(shopId) != null) {
      throw const AppFailure('LINK_PENDING', 'link.pending');
    }
    if (customer.linkId != null) {
      throw const AppFailure('VALIDATION_ERROR', 'qr.invalid');
    }
    parseOwnerQr('udhaar://customer/v1/${customer.publicId}');
    final normalized = nickname?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if ((normalized?.length ?? 0) > 120) {
      throw const AppFailure('VALIDATION_ERROR', 'link.nicknameInvalid');
    }
    final attempt = LinkAttempt(
      _uuid(),
      customer.publicId,
      customer.displayName,
      normalized == null || normalized.isEmpty ? null : normalized,
    );
    // Durable before POST. A response loss/restart must preserve the original command.
    await storage.write(
      key: _key(shopId),
      value: jsonEncode({
        ...attempt.body,
        'customerDisplayName': attempt.displayName,
      }),
    );
    return attempt;
  });
  @override
  Future<CustomerLink> submit(OpaqueId shopId, LinkAttempt attempt) =>
      _serial(() async {
        final saved = await pending(shopId);
        if (saved == null || jsonEncode(saved.body) != jsonEncode(attempt.body)) {
          throw const AppFailure('LINK_PENDING', 'link.pending');
        }
        try {
          final link = await _decode(
            auth.cloudRequest(
              accountId,
              '/v1/shops/${shopId.value}/customers',
              body: saved.body,
            ),
            (value) => _link(shopId, value),
          );
          await storage.delete(key: _key(shopId));
          return link;
        } on AppFailure catch (error) {
          if ({
            'QR_INVALID',
            'QR_REVOKED',
            'NOT_FOUND',
            'IDEMPOTENCY_CONFLICT',
            'VALIDATION_ERROR',
          }.contains(error.code)) {
            await storage.delete(key: _key(shopId));
          }
          rethrow;
        }
      });
}
