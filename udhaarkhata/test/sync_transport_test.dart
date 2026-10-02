import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/db/cursor_dao.dart';
import 'package:udhaarkhata/core/db/outbox_dao.dart';
import 'package:udhaarkhata/core/db/sync_dao.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/sync/push.dart';
import 'package:udhaarkhata/core/sync/pull.dart';

import 'helpers/sync_fixture.dart';

void main() {
  late SyncFixture f;
  late SyncPush push;
  late SyncPull pull;
  setUp(() async {
    f = SyncFixture();
    await f.open();
    final dao = SyncDao(f.database, f.accountId, f.database.generation);
    push = SyncPush(auth: f.auth, dao: dao, accountId: f.accountId);
    pull = SyncPull(
      auth: f.auth,
      dao: dao,
      cursors: CursorDao(f.database, f.accountId, f.database.generation),
      accountId: f.accountId,
    );
  });
  tearDown(() async {
    await f.close();
  });
  test('lostResponseRetainsOriginalOperation', () async {
    await f.queue();
    final row = (await OutboxDao(f.database, f.accountId).entries()).single;
    f.auth.handler = (path, body) async {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    };
    await expectLater(push.send('shop', row), throwsA(isA<AppFailure>()));
    f.auth.handler = (path, body) async => {
      'entry': serverEntry()..remove('clientOperationId'),
      'replayed': true,
    };
    await push.send('shop', row);
    expect(f.auth.requests.map((r) => r.body).toList(), [command(), command()]);
    expect(await OutboxDao(f.database, f.accountId).entries(), isEmpty);
  });
  test('receiptMismatchNotAcknowledged', () async {
    await f.queue();
    f.auth.handler = (path, body) async => {
      'entry': serverEntry(amount: 1),
      'replayed': false,
    };
    await expectLater(
      push.send(
        'shop',
        (await OutboxDao(f.database, f.accountId).entries()).single,
      ),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
    expect(await OutboxDao(f.database, f.accountId).entries(), hasLength(1));
  });
  test('pullResolvesPendingOperation', () async {
    await f.queue();
    f.auth.handler = (path, body) async => feed();
    await pull.page('shop', 'link');
    expect(await OutboxDao(f.database, f.accountId).entries(), isEmpty);
    expect(
      await CursorDao(
        f.database,
        f.accountId,
        f.database.generation,
      ).sequence('link'),
      1,
    );
  });
  test('expiredCursorRestartsAtDurableSequence', () async {
    f.auth.handler = (path, body) async {
      if (path.contains('cursor=')) {
        throw const AppFailure('CURSOR_INVALID', 'api.cursorInvalid');
      }
      return feed();
    };
    await expectLater(
      pull.page('shop', 'link', cursor: 'expired'),
      throwsA(isA<AppFailure>()),
    );
    await pull.page('shop', 'link');
    expect(f.auth.requests.last.path, contains('afterSeq=0'));
  });
  test('localIntegrityFailureNeverPosts', () async {
    await f.queue();
    final row = Map<String, Object?>.from(
      (await OutboxDao(f.database, f.accountId).entries()).single,
    )..['request_hash'] = 'b' * 64;
    await expectLater(
      push.send('shop', row),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.code,
          'code',
          'LOCAL_INTEGRITY_ERROR',
        ),
      ),
    );
    expect(f.auth.requests, isEmpty);
  });
  test('legacyRecoveryIsNeverSubmitted', () async {
    // These adapters see only SQLite outbox commands; no secure-storage recovery source.
    f.auth.handler = (path, body) async =>
        feed(items: [], balance: 0, version: 0, high: 0, through: 0);
    await pull.page('shop', 'link');
    expect(f.auth.requests.every((r) => r.body == null), isTrue);
    expect(await OutboxDao(f.database, f.accountId).entries(), isEmpty);
  });
}
