import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/db/cursor_dao.dart';
import 'package:udhaarkhata/core/db/outbox_dao.dart';
import 'package:udhaarkhata/core/db/sync_dao.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/sync/coordinator.dart';
import 'package:udhaarkhata/core/sync/push.dart';
import 'package:udhaarkhata/core/sync/pull.dart';
import 'package:udhaarkhata/core/sync/retry_policy.dart';

import 'helpers/sync_fixture.dart';

final class Scheduled {
  Scheduled(this.delay, this.fire);
  final Duration delay;
  final void Function() fire;
  bool active = true;
}

void main() {
  late SyncFixture f;
  late DeviceSyncCoordinator coordinator;
  late DateTime now;
  late List<Scheduled> timers;
  late bool legacy;
  setUp(() async {
    f = SyncFixture();
    await f.open();
    now = DateTime.utc(2026, 10, 2);
    timers = [];
    legacy = false;
    final dao = SyncDao(f.database, f.accountId, f.database.generation);
    coordinator = DeviceSyncCoordinator(
      auth: f.auth,
      database: f.database,
      accountId: f.accountId,
      shopId: 'shop',
      push: SyncPush(auth: f.auth, dao: dao, accountId: f.accountId),
      pull: SyncPull(
        auth: f.auth,
        dao: dao,
        cursors: CursorDao(f.database, f.accountId, f.database.generation),
        accountId: f.accountId,
      ),
      retryPolicy: RetryPolicy(clock: () => now, random: () => 1),
      clock: () => now,
      legacyBlocked: (shop, link) async => legacy,
      schedule: (delay, fire) {
        final timer = Scheduled(delay, fire);
        timers.add(timer);
        return () {
          timer.active = false;
        };
      },
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await f.close();
  });
  test('coalescedTriggersBoundedSerialRun', () async {
    for (var i = 0; i < 25; i++) {
      await f.queue(
        operation:
            '00000000-0000-4000-8000-${(100 + i).toString().padLeft(12, '0')}',
        amount: 1,
      );
    }
    var inFlight = 0, maxInFlight = 0;
    final committed = <Map<String, Object?>>[];
    f.auth.handler = (path, body) async {
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(Duration.zero);
      Object result;
      if (body != null) {
        final e = serverEntry(
          operation: body['clientOperationId'] as String,
          seq: committed.length + 1,
          amount: 1,
        );
        committed.add(e);
        result = {'entry': e, 'replayed': false};
      } else {
        final after = int.parse(
          Uri.parse(path).queryParameters['afterSeq'] ?? '0',
        );
        result = feed(
          items: committed
              .where((e) => (e['serverSeq'] as int) > after)
              .toList(),
          balance: committed.length,
          version: committed.length,
          high: committed.length,
          through: committed.length,
        );
      }
      inFlight--;
      return result;
    };
    await Future.wait([
      coordinator.synchronize(),
      coordinator.synchronize(),
      coordinator.synchronize(),
    ]);
    expect(maxInFlight, 1);
    expect(f.auth.requests.where((r) => r.body != null), hasLength(20));
    expect(await OutboxDao(f.database, f.accountId).entries(), hasLength(5));
    expect(timers.any((t) => t.active), isTrue);
  });
  test('retryBlocksDependentButNotOtherLink', () async {
    await f.addLink('second');
    await f.queue();
    await f.queue(operation: operationB);
    await f.queue(
      operation: '00000000-0000-4000-8000-000000000023',
      link: 'second',
      amount: 1,
    );
    final committed = <Map<String, Object?>>[];
    f.auth.handler = (path, body) async {
      final second = path.contains('/second/');
      if (body != null) {
        if (body['linkId'] == 'link') {
          throw const AppFailure(
            'INVALID_RESPONSE',
            'api.invalidResponse',
            retryable: true,
          );
        }
        final e = serverEntry(
          operation: body['clientOperationId'] as String,
          link: 'second',
          amount: 1,
        );
        committed.add(e);
        return {'entry': e, 'replayed': false};
      }
      return feed(
        link: second ? 'second' : 'link',
        items: second ? committed : [],
        balance: second ? committed.length : 0,
        version: second ? committed.length : 0,
        high: second ? committed.length : 0,
        through: second ? committed.length : 0,
      );
    };
    await coordinator.synchronize();
    expect(
      f.auth.requests.where((r) => r.body?['linkId'] == 'link'),
      hasLength(1),
    );
    expect(
      f.auth.requests.where((r) => r.body?['linkId'] == 'second'),
      hasLength(1),
    );
    final rows = await OutboxDao(f.database, f.accountId).entries();
    expect(rows, hasLength(2));
    expect(
      rows.first['retry_at_ms'],
      now.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
    );
  });
  test('authAndQuotaStopWholeRun', () async {
    await f.queue();
    await f.addLink('second');
    for (final code in ['AUTH_REQUIRED', 'CAPACITY_UNAVAILABLE']) {
      f.auth.requests.clear();
      f.auth.handler = (path, body) async {
        throw AppFailure(
          code,
          'api.failure',
          retryable: code != 'AUTH_REQUIRED',
        );
      };
      await coordinator.synchronize();
      expect(f.auth.requests, hasLength(1));
      expect(await OutboxDao(f.database, f.accountId).entries(), hasLength(1));
      expect(coordinator.state.errorCode, code);
    }
  });
  test('cachedLinksBeyondListCeilingReauthorized', () async {
    for (var i = 0; i < 105; i++) {
      await f.addLink('many$i');
    }
    f.auth.handler = (path, body) async {
      final id = Uri.parse(path).pathSegments[4];
      return feed(
        link: id,
        items: [],
        balance: 0,
        version: 0,
        high: 0,
        through: 0,
      );
    };
    for (var i = 0; i < 6; i++) {
      await coordinator.synchronize();
    }
    final scopes = f.auth.requests
        .map((r) => Uri.parse(r.path).pathSegments[4])
        .toSet();
    expect(scopes, hasLength(106));
    expect(f.auth.requests.every((r) => r.path.contains('/sync?')), isTrue);
  });
  test('permanentRejectionRetainsAndBlocksOriginal', () async {
    await f.queue();
    await f.queue(operation: operationB, amount: 1);
    f.auth.handler = (path, body) async {
      if (body != null) {
        throw const AppFailure('BALANCE_CONFLICT', 'payment.conflict');
      }
      return feed(items: [], balance: 0, version: 0, high: 0, through: 0);
    };
    await coordinator.synchronize();
    final rows = await OutboxDao(f.database, f.accountId).entries();
    expect(rows.first['state'], 'needs_attention');
    expect(rows.first['payload'], contains(operationA));
    expect(rows.last['state'], 'pending');
    expect(f.auth.requests.where((r) => r.body != null), hasLength(1));
    expect(coordinator.state.needsAttentionCount, 1);
  });
  test('legacyBlocksAutomaticPostWithoutReadingSecureCommand', () async {
    await f.queue();
    legacy = true;
    f.auth.handler = (path, body) async =>
        feed(items: [], balance: 0, version: 0, high: 0, through: 0);
    await coordinator.synchronize();
    expect(f.auth.requests.every((r) => r.body == null), isTrue);
    expect(await OutboxDao(f.database, f.accountId).entries(), hasLength(1));
  });
  test('lateGenerationNeverApplies', () async {
    await f.queue();
    final started = Completer<void>(), release = Completer<void>();
    f.auth.handler = (path, body) async {
      started.complete();
      await release.future;
      return feed();
    };
    final run = coordinator.synchronize();
    await started.future;
    await f.database.lock();
    await f.database.openForAccount(f.accountId);
    release.complete();
    await run;
    expect(await OutboxDao(f.database, f.accountId).entries(), hasLength(1));
    expect(
      await CursorDao(
        f.database,
        f.accountId,
        f.database.generation,
      ).sequence('link'),
      0,
    );
  });
  test('retryAfterAndDisposeCancelTimer', () async {
    await f.queue();
    f.auth.handler = (path, body) async {
      throw AppFailure(
        'RATE_LIMITED',
        'api.rateLimit',
        httpStatus: 429,
        retryAfter: now.add(const Duration(hours: 2)),
      );
    };
    await coordinator.synchronize();
    expect(timers.last.delay, const Duration(hours: 2));
    coordinator.dispose();
    expect(timers.every((t) => !t.active), isTrue);
  });
  test('restartMidPullAndExpiredContinuation', () async {
    f.auth.handler = (path, body) async {
      if (path.contains('cursor=')) {
        throw const AppFailure('CURSOR_INVALID', 'api.cursorInvalid');
      }
      final after = int.parse(Uri.parse(path).queryParameters['afterSeq']!);
      if (after == 0) {
        return feed(
          items: [serverEntry(amount: 1)],
          balance: 2,
          version: 2,
          high: 2,
          through: 1,
          cursor: 'expired',
        );
      }
      return feed(
        items: [serverEntry(operation: operationB, seq: 2, amount: 1)],
        balance: 2,
        version: 2,
        high: 2,
        through: 2,
      );
    };
    await coordinator.synchronize();
    expect(
      await CursorDao(
        f.database,
        f.accountId,
        f.database.generation,
      ).sequence('link'),
      2,
    );
    expect(
      f.auth.requests.where((r) => r.path.contains('afterSeq=1')),
      hasLength(1),
    );
  });
  test('persistedRunBackoffSurvivesCoordinatorRestart', () async {
    await f.queue();
    f.auth.handler = (path, body) async {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    };
    await coordinator.synchronize();
    final count = f.auth.requests.length;
    coordinator.dispose();
    await f.database.lock();
    await f.database.openForAccount(f.accountId);
    final dao = SyncDao(f.database, f.accountId, f.database.generation);
    coordinator = DeviceSyncCoordinator(
      auth: f.auth,
      database: f.database,
      accountId: f.accountId,
      shopId: 'shop',
      push: SyncPush(auth: f.auth, dao: dao, accountId: f.accountId),
      pull: SyncPull(
        auth: f.auth,
        dao: dao,
        cursors: CursorDao(f.database, f.accountId, f.database.generation),
        accountId: f.accountId,
      ),
      retryPolicy: RetryPolicy(clock: () => now, random: () => 1),
      clock: () => now,
      legacyBlocked: (shop, link) async => false,
      schedule: (delay, fire) {
        final timer = Scheduled(delay, fire);
        timers.add(timer);
        return () {
          timer.active = false;
        };
      },
    );
    await coordinator.synchronize();
    expect(f.auth.requests, hasLength(count));
    expect(timers.last.delay, const Duration(seconds: 2));
    expect(await OutboxDao(f.database, f.accountId).entries(), hasLength(1));
  });
}
