import 'package:sqflite/sqflite.dart';

import '../network/contracts.dart';
import '../network/app_failure.dart';
import '../sync/sync_models.dart';
import 'database.dart';
import 'repositories.dart';

final class SyncDao {
  const SyncDao(this.database, this.accountId, this.generation);
  final SqliteAccountDatabase database;
  final OpaqueId accountId;
  final int generation;
  Future<T> _tx<T>(Future<T> Function(Transaction) action) =>
      database.transaction(accountId, action, expectedGeneration: generation);
  Future<Map<String, Object?>> _link(
    Transaction tx,
    String shop,
    String link,
  ) async {
    final account = (await tx.query('local_account')).single;
    final rows = await tx.query(
      'cached_links',
      where: 'id=? AND shop_id=? AND owner_user_id=?',
      whereArgs: [link, shop, accountId.value],
    );
    if (account['role'] != 'owner' ||
        account['last_verified_at_ms'] == null ||
        rows.length != 1 ||
        rows.single['status'] != 'active') {
      throw StateError('Verified active owner scope required');
    }
    return rows.single;
  }

  Future<void> acknowledge(
    String shopId,
    Map<String, Object?> originalBody,
    SyncEntry entry,
  ) => _tx((tx) async {
    await _link(tx, shopId, entry.linkId);
    if (entry.shopId != shopId ||
        entry.ownerId != accountId.value ||
        !entry.matchesBody(originalBody)) {
      throw StateError('Receipt command mismatch');
    }
    final existing = await tx.query(
      'cached_entries',
      where: 'client_operation_id=?',
      whereArgs: [entry.operationId],
    );
    if (existing.length != 1) throw StateError('Original command required');
    await LocalLedgerStore.reconcile(tx, entry.linkId, [entry.row]);
    final count = Sqflite.firstIntValue(
      await tx.rawQuery(
        "SELECT COUNT(*) FROM cached_entries WHERE link_id=? AND sync_status='synced'",
        [entry.linkId],
      ),
    )!;
    if (count > 10000) {
      await tx.update(
        'owner_ledger_snapshots',
        {'sync_blocked_code': 'CACHE_TOO_LARGE'},
        where: 'link_id=?',
        whereArgs: [entry.linkId],
      );
    }
  });
  Future<void> applyPage(String shopId, String linkId, SyncPage page) =>
      _tx((tx) async {
        final old = await _link(tx, shopId, linkId);
        if (page.link['id'] != linkId ||
            page.link['shopId'] != shopId ||
            page.link['ownerUserId'] != accountId.value ||
            page.link['customerUserId'] != old['customer_user_id']) {
          throw StateError('Page link mismatch');
        }
        final cursors = await tx.query(
          'sync_cursors',
          where: 'scope=?',
          whereArgs: [linkId],
        );
        final before = cursors.isEmpty ? 0 : cursors.single['sequence'] as int;
        if (page.appliedThroughSeq < before ||
            page.items.any((e) => e.seq <= before) ||
            (page.items.isEmpty && page.appliedThroughSeq != before)) {
          throw StateError('Cursor moved incorrectly');
        }
        if (page.balance.ledgerVersion > 10000) {
          throw const AppFailure('CACHE_TOO_LARGE', 'ledger.cacheTooLarge');
        }
        await LocalLedgerStore.reconcile(
          tx,
          linkId,
          page.items.map((e) => e.row).toList(),
          minimumSequence: before,
        );
        await tx.update(
          'cached_links',
          {
            'display_name': page.link['displayName'],
            'nickname': page.link['nickname'],
            'linked_at_ms': page.link['linkedAtMs'],
            'last_verified_at_ms': page.snapshotAtMs,
          },
          where: 'id=?',
          whereArgs: [linkId],
        );
        if (!page.hasMore) {
          final totals = (await tx.rawQuery(
            "SELECT COALESCE(SUM(effect_paise),0) AS sum,COUNT(*) AS count,COALESCE(MAX(server_seq),0) AS seq FROM cached_entries WHERE link_id=? AND sync_status='synced' AND server_seq<=?",
            [linkId, page.highWaterSeq],
          )).single;
          if (totals['sum'] != page.balance.balancePaise ||
              totals['count'] != page.balance.ledgerVersion ||
              totals['seq'] != page.highWaterSeq) {
            throw StateError('Final snapshot does not reconcile');
          }
          await tx.insert('owner_ledger_snapshots', {
            'link_id': linkId,
            'balance_paise': page.balance.balancePaise,
            'ledger_version': page.balance.ledgerVersion,
            'server_seq': page.highWaterSeq,
            'snapshot_at_ms': page.snapshotAtMs,
            'partial_sync_at_ms': page.snapshotAtMs,
            'sync_blocked_code': null,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await tx.update(
            'owner_ledger_snapshots',
            {'partial_sync_at_ms': page.snapshotAtMs},
            where: 'link_id=?',
            whereArgs: [linkId],
          );
        }
        await tx.insert('sync_cursors', {
          'scope': linkId,
          'sequence': page.appliedThroughSeq,
          'last_sync_at_ms': page.snapshotAtMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
  Future<void> defer(
    String operationId,
    int attempts,
    DateTime retryAt,
    String code,
  ) => _tx((tx) async {
    await tx.update(
      'outbox',
      {
        'attempts': attempts,
        'retry_at_ms': retryAt.millisecondsSinceEpoch,
        'error_code': code,
      },
      where: 'operation_id=? AND state=?',
      whereArgs: [operationId, 'pending'],
    );
  });
  Future<void> _reject(Transaction tx, String operationId, String code) async {
    await tx.update(
      'cached_entries',
      {'sync_status': 'needs_attention'},
      where: 'client_operation_id=? AND sync_status=?',
      whereArgs: [operationId, 'pending'],
    );
    await tx.update(
      'outbox',
      {'state': 'needs_attention', 'error_code': code},
      where: 'operation_id=?',
      whereArgs: [operationId],
    );
  }

  Future<void> reject(String operationId, String code) =>
      _tx((tx) => _reject(tx, operationId, code));
  Future<void> denyLink(String shopId, String linkId, String code) =>
      _tx((tx) async {
        await _link(tx, shopId, linkId);
        await tx.update(
          'cached_links',
          {'status': 'access_removed'},
          where: 'id=?',
          whereArgs: [linkId],
        );
        final commands = await tx.query(
          'outbox',
          where: 'link_id=?',
          whereArgs: [linkId],
        );
        for (final command in commands) {
          await _reject(tx, command['operation_id'] as String, code);
        }
      });
}
