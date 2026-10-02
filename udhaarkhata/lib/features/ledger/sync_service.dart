import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/cursor_dao.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/db/sync_dao.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../../core/sync/coordinator.dart';
import '../../core/sync/push.dart';
import '../../core/sync/pull.dart';
import '../../core/sync/retry_policy.dart';
import '../auth/session_controller.dart';
import 'device_ledger_repository.dart';
import 'ledger_repository.dart';
import 'local_changes.dart';

class SyncService {
  SyncService(
    this.repository, {
    DateTime Function()? clock,
    this.schedule,
    this.onChanged,
    this.onAuthLost,
  }) : clock = clock ?? DateTime.now,
       _generation = repository.database.generation;
  final DeviceLedgerRepository repository;
  final DateTime Function() clock;
  final SyncSchedule? schedule;
  final void Function()? onChanged, onAuthLost;
  final _states = StreamController<SyncRunState>.broadcast();
  DeviceSyncCoordinator? _coordinator;
  StreamSubscription<SyncRunState>? _subscription;
  Future<void>? _active;
  bool _disposed = false, _authNotified = false, _initialWake = false;
  final int _generation;
  SyncRunState? _terminal;
  void Function()? _cancelInitial;
  void _authLost() {
    if (_disposed || _authNotified) return;
    _authNotified = true;
    _terminal = const SyncRunState(errorCode: 'AUTH_REQUIRED');
    _cancelInitial?.call();
    _states.add(_terminal!);
    onAuthLost?.call();
  }

  void Function() _schedule(Duration delay, void Function() action) {
    if (schedule != null) return schedule!(delay, action);
    final timer = Timer(delay, action);
    return timer.cancel;
  }

