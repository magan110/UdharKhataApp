import 'dart:convert';

import '../auth/auth_repository.dart';
import '../db/sync_dao.dart';
import '../network/app_failure.dart';
import '../network/contracts.dart';
import 'operation.dart';
import 'sync_models.dart';

final class SyncPush {
  const SyncPush({
    required this.auth,
    required this.dao,
    required this.accountId,
  });
  final AuthRepository auth;
  final SyncDao dao;
  final OpaqueId accountId;
  void _guard() {
    if (auth.sessionGeneration != dao.generation ||
        dao.database.generation != dao.generation) {
      throw StateError('Sync session replaced');
    }
  }

  Future<void> send(String shopId, Map<String, Object?> outboxRow) async {
    _guard();
    late Map<String, Object?> body;
    try {
      body = jsonObject(jsonDecode(outboxRow['payload'] as String));
      final operation = LocalOperation(accountId.value, shopId, body);
      final credit = body['kind'] == 'credit',
          payment = body['kind'] == 'payment',
          correction = body['kind'] == 'correction';
      final keys = correction
          ? {
              'clientOperationId',
              'linkId',
              'kind',
              'correctsEntryId',
              'targetAmountPaise',
              'expectedRevision',
              'correctionReason',
              'occurredAtMs',
            }
          : credit
          ? {
              'clientOperationId',
              'linkId',
              'kind',
              'amountPaise',
              'note',
              'dueDate',
              'occurredAtMs',
            }
          : {
              'clientOperationId',
              'linkId',
              'kind',
              'amountPaise',
              'paymentMethod',
              'occurredAtMs',
            };
      if ((!credit && !payment && !correction) ||
          body.keys.any((key) => !keys.contains(key)) ||
          body['clientOperationId'] != outboxRow['operation_id'] ||
          body['linkId'] != outboxRow['link_id'] ||
          operation.payload != outboxRow['payload'] ||
          operation.hash != outboxRow['request_hash']) {
        throw const FormatException('Operation integrity');
      }
      final rows = await dao.database.transaction(
        accountId,
        (tx) => tx.rawQuery(
          'SELECT e.*,l.shop_id,l.owner_user_id,l.status AS link_status FROM cached_entries e JOIN cached_links l ON l.id=e.link_id WHERE e.client_operation_id=?',
          [body['clientOperationId']],
        ),
        expectedGeneration: dao.generation,
      );
      if (rows.length != 1) throw const FormatException('Missing command');
      if (correction) {
        final expected = body['expectedRevision'];
        final reason = body['correctionReason'];
        if (expected is! int ||
            expected < 0 ||
            reason is! String ||
            reason.trim().isEmpty ||
            reason.length > 240) {
          throw const FormatException('Invalid correction');
        }
        final history = await dao.database.transaction(
          accountId,
          (tx) => tx.query(
            'cached_entries',
            where: 'link_id=? AND sync_status=? AND (server_id=? OR corrects_entry_id=?)',
            whereArgs: [
              body['linkId'],
              'synced',
              body['correctsEntryId'],
              body['correctsEntryId'],
            ],
            orderBy: 'server_seq',
          ),
          expectedGeneration: dao.generation,
        );
        final originals = history
            .where((e) => e['server_id'] == body['correctsEntryId'])
            .toList();
        final prior = history
            .where(
              (e) =>
                  e['corrects_entry_id'] == body['correctsEntryId'] &&
                  (e['expected_revision'] as int) < expected,
            )
            .toList();
        if (originals.length != 1 ||
            !['credit', 'payment'].contains(originals.single['kind']) ||
            prior.length != expected) {
          throw const FormatException('Missing correction history');
        }
        final effective = prior.isEmpty
            ? originals.single['amount_paise'] as int
            : prior.last['target_amount_paise'] as int;
        final delta =
            (MoneyPaise.fromJson(body['targetAmountPaise']).value - effective) *
            (originals.single['kind'] == 'credit' ? 1 : -1);
        if (rows.single['effect_paise'] != delta) {
          throw const FormatException('Correction effect mismatch');
        }
      }
      final row = rows.single;
      final amount = MoneyPaise.fromJson(
        body[correction ? 'targetAmountPaise' : 'amountPaise'],
      ).value;
      if (row['shop_id'] != shopId ||
          row['owner_user_id'] != accountId.value ||
          row['link_status'] != 'active' ||
          row['sync_status'] != 'pending' ||
          row['kind'] != body['kind'] ||
          (correction
              ? row['target_amount_paise'] != amount ||
                    row['corrects_entry_id'] != body['correctsEntryId'] ||
                    row['expected_revision'] != body['expectedRevision'] ||
                    row['correction_reason'] != body['correctionReason'] ||
                    amount < 0
              : row['amount_paise'] != amount ||
                    amount < 1 ||
                    row['effect_paise'] != (credit ? amount : -amount)) ||
          row['note'] != body['note'] ||
          row['due_date'] != body['dueDate'] ||
          row['payment_method'] != body['paymentMethod'] ||
          row['occurred_at_ms'] != body['occurredAtMs']) {
        throw const FormatException('Stored command mismatch');
      }
    } on FormatException {
      throw const AppFailure('LOCAL_INTEGRITY_ERROR', 'sync.integrityError');
    }
    _guard();
    final response = await auth.cloudRequest(
      accountId,
      '/v1/shops/$shopId/entries',
      body: body,
    );
    _guard();
    try {
      final data = jsonObject(response), row = jsonObject(data['entry']);
      if (data['replayed'] is! bool) {
        throw const FormatException('Missing receipt marker');
      }
      final returned = row['clientOperationId'];
      if (returned != null && returned != body['clientOperationId']) {
        throw const FormatException('Operation mismatch');
      }
      final entry = SyncEntry.fromJson({
        ...row,
        'clientOperationId': body['clientOperationId'],
      });
      if (!entry.matchesBody(body) ||
          entry.shopId != shopId ||
          entry.ownerId != accountId.value) {
        throw const FormatException('Receipt mismatch');
      }
      await dao.acknowledge(shopId, body, entry);
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    } on StateError {
      _guard();
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
  }
}
