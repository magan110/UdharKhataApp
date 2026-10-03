// Opt-in renderer evidence: actual production pages, synthetic providers only.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/app/app_strings.dart';

import '../helpers/ux01_fixtures.dart';

void main() {
  const enabled = bool.fromEnvironment('UX01_CAPTURE');
  if (!enabled) return;
  final scenarios = <String>[
    'welcome',
    'entry-detail-corrected',
    'customer-history-corrected',
    'shop-setup-creating',
    'shop-setup-error',
    'owner-customers-paged',
    'owner-customers-paged-more',
    'owner-workspace-partial',
    'owner-workspace-negative',
    'owner-workspace-attention',
    'owner-workspace-denied',
    'customer-history-denied',
    'disputes-context-matched',
    'disputes-context-missing',
    'statement-reconcile',
    'statement-share-controls',
    'statement-bounds',
    'settings-shop-delete-modal',
    'settings-request-submit',
    'correction-conflict',

    'welcome-customer',
    'welcome-signing',
    'welcome-cancel',
    'welcome-error',
    'session-reauth',
    'session-unavailable',
    'welcome-configuration',
    'session-loading',
    'session-error',
    'shop-setup',
    'shop-setup-validation',
    'shop-setup-long',
    'owner-home',
    'owner-home-error',
    'owner-home-empty',
    'owner-home-offline',
    'owner-home-attention',
    'owner-home-loading',
    'owner-customers',
    'owner-customers-empty',
    'owner-customers-error-saved',
    'owner-more',
    'owner-workspace',
    'owner-workspace-error',
    'owner-workspace-loading',
    'owner-history-confirmed',
    'owner-history-confirmed-empty',
    'owner-history-confirmed-error',
    'owner-history-confirmed-paged',
    'owner-history-confirmed-paged-more',
    'owner-history-local',
    'owner-history-local-attention',
    'owner-history-local-partial',
    'owner-history-local-negative',
    'owner-history-details',
    'credit',
    'credit-validation',
    'credit-loading',
    'credit-error',
    'credit-review',
    'credit-pending',
    'credit-ack',
    'credit-saving',
    'credit-retry',
    'credit-restart',
    'credit-datepicker',
    'payment',
    'payment-validation',
    'payment-upi',
    'payment-overpayment',
    'payment-review',
    'payment-pending',
    'payment-ack',
    'payment-saving',
    'payment-retry',
    'payment-restart',
    'payment-rejected',
    'correction',
    'correction-validation',
    'correction-zero',
    'entry-detail',
    'correction-review',
    'correction-pending',
    'scanner-denied',
    'scanner-error',
    'link',
    'link-recovery',
    'link-saving',
    'link-error',
    'customer-qr',
    'customer-qr-rotate-modal',
    'customer-qr-cached',
    'customer-qr-uncertain',
    'customer-qr-signin',
    'customer-qr-rotation-error',
    'customer-shops',
    'customer-shops-empty',
    'customer-shops-error',
    'customer-shops-cached',
    'customer-shops-paged',
    'customer-shops-paged-more',
    'customer-more',
    'customer-history',
    'customer-history-remove-modal',
    'customer-history-error',
    'customer-history-offline',
    'customer-history-details',
    'disputes',
    'disputes-resolve-modal',
    'disputes-empty',
    'disputes-resolved',
    'disputes-customer',
    'disputes-cached',
    'statement',
    'statement-preview',
    'statement-datepicker',
    'statement-error',
    'statement-loading',
    'settings',
    'settings-delete-modal',
    'settings-requests',
    'settings-requests-latest100',
    'settings-language',
    'settings-copy-modal',
    'help',
    'sync-attention',
    'sync-running',
    'sync-network',
    'sync-rate',
    'sync-capacity',
    'sync-access',
    'sync-auth',
    'sync-service',
    'signout',
    'signout-modal',
    'signout-error',
  ];
  setUpAll(() async {
    final loader = FontLoader('CaptureSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    Directory('../docs/verification/ux01-captures/redesign')
        .createSync(recursive: true);
  });
  for (final scenario in scenarios) {
    for (final variant in [
      'en',
      'hi',
      if ([
        'owner-home',
        'owner-customers',
        'owner-customers-empty',
        'owner-customers-error-saved',
        'owner-more',
        'credit-review',
        'payment-review',
        'credit-validation',
        'payment-validation',
        'correction-review',
        'customer-qr',
        'customer-shops',
        'settings-delete-modal',
        'signout-modal',
        'disputes-resolve-modal',
        'help',
      ].contains(scenario))
        'hi-large',
      if ([
        'owner-home',
        'credit-review',
        'payment-review',
        'customer-qr',
      ].contains(scenario))
        'en-landscape',
    ]) {
      final lang = variant.startsWith('hi') ? 'hi' : 'en';
      testWidgets('renderer $scenario $variant', (tester) async {
        tester.view.physicalSize = variant.endsWith('large')
            ? const Size(320, 844)
            : variant.endsWith('landscape')
            ? const Size(844, 390)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final locale = Locale(lang);
        final theme = clearCounterTheme();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  variant.endsWith('large') ? 2 : 1,
                ),
              ),
              child: child!,
            ),
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('hi')],
            localizationsDelegates: [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'CaptureSans'),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontFamily: 'CaptureSans',
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: theme.filledButtonTheme.style?.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    theme.textTheme.labelLarge!.copyWith(
                      fontFamily: 'CaptureSans',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            home: ux01FixtureSurface(scenario, locale),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        if (!scenario.contains('loading')) await tester.pumpAndSettle();
        final strings = AppStrings(lang);
        Future<void> tapLabel(String text) async {
          final finder = find.text(strings.translate(text)).last;
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        if (scenario.startsWith('credit-') &&
            ![
              'credit-validation',
              'credit-loading',
              'credit-error',
            ].contains(scenario) &&
            scenario != 'credit-datepicker' &&
            !scenario.contains('restart') &&
            ![
              'payment-validation',
              'payment-upi',
              'payment-overpayment',
            ].contains(scenario)) {
          await tester.enterText(find.byType(TextFormField).first, '12450.00');
          await tapLabel('Review credit');
          if (['pending', 'ack', 'saving', 'retry'].any(scenario.endsWith)) {
            await tapLabel('Confirm credit');
          }
        }
        if ([
          'welcome-signing',
          'welcome-cancel',
          'welcome-error',
        ].contains(scenario)) {
          await tapLabel('Continue with Google');
          expect(
            find.text(
              strings.translate(
                scenario == 'welcome-signing'
                    ? 'Opening your account'
                    : 'Could not open your account',
              ),
            ),
            findsOneWidget,
          );
        }
        if (scenario == 'welcome-customer') await tapLabel('Customer');
        if (scenario == 'shop-setup-validation') await tapLabel('Create shop');
        if (scenario == 'shop-setup-creating' ||
            scenario == 'shop-setup-error') {
          await tester.enterText(
            find.byType(TextFormField).first,
            'Kiran Store',
          );
          await tapLabel('Create shop');
          expect(find.byType(TextFormField), findsOneWidget);
          if (scenario.endsWith('creating')) {
            expect(
              tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
              false,
            );
          } else {
            expect(
              find.textContaining(strings.text('api.networkError')),
              findsWidgets,
            );
          }
        }
        if (scenario == 'shop-setup-long') {
          await tester.enterText(
            find.byType(TextField).first,
            'Kiran Family General Store and Grocery Counter',
          );
          await tester.pumpAndSettle();
        }
        if (scenario == 'credit-validation') {
          await tester.enterText(find.byType(TextFormField).first, '0');
          await tapLabel('Review credit');
        }
        if (scenario == 'payment-validation' ||
            scenario == 'payment-overpayment') {
          await tester.enterText(
            find.byType(TextFormField).first,
            scenario.endsWith('overpayment') ? '30000' : '0',
          );
          await tapLabel('Review payment');
        }
        if (scenario == 'payment-overpayment') {
          await tapLabel('Confirm payment received');
          expect(
            find.text(strings.text('payment.balanceConflict')),
            findsOneWidget,
          );
        }
        if (scenario == 'payment-upi') {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.translate('UPI')).last);
          await tester.pumpAndSettle();
        }
        if (scenario == 'correction-validation' ||
            scenario == 'correction-zero') {
          await tester.enterText(find.byType(TextField).first, '0');
          if (scenario.endsWith('zero')) {
            await tester.enterText(
              find.byType(TextField).last,
              'Correct entry recorded twice',
            );
          }
          await tapLabel('Review correction');
        }
        if (scenario == 'credit-datepicker') {
          await tester.ensureVisible(find.byType(TextFormField).last);
          await tester.tap(find.byType(TextFormField).last);
          await tester.pumpAndSettle();
        }
        if (scenario.startsWith('payment-') &&
            !scenario.contains('rejected') &&
            !scenario.contains('restart') &&
            ![
              'payment-validation',
              'payment-upi',
              'payment-overpayment',
            ].contains(scenario)) {
          await tester.enterText(find.byType(TextFormField).first, '12450.00');
          await tapLabel('Review payment');
          if (['pending', 'ack', 'saving', 'retry'].any(scenario.endsWith)) {
            await tapLabel('Confirm payment received');
          }
        }
        if (scenario == 'correction-review' ||
            scenario == 'correction-pending' ||
            scenario == 'correction-conflict') {
          await tester.enterText(
            find.byType(TextField).last,
            'Checked customer record',
          );
          await tester.enterText(find.byType(TextField).first, '450.00');
          await tapLabel('Review correction');
          if (scenario.endsWith('pending') || scenario.endsWith('conflict')) {
            await tapLabel('Confirm correction');
          }
        }
        if (scenario == 'statement-bounds') {
          await tester.tap(find.byType(OutlinedButton).first);
          await tester.pumpAndSettle();
          final material = MaterialLocalizations.of(
            tester.element(find.byType(DatePickerDialog)),
          );
          await tester.tap(find.byTooltip(material.inputDateModeButtonLabel));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextField),
            ),
            material.formatCompactDate(DateTime(2025, 1, 1)),
          );
          await tester.tap(find.text(material.okButtonLabel));
          await tester.pumpAndSettle();
          await tapLabel('Prepare preview');
          await tester.pumpAndSettle();
          expect(find.text(strings.text('statement.sharePdf')), findsNothing);
          expect(find.textContaining('2025-01-01'), findsOneWidget);
        }
        if ([
          'statement-preview',
          'statement-error',
          'statement-loading',
          'statement-reconcile',
          'statement-share-controls',
        ].contains(scenario)) {
          final button = find.text(strings.text('statement.load'));
          await tester.tap(button);
          if (scenario != 'statement-loading') {
            await tester.pumpAndSettle();
          } else {
            await tester.pump();
          }
          if (scenario == 'statement-preview') {
            expect(
              find.textContaining(strings.text('statement.sensitive')),
              findsWidgets,
            );
          }
        }
        if (scenario == 'statement-preview') {
          expect(
            find.text('${strings.translate('Shop')}: Store'),
            findsOneWidget,
          );
          expect(find.textContaining('Shop nickname'), findsNothing);
          expect(
            find.text(
              '${strings.translate('Server snapshot')}: 03-10-2026 00:00',
            ),
            findsOneWidget,
          );
        }
        if (scenario == 'disputes-context-matched') {
          expect(find.textContaining('₹500.00'), findsWidgets);
        }
        if (scenario == 'disputes-context-missing') {
          expect(find.textContaining('₹500.00'), findsNothing);
        }
        if (scenario == 'owner-customers-paged') {
          expect(find.text(strings.translate('Load more')), findsOneWidget);
        }
        if (scenario == 'statement-reconcile') {
          expect(find.text(strings.text('statement.sharePdf')), findsNothing);
        }
        if (scenario == 'statement-share-controls') {
          final pdf = find.text(strings.text('statement.sharePdf'));
          await tester.ensureVisible(pdf);
          expect(find.text(strings.text('statement.shareCsv')), findsOneWidget);
          expect(find.text(strings.text('reminder.share')), findsOneWidget);
        }
        if (scenario == 'statement-datepicker') {
          await tester.tap(find.byType(OutlinedButton).first);
          await tester.pumpAndSettle();
          expect(find.byType(DatePickerDialog), findsOneWidget);
        }
        if (scenario.endsWith('paged-more')) await tapLabel('Load more');
        if (scenario == 'owner-customers-paged-more') {
          expect(find.text('Second page customer'), findsWidgets);
        }
        if (scenario == 'settings-language') {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
        }
        if (scenario == 'customer-history-details' ||
            scenario == 'customer-history-corrected') {
          await tapLabel('Details');
        }
        if (scenario == 'customer-history-corrected') {
          final reason = find.textContaining('Checked original receipt');
          await tester.ensureVisible(reason);
          expect(reason, findsOneWidget);
          expect(find.textContaining('credit'), findsWidgets);
        }
        if (scenario == 'session-unavailable') {
          expect(
            find.text(strings.translate('Page unavailable')),
            findsOneWidget,
          );
        }
        if (scenario == 'customer-qr-signin') await tapLabel('Refresh QR');
        if (scenario == 'customer-qr-rotation-error') {
          await tapLabel('Replace QR');
          await tapLabel('Replace');
        }
        if (scenario == 'signout-error') {
          await tapLabel('Sign out');
          await tapLabel('Sign out');
        }
        if (scenario == 'customer-history-remove-modal') {
          await tapLabel('Remove my access to this shop');
        }
        if (scenario == 'owner-history-details') await tapLabel('Details');
        if (scenario == 'customer-qr-rotate-modal') {
          await tapLabel('Replace QR');
        }
        if (scenario == 'settings-shop-delete-modal') {
          await tapLabel('Request shop deletion');
          expect(find.byType(AlertDialog), findsOneWidget);
        }
        if (scenario == 'settings-request-submit') {
          await tapLabel('Request shop data export');
          await tapLabel('Submit request');
          await tester.pumpAndSettle();
          expect(
            find.textContaining(strings.translate('Submitted')),
            findsWidgets,
          );
        }
        if (scenario == 'settings-delete-modal') {
          await tapLabel('Request account deletion');
        }
        if (scenario == 'settings-copy-modal') {
          await tapLabel('Export device-only requests');
        }
        if (scenario == 'signout-modal') await tapLabel('Sign out');
        if (scenario == 'disputes-resolve-modal') await tapLabel('Resolve');
        if (scenario == 'customer-qr') {
          expect(
            find.text(strings.translate('QR checked online.')),
            findsOneWidget,
          );
        }
        if (scenario == 'disputes') {
          expect(find.text('Please check this credit amount.'), findsOneWidget);
        }
        if (scenario == 'disputes-empty') {
          expect(
            find.text(strings.translate('No disputes yet.')),
            findsOneWidget,
          );
        }
        if (scenario == 'disputes-resolved') {
          expect(
            find.textContaining('Correction recorded separately.'),
            findsOneWidget,
          );
        }
        if (scenario.endsWith('pending') &&
            !scenario.startsWith('correction')) {
          expect(
            find.textContaining(
              strings.translate(
                scenario.startsWith('credit')
                    ? 'Credit saved · Pending'
                    : 'Payment saved · Pending',
              ),
            ),
            findsWidgets,
          );
        }
        await tester.pump();
        if (scenario == 'shop-setup-long') {
          expect(
            find.text('Kiran Family General Store and Grocery Counter'),
            findsOneWidget,
          );
        }
        if (scenario == 'payment-retry') {
          expect(
            find.text(strings.translate('Check same payment')),
            findsOneWidget,
          );
        }
        if (scenario == 'disputes-cached') {
          expect(find.text(strings.translate('Resolve')), findsNothing);
        }
        expect(tester.takeException(), isNull, reason: scenario);
        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFile(
            '../../../docs/verification/ux01-captures/redesign/$scenario-$variant.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