  SyncRunState get state =>
      _terminal ?? _coordinator?.state ?? const SyncRunState();
  Stream<SyncRunState> get states => _states.stream;
  Future<void> _capabilities() async {
    Map<String, Object?> health;
    try {
      health = jsonObject(
        await repository.auth.cloudRequest(repository.accountId, '/health'),
      );
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'sync.invalidResponse',
        retryable: true,
      );
    }
    if ((health['apiVersion'] != null && health['apiVersion'] != 1) ||
        health['capabilities'] is! List ||
        !(health['capabilities'] as List).contains('owner-ledger-sync-v1')) {
      throw const AppFailure(
        'FEATURE_UNAVAILABLE',
        'sync.unavailable',
        retryable: true,
      );
    }
  }

  Future<void> synchronize() {
    if (_disposed) return Future.value();
    if (_generation != repository.database.generation) {
      _authLost();
      return Future.value();
    }
    if (_active != null) {
      if (!(_coordinator?.requestAnotherRun() ?? false)) _initialWake = true;
      return _active!;
    }
    _cancelInitial?.call();
    _cancelInitial = null;
    return _active = _run().whenComplete(_finished);
  }

  void _finished() {
    _active = null;
    if (_initialWake && !_disposed && !_authNotified) {
      _initialWake = false;
      _cancelInitial = _schedule(
        const Duration(seconds: 2),
        () => unawaited(synchronize()),
      );
    }
  }

  Future<void> _run({String? refresh}) async {
    final generation = repository.database.generation;
    try {
      if (_coordinator == null) {
        // Include removed links so retained failures remain visible after restart.
        final links = await repository.database.transaction(
          repository.accountId,
          (tx) => tx.rawQuery(
            'SELECT DISTINCT shop_id FROM cached_links WHERE owner_user_id=?',
            [repository.accountId.value],
          ),
        );
        if (_disposed || repository.database.generation != generation) return;
        if (links.isEmpty) return;
        if (links.length != 1) throw StateError('Single owner shop required');
        final dao = SyncDao(
          repository.database,
          repository.accountId,
          generation,
        );
        _coordinator = DeviceSyncCoordinator(
          auth: repository.auth,
          database: repository.database,
          accountId: repository.accountId,
          shopId: links.single['shop_id'] as String,
          push: SyncPush(
            auth: repository.auth,
            dao: dao,
            accountId: repository.accountId,
          ),
          pull: SyncPull(
            auth: repository.auth,
            dao: dao,
            cursors: CursorDao(
              repository.database,
              repository.accountId,
              generation,
            ),
            accountId: repository.accountId,
          ),
          retryPolicy: RetryPolicy(clock: clock, random: Random().nextDouble),
          legacyBlocked: (shop, link) async =>
              await repository.pending(
                    OpaqueId.fromJson(shop),
                    OpaqueId.fromJson(link),
                  ) !=
                  null ||
              await repository.pendingPayment(
                    OpaqueId.fromJson(shop),
                    OpaqueId.fromJson(link),
                  ) !=
                  null,
          clock: clock,
          schedule: schedule,
          beforeRun: _capabilities,
          scheduledRun: synchronize,
        );
        _subscription = _coordinator!.states.listen((state) {
          if (!_disposed) {
            if (!_authNotified) _states.add(state);
            if (state.errorCode == 'AUTH_REQUIRED') _authLost();
            if (!state.running) onChanged?.call();
          }
        });
      }
      final run = refresh == null
          ? _coordinator!.synchronize()
          : _coordinator!.refreshLink(refresh);
      if (_initialWake) {
        _initialWake = !_coordinator!.requestAnotherRun();
      }
      await run;
    } on StateError catch (error) {
      if ([
        'Local access expired',
        'Account database locked',
      ].contains(error.message)) {
        _authLost();
      } else if (repository.database.generation == generation) {
        rethrow;
      }
    } finally {
      if (!_disposed && repository.database.generation != generation) {
        _authLost();
      }
    }
  }

  Future<void> refreshLink(OpaqueId shop, OpaqueId link) async {
    await _active;
    if (_disposed) return;
    if (_generation != repository.database.generation) {
      _authLost();
    } else {
      await (_active = _run(refresh: link.value).whenComplete(_finished));
    }
    final error = state.errorCode;
    if (error != null) {
      throw AppFailure(
        error,
        'sync.failed',
        retryable: !['NOT_FOUND', 'FORBIDDEN', 'AUTH_REQUIRED'].contains(error),
      );
    }
  }

  Future<int?> verifiedAt() => repository.database.transaction(
    repository.accountId,
    (tx) async =>
        (await tx.query('local_account')).single['last_verified_at_ms'] as int?,
  );
  Future<List<Map<String, Object?>>> attention() =>
      repository.database.transaction(
        repository.accountId,
        (tx) => tx.rawQuery(
          "SELECT e.*,o.error_code FROM cached_entries e JOIN outbox o ON o.operation_id=e.client_operation_id JOIN cached_links l ON l.id=e.link_id WHERE o.state='needs_attention' AND l.owner_user_id=? ORDER BY o.rowid",
          [repository.accountId.value],
        ),
      );
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelInitial?.call();
    _coordinator?.dispose();
    unawaited(_subscription?.cancel());
    unawaited(_states.close());
  }
}

final Provider<SyncService?> syncServiceProvider =
    Provider.autoDispose<SyncService?>((ref) {
      final repo = ref.watch(ledgerRepositoryProvider);
      if (repo is! DeviceLedgerRepository ||
          repo.auth is! GoogleAuthRepository) {
        return null;
      }
      final service = SyncService(
        repo,
        onChanged: () {
          if (ref.mounted) {
            ref.read(cacheRevisionProvider.notifier).bump();
            ref.invalidate(savedCustomersProvider);
          }
        },
        onAuthLost: () {
          if (ref.mounted) {
            ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
          }
        },
      );
      ref.listen(
        syncWakeRevisionProvider,
        (_, _) => unawaited(service.synchronize()),
      );
      ref.onDispose(service.dispose);
      scheduleMicrotask(() => unawaited(service.synchronize()));
      return service;
    });
final StreamProvider<SyncRunState> syncRunStateProvider =
    StreamProvider.autoDispose<SyncRunState>((ref) async* {
      final service = ref.watch(syncServiceProvider);
      yield service?.state ?? const SyncRunState();
      if (service != null) yield* service.states;
    });

class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(syncServiceProvider)?.synchronize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider);
    return widget.child;
  }
}
