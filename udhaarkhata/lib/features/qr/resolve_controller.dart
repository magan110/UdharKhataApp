import 'package:flutter/foundation.dart';

import '../../core/network/contracts.dart';
import '../../core/network/app_failure.dart';
import 'owner_qr_model.dart';
import 'owner_link_repository.dart';

enum ScanStage {
  loading,
  ready,
  resolving,
  confirm,
  saving,
  recovery,
  linked,
  failed,
}

class ResolveController extends ChangeNotifier {
  ResolveController(this.repository, this.shopId);
  final OwnerLinkRepository repository;
  final OpaqueId shopId;
  ScanStage stage = ScanStage.loading;
  ResolvedCustomer? customer;
  LinkAttempt? attempt;
  CustomerLink? link;
  Object? error;
  String? _payload;
  bool _disposed = false;
  void _set(ScanStage value) {
    if (_disposed) return;
    stage = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      attempt = await repository.pending(shopId);
      _set(attempt == null ? ScanStage.ready : ScanStage.recovery);
    } catch (e) {
      error = e;
      _set(ScanStage.failed);
    }
  }

  Future<void> scan(String payload) async {
    if (stage != ScanStage.ready || _disposed) return;
    _payload = payload;
    error = null;
    _set(ScanStage.resolving);
    try {
      final resolved = await repository.resolve(shopId, parseOwnerQr(payload));
      if (_disposed) return;
      customer = resolved;
      if (resolved.linkId != null) {
        link = await repository.customer(shopId, resolved.linkId!);
        _set(ScanStage.linked);
      } else {
        _set(ScanStage.confirm);
      }
    } catch (e) {
      error = e is AppFailure && e.code == 'NETWORK_ERROR'
          ? const AppFailure(
              'NETWORK_ERROR',
              'link.internetNeeded',
              retryable: true,
            )
          : e;
      _set(ScanStage.failed);
    }
  }

  Future<void> confirm(String? nickname) async {
    if (_disposed ||
        (stage != ScanStage.confirm && stage != ScanStage.recovery)) {
      return;
    }
    error = null;
    _set(ScanStage.saving);
    try {
      attempt ??= await repository.begin(shopId, customer!, nickname);
      if (_disposed) return;
      link = await repository.submit(shopId, attempt!);
      if (_disposed) return;
      attempt = null;
      _set(ScanStage.linked);
    } catch (e) {
      if (_disposed) return;
      error = e;
      try {
        attempt = await repository.pending(shopId);
      } catch (_) {
        // Storage uncertainty must not permit a new command under a new ID.
        _set(ScanStage.failed);
        return;
      }
      _set(attempt == null ? ScanStage.failed : ScanStage.recovery);
    }
  }

  void rescan() {
    if (_disposed ||
        attempt != null ||
        stage == ScanStage.saving ||
        stage == ScanStage.resolving) {
      return;
    }
    customer = null;
    link = null;
    error = null;
    _payload = null;
    _set(ScanStage.ready);
  }

  Future<void> retry() async {
    if (stage != ScanStage.failed) return;
    if (error is AppFailure && (error as AppFailure).code == 'AUTH_REQUIRED') {
      return;
    }
    final payload = _payload;
    if (payload == null) {
      _set(ScanStage.loading);
      await initialize();
    } else {
      _set(ScanStage.ready);
      await scan(payload);
    }
  }
}
