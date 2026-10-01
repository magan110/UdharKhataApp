import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';
import 'package:udhaarkhata/features/qr/resolve_controller.dart';

import 'owner_link_test.dart' show LinkAuth, linkJson;
import 'auth_session_test.dart' show MemorySecureStorage;

void main() {
  final shop = OpaqueId.fromJson('shop'),
      owner = OpaqueId.fromJson('owner'),
      payload = 'udhaar://customer/v1/${'a' * 64}';
  test(
    'offline new lookup explicitly requires internet and makes no link request',
    () async {
      final auth = LinkAuth()..loseResponse = true,
          controller = ResolveController(
            CloudOwnerLinkRepository(auth, owner, MemorySecureStorage()),
            shop,
          );
      await controller.initialize();
      await controller.scan(payload);
      expect(controller.stage, ScanStage.failed);
      expect(
        (controller.error as AppFailure).messageKey,
        'link.internetNeeded',
      );
      expect(auth.requests.single['path'], '/v1/customer-qr/resolve');
      controller.dispose();
    },
  );
  test(
    'lost confirmation is recoverable under same ID and prevents a new scan',
    () async {
      final storage = MemorySecureStorage(),
          auth = LinkAuth()
            ..response = {
              'state': 'new',
              'customerDisplayName': 'Customer',
              'linkId': null,
            };
      final repo = CloudOwnerLinkRepository(auth, owner, storage),
          controller = ResolveController(repo, shop);
      await controller.initialize();
      await controller.scan(payload);
      expect(controller.stage, ScanStage.confirm);
      auth.loseResponse = true;
      await controller.confirm('Shop label');
      expect(controller.stage, ScanStage.recovery);
      final operation = controller.attempt!.operationId;
      controller.rescan();
      expect(controller.stage, ScanStage.recovery);
      controller.dispose();
      final restored = ResolveController(
        CloudOwnerLinkRepository(auth, owner, storage),
        shop,
      );
      await restored.initialize();
      expect(restored.stage, ScanStage.recovery);
      auth.loseResponse = false;
      auth.response = linkJson;
      await restored.confirm('ignored new name');
      expect(restored.stage, ScanStage.linked);
      final sent = auth.requests
          .where((r) => (r['path'] as String).endsWith('/customers'))
          .toList();
      expect(sent.length, 2);
      expect(sent[0]['body'], sent[1]['body']);
      expect((sent[1]['body'] as Map)['clientOperationId'], operation);
      restored.dispose();
    },
  );
  test(
    'returning customer opens authorized link without Add or POST',
    () async {
      final auth = ReturningLinkAuth();
      final controller = ResolveController(
        CloudOwnerLinkRepository(auth, owner, MemorySecureStorage()),
        shop,
      );
      await controller.initialize();
      await controller.scan(payload);
      expect(controller.stage, ScanStage.linked);
      expect(controller.link!.id.value, 'link');
      expect(auth.requests.map((r) => r['path']), [
        '/v1/customer-qr/resolve',
        '/v1/shops/shop/customers/link',
      ]);
      controller.dispose();
    },
  );
  test('disposed scanner ignores a delayed identity response after leaving or switching account', () async {
    final auth = DelayedLinkAuth(),
        controller = ResolveController(
          CloudOwnerLinkRepository(auth, owner, MemorySecureStorage()),
          shop,
        );
    await controller.initialize();
    final scan = controller.scan(payload);
    controller.dispose();
    auth.responseWait.complete({
      'state': 'new',
      'customerDisplayName': 'Old account customer',
      'linkId': null,
    });
    await scan;
    expect(controller.customer, null);
    expect(controller.stage, ScanStage.resolving);
  });
  test(
    'second confirmation tap while first is running makes one POST',
    () async {
      final auth = DelayedLinkAuth(),
          controller = ResolveController(
            CloudOwnerLinkRepository(auth, owner, MemorySecureStorage()),
            shop,
          );
      await controller.initialize();
      final scan = controller.scan(payload);
      auth.responseWait.complete({
        'state': 'new',
        'customerDisplayName': 'Customer',
        'linkId': null,
      });
      await scan;
      auth.responseWait = Completer<Object?>();
      final first = controller.confirm(null);
      await Future<void>.delayed(Duration.zero);
      await controller.confirm(null);
      expect(controller.stage, ScanStage.saving);
      expect(
        auth.requests
            .where((r) => (r['path'] as String).endsWith('/customers'))
            .length,
        1,
      );
      auth.responseWait.complete(linkJson);
      await first;
      expect(controller.stage, ScanStage.linked);
      controller.dispose();
    },
  );
}

class ReturningLinkAuth extends LinkAuth {
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add({'path': path, 'body': body});
    return path.endsWith('resolve')
        ? {
            'state': 'linked',
            'customerDisplayName': 'Customer',
            'linkId': 'link',
          }
        : linkJson;
  }
}

class DelayedLinkAuth extends LinkAuth {
  Completer<Object?> responseWait = Completer();
  @override
  Future<Object?> cloudRequest(
    OpaqueId account,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add({'path': path, 'body': body});
    return responseWait.future;
  }
}
