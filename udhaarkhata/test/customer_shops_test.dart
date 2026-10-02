import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/ledger/customer_shell.dart';

import 'router_test.dart' show syntheticAccount;

class ProfileAuth extends AuthRepository {
  Object profile = {'links': [], 'linksHasMore': false};
  bool offline = false;
  @override
  Future<Account?> restoreSession() async =>
      syntheticAccount(AccountRole.customer);
  @override
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (offline) throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    if (!path.startsWith('/v1/me/ledgers')) {
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
    }
    final row = profile as Map<String, Object?>;
    final links = row['links'];
    return {
      'links': links is List
          ? [
              for (final link in links)
                {
                  'balancePaise': 0,
                  'ledgerVersion': 0,
                  ...link as Map<String, Object?>,
                },
            ]
          : links,
      'snapshotAtMs': 1,
      'page': {
        'hasMore': row['linksHasMore'],
        'nextCursor': row['linksHasMore'] == true ? 'next_page' : null,
      },
    };
  }
}

Future<void> openShops(WidgetTester tester, ProfileAuth auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: CustomerShell()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('My shops'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('linked shop appears and refresh replaces removed links', (
    tester,
  ) async {
    final auth = ProfileAuth()
      ..profile = {
        'links': [
          {'id': 'link', 'shopId': 'shop', 'shopName': 'Kiran Store'},
        ],
        'linksHasMore': false,
      };
    await openShops(tester, auth);
    expect(find.text('Kiran Store'), findsOneWidget);
    expect(find.text('No shops are linked to this account.'), findsNothing);
    auth.profile = {'links': [], 'linksHasMore': false};
    await tester.tap(find.text('Refresh shops'));
    await tester.pumpAndSettle();
    expect(find.text('Kiran Store'), findsNothing);
    expect(find.text('No shops are linked to this account.'), findsOneWidget);
  });
  testWidgets('failed lookup does not claim no shops and refresh recovers', (
    tester,
  ) async {
    final auth = ProfileAuth()..offline = true;
    await openShops(tester, auth);
    expect(find.text('No shops are linked to this account.'), findsNothing);
    auth.offline = false;
    await tester.tap(find.text('Refresh shops'));
    await tester.pumpAndSettle();
    expect(find.text('No shops are linked to this account.'), findsOneWidget);
  });
  testWidgets('malformed list is an error rather than an empty list', (
    tester,
  ) async {
    final auth = ProfileAuth()
      ..profile = {'links': null, 'linksHasMore': false};
    await openShops(tester, auth);
    expect(find.text('No shops are linked to this account.'), findsNothing);
    expect(find.text('Refresh shops'), findsOneWidget);
  });
  testWidgets('new links load when returning to My shops', (tester) async {
    final auth = ProfileAuth();
    await openShops(tester, auth);
    await tester.tap(find.text('My QR'));
    await tester.pumpAndSettle();
    auth.profile = {
      'links': [
        {'id': 'link', 'shopId': 'shop', 'shopName': 'New Store'},
      ],
      'linksHasMore': true,
    };
    await tester.tap(find.text('My shops'));
    await tester.pumpAndSettle();
    expect(find.text('New Store'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
  });
  testWidgets('customer sees the server balance with explicit owed direction', (
    tester,
  ) async {
    final auth = ProfileAuth()
      ..profile = {
        'links': [
          {
            'id': 'link',
            'shopId': 'shop',
            'shopName': 'Kiran Store',
            'balancePaise': 50000,
            'ledgerVersion': 1,
          },
        ],
        'linksHasMore': false,
      };
    await openShops(tester, auth);
    expect(
      find.text('You owe Kiran Store ₹500.00 (last server read).'),
      findsOneWidget,
    );
  });
}
