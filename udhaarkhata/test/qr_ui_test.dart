import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:udhaarkhata/features/qr/customer_qr_page.dart';
import 'package:udhaarkhata/features/qr/scanner_page.dart';
import 'package:udhaarkhata/features/qr/qr_repository.dart';
import 'package:udhaarkhata/features/qr/qr_model.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';

class FakeQr implements QrRepository {
  final record = QrRecord(
    CustomerQr.fromJson({
      'version': 1,
      'publicQrId': 'a' * 64,
      'payload': 'udhaar://customer/v1/${'a' * 64}',
    }),
    1,
  );
  int rotations = 0;
  bool cacheFails = false;
  @override
  Future<QrRecord?> cached() async {
    if (cacheFails) throw PlatformException(code: 'SYNTHETIC_STORAGE_FAILURE');
    return record;
  }

  @override
  Future<QrRecord> current() async =>
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
  @override
  Future<QrRecord> rotate() async {
    rotations++;
    return QrRecord(
      record.qr,
      record.checkedAtMs,
      noticeKey: 'api.rateLimited',
    );
  }
}

void main() {
  testWidgets(
    'Hindi customer QR and rotation remain usable at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final repo = FakeQr();
      const strings = AppStrings('hi');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [qrRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            locale: const Locale('hi'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(body: CustomerQrPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        strings.translate('Show this to the shopkeeper'),
        isNot('Show this to the shopkeeper'),
      );
      expect(
        find.text(strings.translate('Show this to the shopkeeper')),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsOneWidget);
      const cachedWarning =
          'Saved QR — not checked online. It may have changed on another phone.';
      expect(strings.translate(cachedWarning), isNot(cachedWarning));
      expect(find.text(strings.translate(cachedWarning)), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          strings.translate(
            'Customer identification QR. Show this to the shopkeeper. It does not authorize a payment.',
          ),
        ),
        findsOneWidget,
      );
      final replace = find.text(strings.translate('Replace QR'));
      await tester.ensureVisible(replace);
      await tester.tap(replace);
      await tester.pumpAndSettle();
      expect(find.text(strings.translate('Replace your QR?')), findsOneWidget);
      expect(repo.rotations, 0);
      await tester.ensureVisible(find.text(strings.translate('Cancel')));
      await tester.tap(find.text(strings.translate('Cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
  for (final denied in [true, false]) {
    testWidgets(
      'Hindi camera failure $denied gives usable settings and retry at 200 percent',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        var retries = 0, settings = 0;
        const strings = AppStrings('hi');
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('hi'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: ScannerCameraError(
                  permissionDenied: denied,
                  restarting: false,
                  onRetry: () => retries++,
                  onSettings: () => settings++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final englishTitle = denied
            ? 'Camera permission needed'
            : 'Camera unavailable';
        expect(strings.translate(englishTitle), isNot(englishTitle));
        expect(
          find.bySemanticsLabel(strings.translate(englishTitle)),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.text(strings.translate('Try camera again')),
        );
        await tester.tap(find.text(strings.translate('Try camera again')));
        await tester.ensureVisible(
          find.text(strings.translate('Open settings')),
        );
        await tester.tap(find.text(strings.translate('Open settings')));
        expect(retries, 1);
        expect(settings, 1);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
  testWidgets('cache fallback failure leaves an error with enabled recovery', (
    tester,
  ) async {
    final repo = FakeQr();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [qrRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: CustomerQrPage())),
      ),
    );
    await tester.pumpAndSettle();
    repo.cacheFails = true;
    await tester.ensureVisible(find.text('Refresh QR'));
    await tester.tap(find.text('Refresh QR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Refresh QR'))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'saved QR renders offline; rotation requires confirmation and failure has recovery',
    (tester) async {
      final repo = FakeQr();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [qrRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: CustomerQrPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Saved QR'), findsOneWidget);
      await tester.ensureVisible(find.text('Replace QR'));
      await tester.tap(find.text('Replace QR'));
      await tester.pumpAndSettle();
      expect(repo.rotations, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.rotations, 0);
      await tester.ensureVisible(find.text('Replace QR'));
      await tester.tap(find.text('Replace QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();
      expect(repo.rotations, 1);
      expect(find.textContaining('QR replacement failed.'), findsOneWidget);
      await tester.ensureVisible(find.text('Refresh QR'));
      await tester.tap(find.text('Refresh QR'));
      await tester.pumpAndSettle();
      expect(
        find.byType(QrImageView),
        findsOneWidget,
      ); // Network failure must keep a safe cache visible.
      expect(find.textContaining('Saved QR'), findsOneWidget);
    },
  );
}
