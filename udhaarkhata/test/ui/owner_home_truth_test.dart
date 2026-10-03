import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/ledger/history_page.dart';
import 'package:udhaarkhata/features/ledger/online_reads.dart';
import 'package:flutter/material.dart';

import '../history_ui_test.dart' show HistoryAuth;

class SummaryAuth extends HistoryAuth {
  SummaryAuth() : super(AccountRole.owner);
  bool unavailable = false;
  @override
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (path == '/v1/shops/shop') {
      if (unavailable) {
        throw const AppFailure(
          'NETWORK_ERROR',
          'api.internalError',
          retryable: true,
        );
      }
      return {
        'id': 'shop',
        'name': 'Store',
        'status': 'active',
        'createdAtMs': 1,
        'totalBalancePaise': 1245000,
        'customerCount': 4,
        'asOfAtMs': 1790985600000,
      };
    }
    if (path.contains('/customers')) {
      return {
        'customers': [
          for (var i = 0; i < 4; i++)
            {
              'id': 'link$i',
              'shopId': 'shop',
              'customerUserId': 'customer$i',
              'customerDisplayName': 'Customer $i',
              'shopNickname': null,
              'linkedAtMs': 1790985600000,
              'status': 'active',
              'balancePaise': 15000,
              'ledgerVersion': 1,
            },
        ],
        'page': {'hasMore': false, 'nextCursor': null},
        'snapshotAtMs': 1790985600000,
      };
    }
    return super.cloudRequest(accountId, path, body: body);
  }
}

void main() {
  testWidgets(
    'confirmed total is endpoint total rather than loaded customer sums',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(SummaryAuth())],
          child: const MainApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹12,450.00'), findsOneWidget);
      expect(find.text('Confirmed balance'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Customer 0'), findsOneWidget);
      expect(find.text('Customer 2'), findsOneWidget);
      expect(find.text('Customer 3'), findsNothing);
    },
  );
  testWidgets('unavailable confirmed total is not a zero balance', (
    tester,
  ) async {
    final auth = SummaryAuth()..unavailable = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirmed total unavailable'), findsOneWidget);
    expect(find.text('₹0.00'), findsNothing);
  });
  testWidgets(
    'old account delayed history cannot repopulate a replaced provider',
    (tester) async {
      final old = HistoryAuth(AccountRole.owner)
        ..delayed = Completer<Object?>();
      final next = HistoryAuth(AccountRole.owner)
        ..name = 'New account customer';
      Future<void> mount(HistoryAuth auth) async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(auth),
            overrides: [authRepositoryProvider.overrideWithValue(auth)],
            child: const MaterialApp(
              home: SingleChildScrollView(
                child: OnlineRecordsView(
                  path: '/v1/shops/shop/customers/link/entries',
                  kind: OnlineReadKind.history,
                  shopId: 'shop',
                  linkId: 'link',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await mount(old);
      await mount(next);
      await tester.pumpAndSettle();
      old.delayed!.complete({'invalid': 'old response'});
      await tester.pumpAndSettle();
      expect(find.text('New account customer'), findsOneWidget);
      expect(find.text('Synthetic Customer'), findsNothing);
    },
  );
}
