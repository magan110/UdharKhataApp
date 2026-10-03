import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/status_page.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/features/qr/scanner_page.dart';

void main() {
  testWidgets('session error and camera denial are reachable at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    Widget frame(Widget child) => MaterialApp(
      theme: clearCounterTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: child,
    );
    await tester.pumpWidget(
      frame(
        StatusPage(
          title: 'Could not open your account',
          message: 'Connect to the internet and check the same request. Your saved entries remain on this phone.',
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    await tester.pumpWidget(
      frame(
        Scaffold(
          body: ScannerCameraError(
            permissionDenied: true,
            restarting: false,
            onRetry: () => retries++,
            onSettings: () => retries++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Open settings'));
    await tester.tap(find.text('Open settings'));
    expect(retries, 2);
  });
}
