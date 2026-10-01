import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/account.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import 'entry_model.dart';
import 'money.dart';

abstract interface class LedgerRepository {
  Future<CreditAttempt?> pending(OpaqueId shopId, OpaqueId linkId);
  Future<CreditAttempt> begin(
    OpaqueId shopId,
    OpaqueId linkId,
    String displayName,
    int amountPaise,
    String? note,
    String? dueDate,
  );
  Future<CreditReceipt> submit(OpaqueId shopId, CreditAttempt attempt);
}

final ledgerRepositoryProvider = Provider<LedgerRepository?>((ref) {
  final account = ref.watch(sessionProvider).value;
  return account == null || account.role != AccountRole.owner
      ? null
      : CloudLedgerRepository(
          ref.watch(authRepositoryProvider),
          account.id,
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          ),
        );
});

class CloudLedgerRepository implements LedgerRepository {
  CloudLedgerRepository(this.auth, this.accountId, this.storage);
  final AuthRepository auth;
  final OpaqueId accountId;
  final FlutterSecureStorage storage;
  Future<void> _queue = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _key(OpaqueId shopId, OpaqueId linkId) =>
      'credit_${sha256.convert(utf8.encode(jsonEncode([accountId.value, shopId.value, linkId.value])))}';
  @override
  Future<CreditAttempt?> pending(OpaqueId shopId, OpaqueId linkId) async {
    final text = await storage.read(key: _key(shopId, linkId));
    if (text == null) return null;
    try {
      final attempt = CreditAttempt.fromJson(jsonDecode(text));
      if (attempt.linkId.value != linkId.value) {
        throw const FormatException('Wrong link');
      }
      return attempt;
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'credit.savedInvalid');
    }
  }

  String _uuid() {
    final random = Random.secure(),
        bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  @override
  Future<CreditAttempt> begin(
    OpaqueId shopId,
    OpaqueId linkId,
    String displayName,
    int amountPaise,
    String? note,
    String? dueDate,
  ) => _serial(() async {
    if (await pending(shopId, linkId) != null) {
      throw const AppFailure('CREDIT_PENDING', 'credit.pending');
    }
    final normalized = note?.trim();
    if (amountPaise < 1 ||
        amountPaise > maxCreditPaise ||
        (normalized?.length ?? 0) > maxCreditNoteCharacters ||
        !validDueDate(dueDate)) {
      throw const AppFailure('VALIDATION_ERROR', 'credit.invalid');
    }
    final attempt = CreditAttempt(
      _uuid(),
      linkId,
      displayName,
      amountPaise,
      normalized == null || normalized.isEmpty ? null : normalized,
      dueDate,
      DateTime.now().millisecondsSinceEpoch,
    );
    await storage.write(
      key: _key(shopId, linkId),
      value: jsonEncode({...attempt.body, 'customerDisplayName': displayName}),
    );
    return attempt;
  });
  @override
  Future<CreditReceipt> submit(OpaqueId shopId, CreditAttempt attempt) =>
      _serial(() async {
        final saved = await pending(shopId, attempt.linkId);
        if (saved == null ||
            jsonEncode(saved.body) != jsonEncode(attempt.body)) {
          throw const AppFailure('CREDIT_PENDING', 'credit.pending');
        }
        CreditReceipt receipt;
        try {
          receipt = CreditReceipt.fromJson(
            await auth.cloudRequest(
              accountId,
              '/v1/shops/${shopId.value}/entries',
              body: saved.body,
            ),
            shopId,
            saved,
          );
        } on FormatException {
          throw const AppFailure(
            'INVALID_RESPONSE',
            'api.invalidResponse',
            retryable: true,
          );
        }
        // A failed response/verification/deletion retains the identical command, never a new ID.
        await storage.delete(key: _key(shopId, attempt.linkId));
        return receipt;
      });
}
