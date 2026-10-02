import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:udhaarkhata/features/sharing/share_controller.dart';

void main() {
  test('Private export exists only during canceled share and orphan cleanup preserves recent files', () async {
    final temporary = await Directory.systemTemp.createTemp('statement_test_');
    try {
      final parent = Directory('${temporary.path}/statements');
      await parent.create();
      final stale = File('${parent.path}/stale');
      await stale.create();
      await stale.setLastModified(
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      final recent = Directory('${parent.path}/recent');
      await recent.create();
      String? path;
      final controller = ShareController(
        temporaryDirectory: () async => temporary,
        launch: (params) async {
          expect(await stale.exists(), isFalse);
          expect(await recent.exists(), isTrue);
          path = params.files!.single.path;
          expect(path, startsWith(parent.path));
          expect(await File(path!).readAsBytes(), [1, 2, 3]);
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      await controller.file(Uint8List.fromList([1, 2, 3]), 'pdf');
      expect(await File(path!).exists(), isFalse);
    } finally {
      await temporary.delete(recursive: true);
    }
  });
  test('Failed native share removes private export', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'statement_failure_',
    );
    String? path;
    try {
      final controller = ShareController(
        temporaryDirectory: () async => temporary,
        launch: (params) async {
          path = params.files!.single.path;
          throw StateError('Canceled platform');
        },
      );
      await expectLater(controller.file(Uint8List(2), 'csv'), throwsStateError);
      expect(await File(path!).exists(), isFalse);
    } finally {
      await temporary.delete(recursive: true);
    }
  });
  test(
    'Reminder share contains only explicitly supplied reviewed text',
    () async {
      var calls = 0;
      final controller = ShareController(
        launch: (params) async {
          calls++;
          expect(params.text, 'Edited reminder');
          expect(params.files, isNull);
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      expect(calls, 0);
      await controller.text('Edited reminder');
      expect(calls, 1);
    },
  );
  test('Account changes during private file preparation prevent native launch and clean files', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'statement_account_',
    );
    final ready = Completer<Directory>();
    var authorized = true, calls = 0;
    final controller = ShareController(
      temporaryDirectory: () => ready.future,
      canShare: () => authorized,
      launch: (params) async {
        calls++;
        return const ShareResult('', ShareResultStatus.dismissed);
      },
    );
    final preparing = controller.file(Uint8List.fromList([1, 2, 3]), 'pdf');
    authorized = false;
    ready.complete(temporary);
    await preparing;
    expect(calls, 0);
    expect(Directory('${temporary.path}/statements').listSync(), isEmpty);
    await controller.text('Old account reminder');
    expect(calls, 0);
    await temporary.delete(recursive: true);
  });
  test(
    'Account changes during PDF preparation also prevent native launch',
    () async {
      var authorized = true, calls = 0;
      final pdf = Completer<Uint8List>();
      final temporary = await Directory.systemTemp.createTemp(
        'statement_pdf_account_',
      );
      final controller = ShareController(
        temporaryDirectory: () async => temporary,
        canShare: () => authorized,
        launch: (params) async {
          calls++;
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      Future<void> prepareAndShare() async {
        await controller.file(await pdf.future, 'pdf');
      }

      final work = prepareAndShare();
      authorized = false;
      pdf.complete(Uint8List(2));
      await work;
      expect(calls, 0);
      expect(Directory('${temporary.path}/statements').listSync(), isEmpty);
      await temporary.delete(recursive: true);
    },
  );
}
