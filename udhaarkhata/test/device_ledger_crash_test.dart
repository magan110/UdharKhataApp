import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/ledger_dao.dart';
import 'package:udhaarkhata/core/db/outbox_dao.dart';
import 'package:udhaarkhata/core/network/contracts.dart';

void main() {
  test(
    'committed local command survives SIGKILL of the saving process',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'udhaar_d11_crash_',
      );
      final executable = Platform.resolvedExecutable;
      final root =
          Platform.environment['FLUTTER_ROOT'] ??
          executable.split('/bin/cache/').first;
      final process = await Process.start('$root/bin/flutter', [
        'test',
        '--no-pub',
        '--reporter=expanded',
        '--dart-define=D11_CRASH_DIRECTORY=${directory.path}',
        'test/helpers/local_crash_probe.dart',
      ]);
      final committed = Completer<int>();
      final output = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final match = RegExp(r'D11_COMMITTED_PID=(\d+)').firstMatch(line);
            if (match != null && !committed.isCompleted) {
              committed.complete(int.parse(match[1]!));
            }
          });
      final errors = process.stderr.drain<void>();
      final account = OpaqueId.fromJson('crash_owner');
      final database = SqliteAccountDatabase(
        factory: databaseFactoryFfi,
        directory: directory.path,
      );
      try {
        final appPid = await committed.future.timeout(
          const Duration(seconds: 45),
        );
        expect(Process.killPid(appPid, ProcessSignal.sigkill), isTrue);
        expect(
          await process.exitCode.timeout(const Duration(seconds: 15)),
          isNot(0),
        );
        await database.openForAccount(account);
        final queue = await OutboxDao(database, account).entries();
        expect(queue, hasLength(1));
        expect(
          queue.single['operation_id'],
          '00000000-0000-4000-8000-000000000001',
        );
        expect(jsonDecode(queue.single['payload'] as String), {
          'clientOperationId': '00000000-0000-4000-8000-000000000001',
          'linkId': 'link',
          'kind': 'credit',
          'amountPaise': 50000,
          'note': null,
          'dueDate': null,
          'occurredAtMs': 1,
        });
        final snapshot = (await OwnerLedgerDao(
          database,
          account,
        ).snapshot('shop', 'link'))!;
        expect(snapshot.provisionalPaise, 50000);
        expect(snapshot.entries.single['sync_status'], 'pending');
        expect(
          await database.transaction(
            account,
            (tx) => tx.rawQuery('PRAGMA foreign_key_check'),
          ),
          isEmpty,
        );
      } finally {
        process.kill();
        await output.cancel();
        await errors;
        await database.lock();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 75)),
  );
}
