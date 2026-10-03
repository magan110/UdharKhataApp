import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';
import 'package:udhaarkhata/features/qr/owner_qr_model.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/app/app.dart';

import 'helpers/fake_auth_repository.dart';
import 'router_test.dart' show syntheticAccount;
import 'owner_link_test.dart' show LinkAuth, linkJson;
import 'auth_session_test.dart' show MemorySecureStorage;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/shop/owner_shell.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';

import 'shop_test.dart' show TestShopRepository;

class TestCamera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  bool denied = false;
  int starts = 0;
  Completer<void>? disposeWait;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
    );
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {
    await disposeWait?.future;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  void scan(String value) => captures.add(
    BarcodeCapture(
      barcodes: [Barcode(rawValue: value, format: BarcodeFormat.qrCode)],
    ),
  );
}

void main() {
  Future<void> open(
    WidgetTester tester,
    TestCamera camera,
    LinkAuth auth,
  ) async {
    MobileScannerPlatform.instance = camera;
    final repo = CloudOwnerLinkRepository(
      auth,
      OpaqueId.fromJson('owner'),
      MemorySecureStorage(),
    );
    final shop = TestShopRepository()
      ..shop = Shop(OpaqueId.fromJson('shop'), 'Store');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(() async => syntheticAccount(AccountRole.owner)),
          ),
          shopRepositoryProvider.overrideWithValue(shop),
          ownerLinkRepositoryProvider.overrideWithValue(repo),
          customerLinksProvider('shop')
              .overrideWith((_) async => const CustomerLinks([], false)),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'camera is requested on scan; identity must be confirmed before linking; list refreshes',
    (tester) async {
      final camera = TestCamera(), auth = LinkAuth();
      await open(tester, camera, auth);
      expect(camera.starts, 0);
      await tester.tap(find.text('Scan customer QR'));
      await tester.pumpAndSettle();
      expect(camera.starts, 1);
      auth.response = {
        'state': 'new',
        'customerDisplayName': 'Synthetic Customer',
        'linkId': null,
      };
      camera.scan('udhaar://customer/v1/${'a' * 64}');
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Customer'), findsOneWidget);
      expect(find.text('Add customer'), findsOneWidget);
      expect(
        auth.requests.where(
          (r) => (r['path'] as String).endsWith('/customers'),
        ),
        isEmpty,
      );
      auth.response = linkJson;
      await tester.tap(find.text('Add customer'));
      await tester.pumpAndSettle();
      expect(find.text('Customer ledger'), findsOneWidget);
      expect(find.text('Synthetic Customer'), findsOneWidget);
      expect(
        auth.requests
            .where(
              (r) =>
                  r['body'] != null &&
                  (r['path'] as String).endsWith('/customers'),
            )
            .length,
        1,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await camera.captures.close();
    },
  );
  testWidgets(
    'camera denied gives retry and settings; invalid QR never calls resolve',
    (tester) async {
      final camera = TestCamera()..denied = true, auth = LinkAuth();
      await open(tester, camera, auth);
      await tester.tap(find.text('Scan customer QR'));
      await tester.pumpAndSettle();
      expect(find.text('Camera permission needed'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      camera.denied = false;
      await tester.tap(find.text('Try camera again'));
      await tester.pumpAndSettle();
      camera.scan('https://evil.test');
      await tester.pumpAndSettle();
      expect(
        find.text('This is not a valid Udhaar Khata customer QR.'),
        findsOneWidget,
      );
      expect(auth.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await camera.captures.close();
    },
  );

  testWidgets(
    'camera retry waits for old native camera disposal before restarting',
    (tester) async {
      final camera = TestCamera()..denied = true, auth = LinkAuth();
      await open(tester, camera, auth);
      await tester.tap(find.text('Scan customer QR'));
      await tester.pumpAndSettle();
      camera.denied = false;
      camera.disposeWait = Completer<void>();
      await tester.tap(find.text('Try camera again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(camera.starts, 1);
      camera.disposeWait!.complete();
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await camera.captures.close();
    },
  );
  testWidgets(
    'rescan waits for the previous camera teardown across widget recreation',
    (tester) async {
      final camera = TestCamera(), auth = LinkAuth();
      await open(tester, camera, auth);
      await tester.tap(find.text('Scan customer QR'));
      await tester.pumpAndSettle();
      camera.disposeWait = Completer<void>();
      camera.scan('https://invalid.test');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan another QR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(camera.starts, 1);
      camera.disposeWait!.complete();
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await camera.captures.close();
    },
  );
  testWidgets('owner can start customer scan only after opening their shop', (
    tester,
  ) async {
    final shop = TestShopRepository()
      ..shop = Shop(OpaqueId.fromJson('shop'), 'Store');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopRepositoryProvider.overrideWithValue(shop)],
        child: const MaterialApp(home: OwnerShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scan customer QR'), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Customers')), findsOneWidget);
  });
}
