import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';

import '../helpers/ux01_fixtures.dart';

void main() {
  testWidgets('payment form presents amount validation in Hindi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const strings = AppStrings('hi');
    await tester.pumpWidget(
      MaterialApp(
        theme: clearCounterTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        locale: const Locale('hi'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: ux01FixtureSurface('payment-validation', const Locale('hi')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '0');
    final button = find.text(strings.translate('Review payment'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    const error = 'Use an amount from ₹0.01 to ₹1,00,000.00.';
    expect(find.text(error), findsNothing);
    expect(find.text(strings.translate(error)), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(strings.translate(error)))
          .didExceedMaxLines,
      isFalse,
    );
  });
  testWidgets(
    'Hindi corrected history labels original entry without replacing its identity',
    (tester) async {
      const strings = AppStrings('hi');
      await tester.pumpWidget(
        MaterialApp(
          theme: clearCounterTheme(),
          locale: const Locale('hi'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: ux01FixtureSurface(
            'customer-history-corrected',
            const Locale('hi'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final disclosure = find.text(strings.translate('Details')).last;
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.textContaining('Original entry:'), findsNothing);
      expect(
        find.textContaining('${strings.translate('Original entry')}: credit'),
        findsOneWidget,
      );
    },
  );
  test('Hindi correction reason validation is translated', () {
    const source = 'Enter a reason of 1–240 characters.';
    expect(const AppStrings('hi').translate(source), isNot(source));
    const conflict =
        'Correction could not be saved. Refresh the ledger and review the original entry.';
    expect(const AppStrings('hi').translate(conflict), isNot(conflict));
    expect(
      const AppStrings('hi').translate('Original entry'),
      isNot('Original entry'),
    );
  });
  test('Hindi payment amount validation is translated', () {
    const source = 'Use an amount from ₹0.01 to ₹1,00,000.00.';
    expect(const AppStrings('hi').translate(source), isNot(source));
  });
  test('uncertain payment capture retains its original attempt', () async {
    final shop = OpaqueId.fromJson('shop'), link = OpaqueId.fromJson('link');
    final repo = CaptureCloudLedger(
      CaptureAuth(AccountRole.owner, 'payment-retry'),
      'payment-retry',
    );
    final original = await repo.beginPayment(
      shop,
      link,
      'Asha Patel',
      1245000,
      'cash',
    );
    expect(
      (await repo.pendingPayment(shop, link))?.attempt.operationId,
      original.operationId,
    );
  });
  test(
    'financial capture snapshots include the operation shown in the receipt',
    () async {
      final shop = OpaqueId.fromJson('shop'), link = OpaqueId.fromJson('link');
      final credit = CaptureLedger(
        CaptureAuth(AccountRole.owner, 'credit-pending'),
        'credit-pending',
      );
      final payment = CaptureLedger(
        CaptureAuth(AccountRole.owner, 'payment-pending'),
        'payment-pending',
      );
      expect((await credit.snapshot(shop, link))!.provisionalPaise, 2000000);
      await credit.begin(shop, link, 'Asha Patel', 1245000, null, null);
      expect((await credit.snapshot(shop, link))!.provisionalPaise, 3245000);
      await payment.beginPayment(shop, link, 'Asha Patel', 1245000, 'cash');
      expect((await payment.snapshot(shop, link))!.provisionalPaise, 755000);
    },
  );
}
