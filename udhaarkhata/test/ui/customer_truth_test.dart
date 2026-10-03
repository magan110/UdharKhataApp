import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';

import '../history_ui_test.dart' show HistoryAuth;

class EmptyShopsAuth extends HistoryAuth {
  EmptyShopsAuth() : super(AccountRole.customer);
  @override
  Future<Object?> cloudRequest(
    OpaqueId id,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (path.startsWith('/v1/me/ledgers?'))
      return {
        'links': [],
        'snapshotAtMs': 1790985600000,
        'page': {'hasMore': false, 'nextCursor': null},
      };
    return super.cloudRequest(id, path, body: body);
  }
}

void main() {
  testWidgets('no shops offers show QR without invented customer total', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(EmptyShopsAuth())],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const MainApp()),
    );
    await tester.pumpAndSettle();
    c.read(routerProvider).go('/customer?tab=shops');
    await tester.pumpAndSettle();
    expect(find.text('Show my QR'), findsOneWidget);
    expect(find.text('₹0.00'), findsNothing);
    await tester.tap(find.text('Show my QR'));
    await tester.pumpAndSettle();
    expect(find.text('Show this to the shopkeeper'), findsOneWidget);
  });
}
