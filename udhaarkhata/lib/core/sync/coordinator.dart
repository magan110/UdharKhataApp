import 'dart:async';

import '../auth/auth_repository.dart';
import '../db/database.dart';
import '../db/outbox_dao.dart';
import '../db/sync_dao.dart';
import '../network/app_failure.dart';
import '../network/contracts.dart';
import '../network/error_classifier.dart';
import 'push.dart';
import 'pull.dart';
import 'retry_policy.dart';
import 'sync_coordinator.dart';

typedef SyncSchedule = void Function() Function(
  Duration delay,
  void Function() action,
);

final class SyncRunState {
  const SyncRunState({
    this.running = false,
    this.lastSuccessfulAtMs,
    this.pendingCount = 0,
    this.needsAttentionCount = 0,
    this.blockedLinkIds = const {},
    this.errorCode,
  });
  final bool running;
  final int? lastSuccessfulAtMs;
  final int pendingCount, needsAttentionCount;
  final Set<String> blockedLinkIds;
  final String? errorCode;
}

final class DeviceSyncCoordinator implements SyncCoordinator {
  DeviceSyncCoordinator({
    required this.auth,
    required this.database,
    required this.accountId,
    required this.shopId,
    required this.push,
    required this.pull,
    required this.retryPolicy,
    required this.legacyBlocked,
    DateTime Function()? clock,
    SyncSchedule? schedule,
  }) : clock = clock ?? DateTime.now,
       schedule = schedule ?? _timer;
  final AuthRepository auth;
  final SqliteAccountDatabase database;
  final OpaqueId accountId;
  final String shopId;
  final SyncPush push;
  final SyncPull pull;
  final RetryPolicy retryPolicy;
  final Future<bool> Function(String, String) legacyBlocked;
  final DateTime Function() clock;
  final SyncSchedule schedule;
  final _states = StreamController<SyncRunState>.broadcast();
  SyncRunState _state = const SyncRunState();
  SyncRunState get state => _state;
  Stream<SyncRunState> get states => _states.stream;
  Future<void>? _active;
  bool _disposed = false, _stop = false;
  void Function()? _cancel;
  int _offset = 0, _pages = 0;
  final _remaining = <String>{}, _blocked = <String>{};
  String? _error;
  DateTime? _wake;
  int? _lastSuccess;
  SyncDao get _dao => push.dao;
  String get _runScope => 'shop:$shopId';
  static void Function() _timer(Duration delay, void Function() action) {
    final timer = Timer(delay, action);
    return timer.cancel;
  }

  void _guard() {
    if (_disposed ||
        database.generation != _dao.generation ||
        auth.sessionGeneration != _dao.generation) {
      throw StateError('Sync session replaced');
    }
  }

  void _later(DateTime deadline) {
    if (_wake == null || deadline.isBefore(_wake!)) _wake = deadline;
  }

  Future<void> _snapshot(bool running) async {
    _guard();
    final rows = await database.transaction(
      accountId,
      (tx) => tx.rawQuery(
        'SELECT o.state,o.link_id,o.retry_at_ms FROM outbox o JOIN cached_links l ON l.id=o.link_id WHERE l.shop_id=?',
        [shopId],
      ),
      expectedGeneration: _dao.generation,
    );
    _guard();
    final attention = rows.where((r) => r['state'] == 'needs_attention').length;
    for (final row in rows) {
      if (row['state'] == 'needs_attention') {
        _blocked.add(row['link_id'] as String);
      }
      final retry = row['retry_at_ms'] as int?;
      if (retry != null && retry > clock().millisecondsSinceEpoch) {
        _later(DateTime.fromMillisecondsSinceEpoch(retry));
      }
    }
    _state = SyncRunState(
      running: running,
      lastSuccessfulAtMs: _lastSuccess,
      pendingCount: rows.length - attention,
      needsAttentionCount: attention,
      blockedLinkIds: Set.unmodifiable(_blocked),
      errorCode: _error,
    );
    _states.add(_state);
  }

  bool _global(AppFailure failure) =>
      [
        'NETWORK_ERROR',
        'RATE_LIMITED',
        'CAPACITY_UNAVAILABLE',
        'SERVER_ERROR',
      ].contains(failure.code) ||
      failure.httpStatus == 429 ||
      (failure.httpStatus ?? 0) >= 500;
  Future<void> _failure(
    AppFailure failure, {
    String? link,
    Map<String, Object?>? command,
  }) async {
    _guard();
    _error = failure.code;
    final kind = classifySyncFailure(failure);
    if (kind == SyncFailureKind.authentication) {
      _stop = true;
      _wake = null;
      return;
    }
    if (kind == SyncFailureKind.permanent) {
      if (link != null) {
        _blocked.add(link);
        if (['FORBIDDEN', 'NOT_FOUND'].contains(failure.code)) {
          await _dao.denyLink(shopId, link, failure.code);
          _remaining.remove(link);
        } else if (command != null) {
          await _dao.reject(command['operation_id'] as String, failure.code);
        } else {
          _remaining.remove(link);
        }
      }
      return;
    }
    final scope = _global(failure) ? _runScope : 'link:$link';
    final saved = await _dao.retry(scope);
    final attempts = (saved?['attempts'] as int? ?? 0);
    final deadline = retryPolicy.nextRetry(
      attempts,
      retryAfter: failure.retryAfter,
    );
    await _dao.retryScope(scope, attempts + 1, deadline, failure.code);
    _later(deadline);
    if (link != null) _blocked.add(link);
    if (command != null) {
      await _dao.defer(
        command['operation_id'] as String,
        (command['attempts'] as int) + 1,
        deadline,
        failure.code,
      );
    }
    if (_global(failure)) _stop = true;
  }

