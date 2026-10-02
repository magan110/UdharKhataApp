import 'package:sqflite/sqflite.dart';

import '../network/contracts.dart';
import 'database.dart';

final class LocalLedgerStore {
  const LocalLedgerStore(this.database, this.accountId);
  final SqliteAccountDatabase database;
  final OpaqueId accountId;

  Future<void> savePending(
    Map<String, Object?> entry,
    String payload,
    String requestHash,
    int createdAtMs, {
    bool requireSnapshot = false,
    String? expectedShopId,
  }) => database.transaction(accountId, (tx) async {
    final account = (await tx.query('local_account')).single;
    final link = await tx.query(
      'cached_links',
      where: 'id=? AND owner_user_id=? AND status=?',
      whereArgs: [entry['link_id'], accountId.value, 'active'],
    );
    if (account['role'] != 'owner' || account['last_verified_at_ms'] == null) {
      throw StateError('Verified owner required');
    }
    if (link.isEmpty ||
        (expectedShopId != null && link.single['shop_id'] != expectedShopId)) {
      throw StateError('Verified active link required');
    }
    if (entry['sync_status'] != 'pending') {
      throw StateError('Pending entry required');
    }
    final existing = await tx.query(
      'cached_entries',
      where: 'client_operation_id=?',
      whereArgs: [entry['client_operation_id']],
    );
    if (existing.isNotEmpty) {
      final saved = await tx.query(
        'outbox',
        where: 'operation_id=?',
        whereArgs: [entry['client_operation_id']],
      );
      if (saved.length != 1 ||
          saved.single['payload'] != payload ||
          saved.single['request_hash'] != requestHash ||
          saved.single['created_at_ms'] != createdAtMs ||
          entry.entries.any(
            (field) => existing.single[field.key] != field.value,
          )) {
        throw StateError('Local operation identity reused');
      }
      return;
    }
    if (requireSnapshot) {
      final ready = await tx.query(
        'owner_ledger_snapshots',
        where: 'link_id=?',
        whereArgs: [entry['link_id']],
      );
      final blocked = await tx.query(
        'outbox',
        where: 'link_id=? AND state=?',
        whereArgs: [entry['link_id'], 'needs_attention'],
      );
      if (ready.length != 1 ||
          ready.single['sync_blocked_code'] != null ||
          blocked.isNotEmpty) {
        throw StateError('Verified complete ledger required');
      }
    }
    await tx.insert('cached_entries', entry);
    await tx.insert('outbox', {
      'operation_id': entry['client_operation_id'],
      'link_id': entry['link_id'],
      'payload': payload,
      'request_hash': requestHash,
      'created_at_ms': createdAtMs,
    });
    final totals = await _balance(tx, entry['link_id'] as String);
    final provisional =
        (totals['synced_paise'] as int) + (totals['pending_paise'] as int);
    if (provisional < 0 || provisional > maxSafeInteger) {
      throw StateError('Provisional balance out of range');
    }
  });

  Future<List<Map<String, Object?>>> entries(String linkId) =>
      database.transaction(accountId, (tx) async {
        final rows = await tx.query(
          'cached_entries',
          where: 'link_id=?',
          whereArgs: [linkId],
          orderBy: 'server_seq,local_id',
        );
        return rows
            .map(
              (row) =>
                  Map<String, Object?>.from(row)
                    ..removeWhere((key, value) => value == null),
            )
            .toList();
      });

  Future<Map<String, Object?>> _balance(Transaction tx, String linkId) async {
    final rows = await tx.query(
      'cached_balances',
      columns: ['synced_paise', 'pending_paise'],
      where: 'link_id=?',
      whereArgs: [linkId],
    );
    return rows.isEmpty ? {'synced_paise': 0, 'pending_paise': 0} : rows.single;
  }

  Future<Map<String, Object?>> balance(String linkId) =>
      database.transaction(accountId, (tx) => _balance(tx, linkId));

  Future<Map<String, Object?>?> cursor(String linkId) =>
      database.transaction(accountId, (tx) async {
        final rows = await tx.query(
          'sync_cursors',
          columns: ['sequence', 'last_sync_at_ms'],
          where: 'scope=?',
          whereArgs: [linkId],
        );
        return rows.isEmpty ? null : rows.single;
      });

  Future<void> applyPage(
    String linkId,
    List<Map<String, Object?>> entries,
    int sequence,
    int syncedAtMs,
  ) => database.transaction(accountId, (tx) async {
    final cursors = await tx.query(
      'sync_cursors',
      where: 'scope=?',
      whereArgs: [linkId],
    );
    final previous = cursors.isEmpty ? 0 : cursors.single['sequence'] as int;
    final last = await reconcile(
      tx,
      linkId,
      entries,
      minimumSequence: previous,
    );
    if (sequence < previous || sequence != last) {
      throw StateError('Cursor must match the last stored sequence');
    }
    await tx.insert('sync_cursors', {
      'scope': linkId,
      'sequence': sequence,
      'last_sync_at_ms': syncedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  static Future<int> reconcile(
    Transaction tx,
    String linkId,
    List<Map<String, Object?>> entries, {
    int minimumSequence = 0,
  }) async {
    var last = minimumSequence;
    var seen = false;
    for (final entry in entries) {
      if (entry['link_id'] != linkId || entry['sync_status'] != 'synced') {
        throw StateError('Page scope or status mismatch');
      }
      final serverSequence = entry['server_seq'];
      if (serverSequence is! int ||
          serverSequence < last ||
          (seen && serverSequence == last)) {
        throw StateError('Unordered page');
      }
      final serverId = entry['server_id'];
      if (serverId is! String || serverId.isEmpty) {
        throw StateError('Acknowledged server identity required');
      }
      last = serverSequence;
      seen = true;
      final operationId = entry['client_operation_id'];
      final existing = await tx.query(
        'cached_entries',
        where: operationId == null
            ? 'server_id=?'
            : 'client_operation_id=? OR server_id=?',
        whereArgs: operationId == null ? [serverId] : [operationId, serverId],
      );
      if (existing.length > 1) {
        throw StateError('Acknowledgment matches conflicting local records');
      }
      if (existing.isEmpty) {
        await tx.insert('cached_entries', entry);
      } else {
        final old = existing.single;
        for (final key in [
          'link_id',
          'kind',
          'amount_paise',
          'target_amount_paise',
          'effect_paise',
          'note',
          'payment_method',
          'due_date',
          'corrects_entry_id',
          'expected_revision',
          'correction_reason',
          'occurred_at_ms',
        ]) {
          if (entry[key] != old[key]) {
            throw StateError('Acknowledged command mismatch');
          }
        }
        for (final key in ['server_id', 'server_seq', 'created_at_ms']) {
          if (old[key] != null && entry[key] != old[key]) {
            throw StateError('Acknowledged server identity mismatch');
          }
        }
        if (operationId != null &&
            old['client_operation_id'] != null &&
            operationId != old['client_operation_id']) {
          throw StateError('Acknowledged operation identity mismatch');
        }
        await tx.update(
          'cached_entries',
          {
            'server_id': entry['server_id'],
            'server_seq': entry['server_seq'],
            'sync_status': 'synced',
            'created_at_ms': entry['created_at_ms'],
            if (old['client_operation_id'] == null && operationId != null)
              'client_operation_id': operationId,
          },
          where: 'local_id=?',
          whereArgs: [old['local_id']],
        );
      }
      if (operationId != null) {
        await tx.delete(
          'outbox',
          where: 'operation_id=?',
          whereArgs: [operationId],
        );
      }
    }
    return last;
  }
}
