import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/local_ledger_view.dart';
import 'package:udhaarkhata/features/ledger/local_changes.dart';
import 'package:udhaarkhata/features/ledger/sync_service.dart';
import 'package:udhaarkhata/features/ledger/sync_status_view.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'helpers/sync_fixture.dart';

void main() {
  late SyncFixture f;
  late DeviceLedgerRepository repo;
  late SyncService service;
  late ProviderContainer container;
  late DateTime now;
  setUp(() async {
    f = SyncFixture();
    await f.open(noIsolate: true);
    now = DateTime.utc(2026, 10, 2);
    repo = DeviceLedgerRepository(
      f.auth,
      f.accountId,
      MemorySecureStorage(),
      f.database,
    );
    service = SyncService(
      repo,
      clock: () => now,
      schedule: (delay, fire) => () {},
      onChanged: () {
        container.read(cacheRevisionProvider.notifier).bump();
      },
    );
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(f.auth),
        ledgerRepositoryProvider.overrideWithValue(repo),
        ownerLinkRepositoryProvider.overrideWithValue(null),
        syncServiceProvider.overrideWithValue(service),
      ],
    );
  });
  tearDown(() async {
    service.dispose();
    container.dispose();
    await f.close();
  });
  Future<void> settle(WidgetTester tester, Finder expected) async {
    for (var i = 0; i < 500; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
      if (expected.evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    expect(expected, findsWidgets);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SyncStatusView(),
                  LocalLedgerView(shopId: 'shop', linkId: 'link'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester, find.textContaining('Synced balance:'));
  }

  testWidgets('pendingToSyncedAfterReconnect', (tester) async {
    await f.queue();
    f.auth.offline = true;
    f.auth.handler = (path, body) async {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    };
    await tester.runAsync(service.synchronize);
    await open(tester);
    expect(find.textContaining('Pending · Waiting to sync'), findsOneWidget);
    expect(find.textContaining('Synced balance: ₹0.00'), findsOneWidget);
    var committed = false;
    f.auth.offline = false;
    now = now.add(const Duration(seconds: 3));
    f.auth.handler = (path, body) async {
      if (body != null) {
        committed = true;
        return {'entry': serverEntry(), 'replayed': false};
      }
      return committed
          ? feed()
          : feed(items: [], balance: 0, version: 0, high: 0, through: 0);
    };
    await tester.tap(find.text('Sync now'));
    await settle(tester, find.textContaining('Synced balance: ₹500.00'));
    expect(find.textContaining('Pending · Waiting to sync'), findsNothing);
    expect(await tester.runAsync(repo.outbox), isEmpty);
  });
  testWidgets('rejectionShowsOriginalAndBlockedSuccessors', (tester) async {
    await f.queue();
    await f.queue(operation: operationB, amount: 1);
    f.auth.handler = (path, body) async {
      if (body != null) {
        throw const AppFailure('BALANCE_CONFLICT', 'payment.conflict');
      }
      return feed(items: [], balance: 0, version: 0, high: 0, through: 0);
    };
    await tester.runAsync(service.synchronize);
    await open(tester);
    expect(find.textContaining('Needs attention'), findsWidgets);
    expect(find.text('Credit ₹500.00'), findsWidgets);
    expect(find.textContaining('Blocked by an earlier entry'), findsWidgets);
    expect(find.textContaining('Customer owes you ₹0.01'), findsOneWidget);
    expect(find.textContaining('Synced balance: ₹0.00'), findsOneWidget);
    expect(find.textContaining('Original entry is retained'), findsWidgets);
  });
  testWidgets('offlineRestartShowsDatedCache', (tester) async {
    await f.queue();
    f.auth.offline = true;
    f.auth.handler = (path, body) async {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    };
    await tester.runAsync(service.synchronize);
    await open(tester);
    expect(find.textContaining('Offline'), findsWidgets);
    expect(find.textContaining('Last verified'), findsWidgets);
    expect(find.textContaining('only on this device'), findsWidgets);
  });
  testWidgets('removedAccessExplainsAndRetainsQueuedEntry', (tester) async {
    await f.queue();
    f.auth.handler = (path, body) async {
      throw const AppFailure('NOT_FOUND', 'api.notFound');
    };
    await tester.runAsync(service.synchronize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SyncStatusView())),
        ),
      ),
    );
    await settle(tester, find.textContaining('Original entry is retained'));
    expect(find.textContaining('Access is no longer available'), findsWidgets);
    expect(await tester.runAsync(repo.outbox), hasLength(1));
  });
  testWidgets('largeLedgerRetainsServerFallback', (tester) async {
    await f.queue();
    f.auth.handler = (path, body) async =>
        feed(items: [], balance: 1, version: 10001, high: 10001, through: 0);
    await tester.runAsync(service.synchronize);
    await open(tester);
    expect(find.text('View confirmed server history'), findsOneWidget);
    expect(find.textContaining('too large for offline entry'), findsWidgets);
    expect((await tester.runAsync(repo.outbox))!.single['state'], 'pending');
    expect(f.auth.requests.where((r) => r.body != null), isEmpty);
  });
  testWidgets('rollbackAfterHealthRetainsPending', (tester) async {
    await f.queue();
    f.auth.handler = (path, body) async {
      f.auth.supportsSync = false;
      throw const AppFailure('NOT_FOUND', 'api.notFound');
    };
    await tester.runAsync(service.synchronize);
    expect((await tester.runAsync(repo.outbox))!.single['state'], 'pending');
    expect(service.state.errorCode, 'FEATURE_UNAVAILABLE');
  });
  testWidgets('olderWorkerCannotRejectLocalQueueAsMissingRoute', (
    tester,
  ) async {
    await f.queue();
    f.auth.supportsSync = false;
    f.auth.handler = (path, body) async {
      throw const AppFailure('NOT_FOUND', 'api.notFound');
    };
    await tester.runAsync(service.synchronize);
    final rows = await tester.runAsync(repo.outbox);
    expect(rows!.single['state'], 'pending');
    expect(service.state.errorCode, 'FEATURE_UNAVAILABLE');
    expect(f.auth.requests.where((r) => r.body != null), isEmpty);
  });
}