  Future<void> _syncLink(String link) async {
    final saved = await _dao.retry('link:$link');
    if (saved != null &&
        (saved['retry_at_ms'] as int) > clock().millisecondsSinceEpoch) {
      _later(DateTime.fromMillisecondsSinceEpoch(saved['retry_at_ms'] as int));
      _blocked.add(link);
      return;
    }
    String? cursor;
    var reset = false;
    while (_pages < 20 && !_stop) {
      _guard();
      _pages++;
      try {
        final page = await pull.page(shopId, link, cursor: cursor);
        _guard();
        await _dao.clearRetry('link:$link');
        cursor = page.nextCursor;
        if (cursor == null) {
          _remaining.remove(link);
          return;
        }
      } on AppFailure catch (failure) {
        if (failure.code == 'CURSOR_INVALID' && cursor != null && !reset) {
          cursor = null;
          reset = true;
          continue;
        }
        await _failure(failure, link: link);
        return;
      }
    }
  }

  @override
  Future<void> synchronize() {
    if (_disposed) return Future.value();
    if (_active != null) return _active!;
    _cancel?.call();
    _cancel = null;
    final future = _run();
    _active = future;
    return future.whenComplete(() => _active = null);
  }

  Future<void> _run() async {
    _stop = false;
    _error = null;
    _wake = null;
    _blocked.clear();
    _pages = 0;
    try {
      _guard();
      await _snapshot(true);
      final retry = await _dao.retry(_runScope);
      if (retry != null &&
          (retry['retry_at_ms'] as int) > clock().millisecondsSinceEpoch) {
        _error = retry['error_code'] as String;
        _later(
          DateTime.fromMillisecondsSinceEpoch(retry['retry_at_ms'] as int),
        );
        return;
      }
      final links = await database.transaction(
        accountId,
        (tx) => tx.rawQuery(
          "SELECT l.id FROM cached_links l JOIN owner_ledger_snapshots s ON s.link_id=l.id WHERE l.shop_id=? AND l.owner_user_id=? AND l.status='active' ORDER BY l.id",
          [shopId, accountId.value],
        ),
        expectedGeneration: _dao.generation,
      );
      _guard();
      final ids = links.map((r) => r['id'] as String).toList();
      _remaining.removeWhere((id) => !ids.contains(id));
      if (_remaining.isEmpty) _remaining.addAll(ids);
      if (ids.isNotEmpty) {
        final offset = _offset % ids.length;
        for (var i = 0; i < ids.length && _pages < 20 && !_stop; i++) {
          final at = (offset + i) % ids.length, link = ids[at];
          if (!_remaining.contains(link)) continue;
          await _syncLink(link);
          _offset = (at + 1) % ids.length;
        }
      }
      if (_stop) return;
      final ready = await OutboxDao(
        database,
        accountId,
      ).ready(clock(), shopId: shopId);
      var attempted = 0;
      final dirty = <String>{};
      for (final row in ready) {
        if (attempted >= 20 || _stop) break;
        _guard();
        final link = row['link_id'] as String;
        if (_blocked.contains(link)) continue;
        if (await legacyBlocked(shopId, link)) {
          _blocked.add(link);
          _error = 'LEGACY_RECOVERY_REQUIRED';
          continue;
        }
        _guard();
        attempted++;
        try {
          await push.send(shopId, row);
          _guard();
          dirty.add(link);
          _remaining.add(link);
        } on AppFailure catch (failure) {
          await _failure(failure, link: link, command: row);
          if (classifySyncFailure(failure) == SyncFailureKind.permanent &&
              !['FORBIDDEN', 'NOT_FOUND'].contains(failure.code)) {
            dirty.add(link);
            _remaining.add(link);
          }
        }
      }
      for (final link in dirty) {
        if (_pages >= 20 || _stop) break;
        await _syncLink(link);
      }
      if (!_stop && _remaining.isEmpty && _error == null) {
        _lastSuccess = clock().millisecondsSinceEpoch;
        await _dao.clearRetry(_runScope);
      }
      if (!_stop &&
          (attempted >= 20 || (_pages >= 20 && _remaining.isNotEmpty))) {
        _later(clock().add(const Duration(seconds: 2)));
      }
    } on StateError {
      _stop = true;
      _wake = null;
    } on AppFailure catch (failure) {
      await _failure(failure);
    } finally {
      if (!_disposed &&
          database.generation == _dao.generation &&
          auth.sessionGeneration == _dao.generation) {
        try {
          await _snapshot(false);
        } on StateError {
          _wake = null;
        }
        if (_wake != null) {
          final delay = _wake!.difference(clock());
          _cancel = schedule(delay.isNegative ? Duration.zero : delay, () {
            _cancel = null;
            unawaited(synchronize());
          });
        }
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancel?.call();
    _cancel = null;
    unawaited(_states.close());
  }
}
