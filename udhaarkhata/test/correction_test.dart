import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/db/repositories.dart';
import 'package:udhaarkhata/core/db/sync_dao.dart';
import 'package:udhaarkhata/core/sync/operation.dart';
import 'package:udhaarkhata/core/sync/save_local.dart';
import 'package:udhaarkhata/core/sync/sync_models.dart';

import 'helpers/sync_fixture.dart';

void main() {
  test('Canonical financial hash is order independent and account scoped', () {
    for (final kind in ['credit', 'payment', 'correction']) {
      final body = {...command(), 'kind': kind};
      final reversed = {
        for (final key in body.keys.toList().reversed) key: body[key],
      };
      expect(
        LocalOperation('owner', 'shop', body).hash,
        LocalOperation('owner', 'shop', reversed).hash,
      );
      expect(
        LocalOperation('other', 'shop', body).hash,
        isNot(LocalOperation('owner', 'shop', body).hash),
      );
    }
  });
  for (final kind in ['credit', 'payment']) {
    test(
      'Correction uses acknowledged effective $kind and retains original',
      () async {
        final fixture = SyncFixture();
        await fixture.open();
        try {
          final store = LocalLedgerStore(fixture.database, fixture.accountId);
          final original = {
            ...serverEntry(),
            'kind': kind,
            'paymentMethod': kind == 'payment' ? 'cash' : null,
            'effectPaise': kind == 'payment' ? -50000 : 50000,
          };
          // A preceding credit supports a nonnegative payment ledger.
          final rows = kind == 'payment'
              ? [
                  SyncEntry.fromJson({
                    ...serverEntry(
                      operation: '00000000-0000-4000-8000-000000000023',
                    ),
                    'id': 'support',
                  }).row,
                  SyncEntry.fromJson({...original, 'serverSeq': 2}).row,
                ]
              : [SyncEntry.fromJson(original).row];
          await store.applyPage('link', rows, kind == 'payment' ? 2 : 1, 2);
          final body = {
            'clientOperationId': operationB,
            'linkId': 'link',
            'kind': 'correction',
            'correctsEntryId': 'entry_1',
            'targetAmountPaise': 40000,
            'expectedRevision': 0,
            'correctionReason': 'Wrong amount',
            'occurredAtMs': 3,
          };
          await SaveLocal(store)('shop', body);
          await SaveLocal(store)(
            'shop',
            body,
          ); // identical save reuses durable command
          final saved = await store.entries('link');
          expect(
            saved.singleWhere((e) => e['kind'] == 'correction')['effect_paise'],
            kind == 'payment' ? 10000 : -10000,
          );
          expect(
            saved
                .where((e) => e['server_id'] == 'entry_1')
                .single['amount_paise'],
            50000,
          );
          expect(
            saved.singleWhere((e) => e['kind'] == 'correction')['sync_status'],
            'pending',
          );
          await expectLater(
            SaveLocal(store)('shop', {
              ...body,
              'clientOperationId': '00000000-0000-4000-8000-000000000024',
            }),
            throwsStateError,
          );
        } finally {
          await fixture.close();
        }
      },
    );
  }
  test('Wrong revision is rejected without writing outbox', () async {
    final fixture = SyncFixture();
    await fixture.open();
    try {
      final store = LocalLedgerStore(fixture.database, fixture.accountId);
      await store.applyPage(
        'link',
        [SyncEntry.fromJson(serverEntry()).row],
        1,
        2,
      );
      await expectLater(
        SaveLocal(store)('shop', {
          'clientOperationId': operationB,
          'linkId': 'link',
          'kind': 'correction',
          'correctsEntryId': 'entry_1',
          'targetAmountPaise': 0,
          'expectedRevision': 1,
          'correctionReason': 'Reset',
          'occurredAtMs': 3,
        }),
        throwsStateError,
      );
      expect(await store.entries('link'), hasLength(1));
    } finally {
      await fixture.close();
    }
  });
  test(
    'Server stale revision retains immutable command Needs attention',
    () async {
      final fixture = SyncFixture();
      await fixture.open();
      try {
        final store = LocalLedgerStore(fixture.database, fixture.accountId);
        await store.applyPage(
          'link',
          [SyncEntry.fromJson(serverEntry()).row],
          1,
          2,
        );
        final body = {
          'clientOperationId': operationB,
          'linkId': 'link',
          'kind': 'correction',
          'correctsEntryId': 'entry_1',
          'targetAmountPaise': 40000,
          'expectedRevision': 0,
          'correctionReason': 'Wrong amount',
          'occurredAtMs': 3,
        };
        await SaveLocal(store)('shop', body);
        await SyncDao(
          fixture.database,
          fixture.accountId,
          fixture.database.generation,
        ).reject(operationB, 'STALE_REVISION');
        final rows = await fixture.database.transaction(
          fixture.accountId,
          (tx) => tx.query(
            'outbox',
            where: 'operation_id=?',
            whereArgs: [operationB],
          ),
        );
        expect(rows.single['state'], 'needs_attention');
        expect(
          rows.single['payload'],
          LocalOperation('owner', 'shop', body).payload,
        );
        final entries = await store.entries('link');
        expect(
          entries.singleWhere((e) => e['kind'] == 'correction')['sync_status'],
          'needs_attention',
        );
        expect(
          entries.singleWhere((e) => e['kind'] == 'credit')['amount_paise'],
          50000,
        );
      } finally {
        await fixture.close();
      }
    },
  );
  test(
    'Second correction delta starts at acknowledged effective amount',
    () async {
      final fixture = SyncFixture();
      await fixture.open();
      try {
        final store = LocalLedgerStore(fixture.database, fixture.accountId);
        final correction = {
          ...serverEntry(operation: operationB, seq: 2),
          'kind': 'correction',
          'amountPaise': null,
          'targetAmountPaise': 40000,
          'effectPaise': -10000,
          'correctsEntryId': 'entry_1',
          'revision': 1,
          'correctionReason': 'First correction',
        };
        await store.applyPage(
          'link',
          [
            SyncEntry.fromJson(serverEntry()).row,
            SyncEntry.fromJson(correction).row,
          ],
          2,
          2,
        );
        await SaveLocal(store)('shop', {
          'clientOperationId': '00000000-0000-4000-8000-000000000024',
          'linkId': 'link',
          'kind': 'correction',
          'correctsEntryId': 'entry_1',
          'targetAmountPaise': 30000,
          'expectedRevision': 1,
          'correctionReason': 'Second correction',
          'occurredAtMs': 3,
        });
        final entries = await store.entries('link');
        expect(
          entries.singleWhere(
            (e) => e['sync_status'] == 'pending',
          )['effect_paise'],
          -10000,
        );
      } finally {
        await fixture.close();
      }
    },
  );
}
