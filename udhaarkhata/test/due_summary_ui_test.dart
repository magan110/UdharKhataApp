import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/due_summary.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/local_changes.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'helpers/sync_fixture.dart';

void main() {
  late SyncFixture fixture;
  late ProviderContainer container;
  setUp(() async {
    fixture = SyncFixture();
    await fixture.open(noIsolate: true);
    final repo = DeviceLedgerRepository(
      fixture.auth,
      fixture.accountId,
      MemorySecureStorage(),
      fixture.database,
    );
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fixture.auth),
        ledgerRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await container.read(sessionProvider.future);
    fixture.auth.handler = (path, body) async {
      final date = Uri.parse(path).queryParameters['asOfDate'];
      return {
        'asOfDate': date,
        'balancePaise': 0,
        'overduePaise': 0,
        'asOfServerSeq': 0,
        'asOfMs': DateTime.now().millisecondsSinceEpoch,
      };
    };
  });
  tearDown(() async {
    container.dispose();
    await fixture.close();
  });
  Future<void> open(WidgetTester tester) async => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DueSummary(shopId: 'shop', linkId: 'link'),
        ),
      ),
    ),
  );
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.textContaining('Outstanding:').evaluate().isNotEmpty ||
          find
              .textContaining('Due totals unavailable.')
              .evaluate()
              .isNotEmpty) {
        break;
      }
    }
  }

  testWidgets(
    'Fresh due summary automatically disappears on local mutation and expiry',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Refresh due summary'));
      await settle(tester);
      expect(find.text('Outstanding: ₹0.00'), findsOneWidget);
      container.read(cacheRevisionProvider.notifier).bump();
      await tester.pump();
      expect(find.textContaining('Outstanding:'), findsNothing);
      await tester.tap(find.text('Refresh due summary'));
      await settle(tester);
      expect(find.text('Outstanding: ₹0.00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(find.textContaining('Outstanding:'), findsNothing);
    },
  );
  testWidgets('Pending entries suppress due request', (tester) async {
    await tester.runAsync(fixture.queue);
    await open(tester);
    await tester.tap(find.text('Refresh due summary'));
    await settle(tester);
    expect(find.textContaining('Outstanding:'), findsNothing);
    expect(fixture.auth.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Stale due response never shows monetary summary', (
    tester,
  ) async {
    fixture.auth.handler = (path, body) async => {
      'asOfDate': Uri.parse(path).queryParameters['asOfDate'],
      'balancePaise': 0,
      'overduePaise': 0,
      'asOfServerSeq': 0,
      'asOfMs': DateTime.now()
          .subtract(const Duration(minutes: 2))
          .millisecondsSinceEpoch,
    };
    await open(tester);
    await tester.tap(find.text('Refresh due summary'));
    await settle(tester);
    expect(find.textContaining('Outstanding:'), findsNothing);
    expect(fixture.auth.requests, hasLength(1));
  });
}
