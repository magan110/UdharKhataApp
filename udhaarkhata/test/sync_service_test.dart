import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/auth/session_store.dart';
import 'package:udhaarkhata/core/network/api_client.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/sync_service.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'helpers/sync_fixture.dart';
import 'sync_coordinator_test.dart' show Scheduled;

void main() {
  late SyncFixture f;
  late GoogleAuthRepository auth;
  late DeviceLedgerRepository repo;
  late SyncService service;
  late ProviderContainer container;
  late DateTime now;
  late List<Scheduled> timers;
  late int authLoss;
  late bool outage, denied, refreshLost;
  late Future<Object?> Function(http.Request)? handler;
  http.Response success(Object? data) =>
      http.Response(jsonEncode({'requestId': 'synthetic', 'data': data}), 200);
  setUp(() async {
    f = SyncFixture();
    await f.open();
    now = DateTime.utc(2026, 10, 2);
    timers = [];
    authLoss = 0;
    outage = false;
    denied = false;
    refreshLost = false;
    handler = null;
    final storage = MemorySecureStorage();
    auth = GoogleAuthRepository(
      api: ApiClient(
        MockClient((r) async {
          if (outage || (refreshLost && r.url.path == '/v1/auth/refresh')) {
            throw http.ClientException('synthetic outage');
          }
          final profile = {
            'id': 'owner',
            'role': 'owner',
            'displayName': 'Synthetic',
            'createdAtMs': 1,
          };
          if (r.url.path == '/v1/auth/google' ||
              r.url.path == '/v1/auth/refresh') {
            return success({
              'account': profile,
              'accessToken': 'a' * 64,
              'refreshToken': 'b' * 64,
              'accessExpiresAtMs': now
                  .add(const Duration(minutes: 15))
                  .millisecondsSinceEpoch,
            });
          }
          if (r.url.path == '/health') {
            return success({
              'status': 'ok',
              'capabilities': ['owner-ledger-sync-v1'],
            });
          }
          if (denied) {
            return http.Response(
              jsonEncode({
                'requestId': 'synthetic',
                'error': {
                  'code': 'AUTH_REQUIRED',
                  'messageKey': 'auth.required',
                  'retryable': false,
                },
              }),
              401,
            );
          }
          if (r.url.path == '/v1/me') return success({'account': profile});
          return success(await handler!(r));
        }),
      ),
      baseUrl: Uri.parse('https://synthetic.test'),
      store: SessionStore(storage),
      database: f.database,
      googleToken: () async => 'synthetic',
      clock: () => now,
    );
    await auth.signIn(AccountRole.owner);
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    await container.read(sessionProvider.future);
    repo = DeviceLedgerRepository(
      auth,
      f.accountId,
      storage,
      f.database,
      onLocalSaved: () => unawaited(service.synchronize()),
    );
    service = SyncService(
      repo,
      clock: () => now,
      schedule: (delay, fire) {
        final timer = Scheduled(delay, fire);
        timers.add(timer);
        return () => timer.active = false;
      },
      onAuthLost: () {
        authLoss++;
        container.read(sessionProvider.notifier).refreshAfterAuthFailure();
      },
    );
  });
  tearDown(() async {
    service.dispose();
    container.dispose();
    await f.close();
  });
  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  for (final uncertain in [false, true]) {
    test(
      uncertain
          ? 'scheduledUncertainRefreshRequestsReauthentication'
          : 'scheduledAuthDenialRequestsReauthentication',
      () async {
        await f.queue();
        outage = true;
        await service.synchronize();
        expect(timers.where((t) => t.active), isNotEmpty);
        outage = false;
        if (uncertain) {
          now = now.add(const Duration(hours: 1));
          refreshLost = true;
        } else {
          now = now.add(const Duration(seconds: 3));
          denied = true;
        }
        final errors = <Object>[];
        runZonedGuarded(
          () => timers.last.fire(),
          (error, stack) => errors.add(error),
        );
        await waitFor(() => authLoss > 0);
        expect(authLoss, 1);
        expect(service.state.running, false);
        expect(errors, isEmpty);
        await waitFor(
          () =>
              container.read(sessionProvider).asData?.value == null &&
              !container.read(sessionProvider).isLoading,
        );
        expect(await container.read(sessionProvider.future), isNull);
        denied = false;
        refreshLost = false;
        await auth.signIn(AccountRole.owner);
        expect(await repo.outbox(), hasLength(1));
      },
    );
  }
  test('manualRefreshAuthLossUsesSameSessionWrapper', () async {
    await f.queue();
    outage = true;
    await service.synchronize();
    outage = false;
    denied = true;
    now = now.add(const Duration(seconds: 3));
    Object? escaped;
    try {
      await service.refreshLink(
        OpaqueId.fromJson('shop'),
        OpaqueId.fromJson('link'),
      );
    } catch (error) {
      escaped = error;
    }
    await waitFor(() => authLoss > 0);
    expect(authLoss, 1);
    expect(service.state.running, false);
    expect(
      escaped,
      isA<AppFailure>().having((e) => e.code, 'code', 'AUTH_REQUIRED'),
    );
    expect(await container.read(sessionProvider.future), isNull);
  });
  test('localSaveDuringPostAutomaticallySchedulesNextBoundedRun', () async {
    await f.queue();
    final entered = Completer<void>(), release = Completer<void>();
    final committed = <Map<String, Object?>>[];
    handler = (r) async {
      if (r.method == 'POST') {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        if (committed.isEmpty) {
          entered.complete();
          await release.future;
        }
        final entry = serverEntry(
          operation: body['clientOperationId'] as String,
          amount: body['amountPaise'] as int,
          seq: committed.length + 1,
        );
        entry['occurredAtMs'] = body['occurredAtMs'];
        committed.add(entry);
        return {'entry': entry, 'replayed': false};
      }
      final after = int.parse(r.url.queryParameters['afterSeq']!);
      return feed(
        items: committed.where((e) => (e['serverSeq'] as int) > after).toList(),
        balance: committed.fold<int>(
          0,
          (sum, e) => sum + (e['effectPaise'] as int),
        ),
        version: committed.length,
        high: committed.length,
        through: committed.length,
      );
    };
    final first = service.synchronize();
    await entered.future;
    final b = await repo.begin(
      OpaqueId.fromJson('shop'),
      OpaqueId.fromJson('link'),
      'Synthetic',
      1,
      null,
      null,
    );
    release.complete();
    await first;
    expect(await repo.outbox(), hasLength(1));
    expect(timers.where((t) => t.active), isNotEmpty);
    now = now.add(const Duration(seconds: 3));
    timers.last.fire();
    await service.synchronize();
    expect(await repo.outbox(), isEmpty);
    expect(
      committed.map((e) => e['clientOperationId']),
      contains(b.operationId),
    );
  });
}
