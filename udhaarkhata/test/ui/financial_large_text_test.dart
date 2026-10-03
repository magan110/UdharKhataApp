import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/credit_form.dart';
import 'package:udhaarkhata/features/ledger/payment_form.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';

import '../auth_session_test.dart' show MemorySecureStorage;
import '../credit_repository_test.dart' show CreditAuth;
import '../payment_repository_test.dart' show PaymentAuth;
import '../owner_link_test.dart' show LinkAuth, linkJson;

void main() {
  for (final payment in [false, true]) {
    testWidgets(
      '${payment ? 'PaymentPage' : 'CreditPage'} Hindi 320 200% keyboard has full amount and reachable review edit',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final creditAuth = CreditAuth()..loseResponse = false;
        final paymentAuth = PaymentAuth();
        final links = LinkAuth()
          ..response = {
            ...linkJson,
            'customerDisplayName': 'ग्राहक का बहुत लंबा नाम और पूरा विवरण',
            'balancePaise': 2000000,
            'ledgerVersion': 1,
          };
        final repository = CloudLedgerRepository(
          payment ? paymentAuth : creditAuth,
          OpaqueId.fromJson('owner'),
          MemorySecureStorage(),
        );
        const l = AppStrings('hi');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ledgerRepositoryProvider.overrideWithValue(repository),
              paymentRepositoryProvider.overrideWithValue(repository),
              ownerLinkRepositoryProvider.overrideWithValue(
                CloudOwnerLinkRepository(
                  links,
                  OpaqueId.fromJson('owner'),
                  MemorySecureStorage(),
                ),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('hi'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: clearCounterTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 300),
                ),
                child: child!,
              ),
              home: payment
                  ? PaymentPage(
                      shopId: OpaqueId.fromJson('shop'),
                      linkId: OpaqueId.fromJson('link'),
                    )
                  : CreditPage(
                      shopId: OpaqueId.fromJson('shop'),
                      linkId: OpaqueId.fromJson('link'),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.widgetWithText(
          TextFormField,
          l.translate(payment ? 'Amount received (₹)' : 'Amount (₹)'),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, '12450');
        final review = find.text(
          l.translate(payment ? 'Review payment' : 'Review credit'),
        );
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₹12,450.00'), findsWidgets);
        final confirm = find.text(
          l.translate(payment ? 'Confirm payment received' : 'Confirm credit'),
        );
        await tester.ensureVisible(confirm);
        expect(confirm.hitTestable(), findsOneWidget);
        final edit = find.text(
          l.translate(payment ? 'Edit payment' : 'Edit credit'),
        );
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(creditAuth.requests, isEmpty);
        expect(paymentAuth.requests, isEmpty);
        expect(field, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
