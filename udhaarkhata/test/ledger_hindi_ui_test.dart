import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/correction_form.dart';
import 'package:udhaarkhata/features/ledger/credit_form.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/local_ledger_view.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'helpers/sync_fixture.dart';

class HindiCorrectionRepository implements CorrectionRepository {
  @override
  Future<void> saveCorrection(
    OpaqueId shop,
    OpaqueId link,
    String id,
    int amount,
    int revision,
    String reason,
  ) async {}
}

Widget hindiApp(Widget child) => MaterialApp(
  locale: const Locale('hi'),
  supportedLocales: AppStrings.supportedLocales,
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
    child: child!,
  ),
  home: child is CorrectionPage || child is CreditPage
      ? child
      : Scaffold(body: SingleChildScrollView(child: child)),
);
void main() {
  testWidgets(
    'Hindi correction success communicates Pending device-only backup at 200 percent',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            correctionRepositoryProvider.overrideWithValue(
              HindiCorrectionRepository(),
            ),
          ],
          child: hindiApp(
            const CorrectionPage(
              shopId: 'shop',
              linkId: 'link',
              entryId: 'entry',
              effectiveAmountPaise: 10000,
              revision: 0,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.enterText(find.byType(TextField).last, 'Synthetic reason');
      final review = find.text(
        const AppStrings('hi').translate('Review correction'),
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      final confirm = find.text(
        const AppStrings('hi').translate('Confirm correction'),
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text(const AppStrings('hi').text('ui112')), findsOneWidget);
      expect(find.textContaining('Correction saved'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Hindi saved owner ledger shows direction and Pending exclusion at 200 percent',
    (tester) async {
      final fixture = SyncFixture();
      await tester.runAsync(() async {
        await fixture.open(noIsolate: true);
        await fixture.queue();
      });
      try {
        fixture.auth.offline = true;
        fixture.auth.handler = (path, body) async => throw const AppFailure(
          'NETWORK_ERROR',
          'api.networkError',
          retryable: true,
        );
        final repo = DeviceLedgerRepository(
          fixture.auth,
          fixture.accountId,
          MemorySecureStorage(),
          fixture.database,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
            child: hindiApp(
              const LocalLedgerView(shopId: 'shop', linkId: 'link'),
            ),
          ),
        );
        for (var i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 10));
          if (find.textContaining('ग्राहक को आपको').evaluate().isNotEmpty &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
        }
        expect(
          find.textContaining('ग्राहक को आपको ₹500.00 देना है'),
          findsOneWidget,
        );
        expect(find.text(const AppStrings('hi').text('ui104')), findsOneWidget);
        expect(find.text(const AppStrings('hi').text('ui90')), findsOneWidget);
        expect(find.textContaining('Customer owes you'), findsNothing);
        expect(
          find.text(
            const AppStrings('hi')
                .translate('Pending · Waiting to sync · Only on this device'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.close);
      }
    },
  );
  testWidgets(
    'Hindi credit review is inert and saved credit shows Pending and backup warning at 200 percent',
    (tester) async {
      final fixture = SyncFixture();
      await tester.runAsync(() => fixture.open(noIsolate: true));
      try {
        fixture.auth.offline = true;
        fixture.auth.handler = (path, body) async => throw const AppFailure(
          'NETWORK_ERROR',
          'api.networkError',
          retryable: true,
        );
        final repo = DeviceLedgerRepository(
          fixture.auth,
          fixture.accountId,
          MemorySecureStorage(),
          fixture.database,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
            child: hindiApp(
              CreditPage(
                shopId: OpaqueId.fromJson('shop'),
                linkId: OpaqueId.fromJson('link'),
              ),
            ),
          ),
        );
        for (var i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          if (find.byType(TextFormField).evaluate().isNotEmpty) break;
        }
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            const AppStrings('hi').translate('Amount (₹)'),
          ),
          '200',
        );
        final review = find.text(
          const AppStrings('hi').translate('Review credit'),
        );
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(await tester.runAsync(repo.outbox), isEmpty);
        expect(
          find.textContaining('ग्राहक को आपको ₹200.00 और देना है'),
          findsOneWidget,
        );
        final confirm = find.text(
          const AppStrings('hi').translate('Confirm credit'),
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        for (var i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          if (find
              .textContaining('ग्राहक को आपको ₹200.00 देना है')
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        expect(
          find.text(const AppStrings('hi').translate('Credit saved · Pending')),
          findsOneWidget,
        );
        expect(find.text(const AppStrings('hi').text('ui85')), findsOneWidget);
        expect(
          find.textContaining('ग्राहक को आपको ₹200.00 देना है'),
          findsOneWidget,
        );
        expect(await tester.runAsync(repo.outbox), hasLength(1));
        expect(find.text('Credit acknowledged by server'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.close);
      }
    },
  );
}
