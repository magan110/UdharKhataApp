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

abstract interface class PaymentRepository {
  Future<PendingPayment?> pendingPayment(OpaqueId shopId, OpaqueId linkId);
  Future<PaymentAttempt> beginPayment(
    OpaqueId shopId,
    OpaqueId linkId,
    String displayName,
    int amountPaise,
    String paymentMethod,
  );
  Future<CreditReceipt> submitPayment(OpaqueId shopId, PaymentAttempt attempt);
  Future<void> reviewRejectedPayment(OpaqueId shopId, OpaqueId linkId);
}

final paymentRepositoryProvider = Provider<PaymentRepository?>((ref) {
  final repo = ref.watch(ledgerRepositoryProvider);
  return repo is PaymentRepository ? repo as PaymentRepository : null;
});

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

class CloudLedgerRepository implements LedgerRepository, PaymentRepository {
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

  String _paymentKey(OpaqueId shopId, OpaqueId linkId) =>
      _key(shopId, linkId).replaceFirst('credit_', 'payment_');
  @override
  Future<PendingPayment?> pendingPayment(
    OpaqueId shopId,
    OpaqueId linkId,
  ) async {
    final text = await storage.read(key: _paymentKey(shopId, linkId));
    if (text == null) return null;
    try {
      final row = jsonObject(jsonDecode(text)),
          attempt = PaymentAttempt.fromJson(row['attempt']);
      if (row['rejected'] is! bool || attempt.linkId.value != linkId.value) {
        throw const FormatException('Invalid saved payment');
      }
      return PendingPayment(attempt, row['rejected'] as bool);
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'payment.savedInvalid');
    }
  }

  Future<void> _savePayment(
    OpaqueId shopId,
    PaymentAttempt attempt,
    bool rejected,
  ) => storage.write(
    key: _paymentKey(shopId, attempt.linkId),
    value: jsonEncode({
      'attempt': {...attempt.body, 'customerDisplayName': attempt.displayName},
      'rejected': rejected,
    }),
  );
  @override
  Future<PaymentAttempt> beginPayment(
    OpaqueId shopId,
    OpaqueId linkId,
    String displayName,
    int amountPaise,
    String paymentMethod,
  ) => _serial(() async {
    if (await pending(shopId, linkId) != null) {
      throw const AppFailure('CREDIT_PENDING', 'payment.creditPending');
    }
    if (await pendingPayment(shopId, linkId) != null) {
      throw const AppFailure('PAYMENT_PENDING', 'payment.pending');
    }
    if (amountPaise < 1 ||
        amountPaise > maxCreditPaise ||
        !['cash', 'upi'].contains(paymentMethod)) {
      throw const AppFailure('VALIDATION_ERROR', 'payment.invalid');
    }
    final attempt = PaymentAttempt(
      _uuid(),
      linkId,
      displayName,
      amountPaise,
      paymentMethod,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _savePayment(shopId, attempt, false);
    return attempt;
  });
  @override
  Future<CreditReceipt> submitPayment(
    OpaqueId shopId,
    PaymentAttempt attempt,
  ) => _serial(() async {
    final saved = await pendingPayment(shopId, attempt.linkId);
    if (saved == null ||
        saved.rejected ||
        jsonEncode(saved.attempt.body) != jsonEncode(attempt.body)) {
      throw const AppFailure('PAYMENT_PENDING', 'payment.pending');
    }
    CreditReceipt receipt;
    try {
      receipt = CreditReceipt.payment(
        await auth.cloudRequest(
          accountId,
          '/v1/shops/${shopId.value}/entries',
          body: saved.attempt.body,
        ),
        shopId,
        saved.attempt,
      );
    } on AppFailure catch (error) {
      // Only an explicit atomic balance rejection unlocks the correction path.
      // Network/auth/5xx/invalid receipts retain an uncertain immutable command.
      if (error.code == 'BALANCE_CONFLICT') {
        await _savePayment(shopId, saved.attempt, true);
      }
      rethrow;
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
    await storage.delete(key: _paymentKey(shopId, attempt.linkId));
    return receipt;
  });
  @override
  Future<void> reviewRejectedPayment(
    OpaqueId shopId,
    OpaqueId linkId,
  ) => _serial(() async {
    final saved = await pendingPayment(shopId, linkId);
    if (saved == null || !saved.rejected) {
      throw const AppFailure('PAYMENT_PENDING', 'payment.pending');
    }
    // Retain the rejected original before opening a new draft. Failures keep it blocked.
    await storage.write(
      key:
          '${_paymentKey(shopId, linkId)}_rejected_${saved.attempt.operationId}',
      value: jsonEncode({
        'attempt': {
          ...saved.attempt.body,
          'customerDisplayName': saved.attempt.displayName,
        },
        'rejected': true,
      }),
    );
    await storage.delete(key: _paymentKey(shopId, linkId));
  });

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
    if (await pendingPayment(shopId, linkId) != null) {
      throw const AppFailure('PAYMENT_PENDING', 'payment.pending');
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
