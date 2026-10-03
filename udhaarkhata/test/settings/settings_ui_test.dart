import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/app/localization.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/settings/settings_page.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';

class TestPrivacyAuth extends AuthRepository {
  TestPrivacyAuth(this.role);
  AccountRole role;
  bool fail = false;
  final posts = <Map<String, Object?>>[];
  Account get account => Account(
    id: OpaqueId.fromJson(role.name),
    role: role,
    displayName: 'Synthetic',
    createdAtMs: 1,
  );
  @override
  Future<Account?> restoreSession() async => account;
  @override
  Future<Account> signIn(AccountRole requested) async {
    role = requested;
    return account;
  }

  Map<String, Object?> request(String kind) => {
    'id': 'request_${role.name}',
    'kind': kind,
    'shopId': kind == 'account_deletion' ? null : 'shop',
    'status': 'submitted',
    'createdAtMs': 1,
    'resolvedAtMs': null,
  };
  @override
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (fail) {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
        requestId: 'support-request',
      );
    }
    expectSync(accountId.value, role.name);
    if (body != null) {
      posts.add(body);
      return request(body['kind'] as String);
    }
    return {
      'requests': [
        request(role == AccountRole.owner ? 'export' : 'account_deletion'),
      ],
      'hasMore': false,
    };
  }
}

class TestSettingsApp extends ConsumerWidget {
  const TestSettingsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: ref.watch(localeProvider).asData?.value ?? const Locale('en'),
    supportedLocales: AppStrings.supportedLocales,
    localizationsDelegates: const [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: const SettingsPage(),
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<ProviderContainer> open(
    WidgetTester tester,
    TestPrivacyAuth auth,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        currentShopProvider.overrideWith(
          (ref) async => Shop(OpaqueId.fromJson('shop'), 'Synthetic shop'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestSettingsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'customer deletion requires confirmation and submitted status never implies erased history',
    (tester) async {
      final auth = TestPrivacyAuth(AccountRole.customer);
      await open(tester, auth);
      expect(find.text('Request shop deletion'), findsNothing);
      expect(
        find.textContaining('does not perform destructive deletion'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Request account deletion'));
      await tester.tap(find.text('Request account deletion'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not immediately delete'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.posts, isEmpty);
      await tester.tap(find.text('Request account deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(auth.posts, [
        {'kind': 'account_deletion'},
      ]);
      expect(find.textContaining('Submitted'), findsOneWidget);
    },
  );
  testWidgets(
    'owner scoped export and shop deletion create tracked requests, not financial writes',
    (tester) async {
      final auth = TestPrivacyAuth(AccountRole.owner);
      await open(tester, auth);
      for (final label in [
        'Request shop data export',
        'Request shop deletion',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit request'));
        await tester.pumpAndSettle();
      }
      expect(auth.posts, [
        {'kind': 'export', 'shopId': 'shop'},
        {'kind': 'shop_deletion', 'shopId': 'shop'},
      ]);
    },
  );
  testWidgets(
    'language selection persists and account change clears prior request identity',
    (tester) async {
      final auth = TestPrivacyAuth(AccountRole.owner);
      final container = await open(tester, auth);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('हिन्दी').last);
      await tester.pumpAndSettle();
      expect(container.read(localeProvider).asData?.value, const Locale('hi'));
      expect(find.text('डेटा अनुरोध'), findsOneWidget);
      await container
          .read(sessionProvider.notifier)
          .signIn(AccountRole.customer);
      await tester.pumpAndSettle();
      expect(find.text('request_owner'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('request_customer'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('request_customer'), findsOneWidget);
    },
  );
  testWidgets('cloud failure shows retry and preserves request semantics', (
    tester,
  ) async {
    final auth = TestPrivacyAuth(AccountRole.customer)..fail = true;
    await open(tester, auth);
    expect(find.textContaining('Could not connect'), findsOneWidget);
    auth.fail = false;
    await tester.ensureVisible(find.text('Refresh request status'));
    await tester.tap(find.text('Refresh request status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not connect'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('request_customer'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('request_customer'), findsOneWidget);
  });
}
