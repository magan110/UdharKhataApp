import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import 'qr_model.dart';

abstract interface class QrRepository {
  Future<QrRecord?> cached();
  Future<QrRecord> current();
  Future<QrRecord> rotate();
}

final qrRepositoryProvider = Provider<QrRepository?>((ref) {
  final account = ref.watch(sessionProvider).value;
  final auth = ref.watch(authRepositoryProvider);
  return account == null || auth is! GoogleAuthRepository
      ? null
      : CloudQrRepository(auth, account.id, auth.store.storage);
});

final class CloudQrRepository implements QrRepository {
  CloudQrRepository(this.auth, this.accountId, this.storage);
  final AuthRepository auth;
  final OpaqueId accountId;
  final FlutterSecureStorage storage;
  String get _key => 'customer_qr_${accountId.value}';
  @override
  Future<QrRecord?> cached() async {
    final value = await storage.read(key: _key);
    if (value == null) return null;
    try {
      final row = jsonObject(jsonDecode(value));
      if (row['rotationPending'] == true) {
        throw const AppFailure(
          'QR_RECOVERY_REQUIRED',
          'qr.recoveryRequired',
          retryable: true,
        );
      }
      return QrRecord(
        CustomerQr.fromJson(row),
        timestampMs(row['checkedAtMs']),
      );
    } on FormatException {
      await storage.delete(key: _key);
      return null;
    }
  }

  Future<QrRecord> _save(Object? value) async {
    final record = QrRecord(
      CustomerQr.fromJson(value),
      DateTime.now().millisecondsSinceEpoch,
    );
    await storage.write(
      key: _key,
      value: jsonEncode({
        ...record.qr.toJson(),
        'checkedAtMs': record.checkedAtMs,
      }),
    );
    return record;
  }

  @override
  Future<QrRecord> current() async =>
      _save(await auth.cloudRequest(accountId, '/v1/me/qr'));
  @override
  Future<QrRecord> rotate() async {
    try {
      await cached();
    } on AppFailure catch (error) {
      if (error.code == 'QR_RECOVERY_REQUIRED') return current();
      rethrow;
    }
    // Persist before sending: a restart after an uncertain response must not show a revoked QR.
    await storage.write(
      key: _key,
      value: jsonEncode({'rotationPending': true}),
    );
    try {
      return await _save(
        await auth.cloudRequest(accountId, '/v1/me/qr/rotate', body: {}),
      );
    } on AppFailure catch (error) {
      if (error.code == 'AUTH_REQUIRED') rethrow;
      try {
        final recovered = await current();
        return QrRecord(
          recovered.qr,
          recovered.checkedAtMs,
          noticeKey: error.code == 'NETWORK_ERROR'
              ? 'qr.rotationRecovered'
              : error.messageKey,
        );
      } on AppFailure catch (recoveryError) {
        if (recoveryError.code == 'AUTH_REQUIRED') rethrow;
        throw const AppFailure(
          'QR_RECOVERY_REQUIRED',
          'qr.recoveryRequired',
          retryable: true,
        );
      }
    }
  }
}

final qrProvider = AsyncNotifierProvider<QrController, QrView>(
  QrController.new,
  retry: (_, _) => null,
);

class QrController extends AsyncNotifier<QrView> {
  @override
  Future<QrView> build() async {
    final repo = ref.watch(qrRepositoryProvider);
    if (repo == null) {
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
    }
    final cached = await repo.cached();
    return cached == null
        ? QrView(await repo.current(), cached: false)
        : QrView(cached, cached: true);
  }

  Future<void> refresh({bool rotate = false}) async {
    if (state.isLoading) return;
    final repo = ref.read(qrRepositoryProvider);
    if (repo == null) return;
    state = const AsyncLoading();
    var result = await AsyncValue.guard(
      () async => QrView(
        rotate ? await repo.rotate() : await repo.current(),
        cached: false,
      ),
    );
    if (result.error case final AppFailure error
        when error.code == 'NETWORK_ERROR' || error.code == 'AUTH_REQUIRED') {
      try {
        final cached = await repo.cached();
        if (cached != null) {
          result = AsyncData(
            QrView(
              cached,
              cached: true,
              needsSignIn: error.code == 'AUTH_REQUIRED',
            ),
          );
        }
      } on AppFailure {
        /* Uncertain rotation cache remains hidden until online recovery. */
      } catch (cacheError, stack) {
        result = AsyncError(cacheError, stack);
      }
    }
    if (ref.mounted && identical(repo, ref.read(qrRepositoryProvider))) {
      state = result;
    }
  }
}
