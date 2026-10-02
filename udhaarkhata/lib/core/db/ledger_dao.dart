import 'package:sqflite/sqflite.dart';

import '../network/contracts.dart';
import 'database.dart';

final class CachedOwnerLedger {
  const CachedOwnerLedger(
    this.link,
    this.entries,
    this.syncedPaise,
    this.pendingPaise,
    this.snapshotAtMs,
  );
  final Map<String, Object?> link;
  final List<Map<String, Object?>> entries;
  final int syncedPaise, pendingPaise, snapshotAtMs;
  int get provisionalPaise => syncedPaise + pendingPaise;
}

final class OwnerLedgerDao {
  const OwnerLedgerDao(this.database, this.accountId);
  final SqliteAccountDatabase database;
  final OpaqueId accountId;

  Future<void> cache(
    Map<String, Object?> link,
    List<Map<String, Object?>> entries,
    int balance,
    int version,
    int high,
    int snapshotAtMs,
  ) => database.transaction(accountId, (tx) async {
    final account = (await tx.query('local_account')).single;
    if (account['role'] != 'owner' ||
        account['last_verified_at_ms'] == null ||
        link['owner_user_id'] != accountId.value ||
        link['status'] != 'active') {
      throw StateError('Verified owner required');
    }
    var sum = 0, last = 0;
    final ids = <Object?>{};
    for (final entry in entries) {
      final seq = entry['server_seq'] as int;
      if (entry['link_id'] != link['id'] ||
          entry['sync_status'] != 'synced' ||
          seq <= last ||
          !ids.add(entry['server_id'])) {
        throw StateError('Invalid snapshot');
      }
      last = seq;
      sum += entry['effect_paise'] as int;
    }
    if (sum != balance || entries.length != version || last != high) {
      throw StateError('Snapshot does not reconcile');
    }
    final existingLink = await tx.query(
      'cached_links',
      where: 'id=?',
      whereArgs: [link['id']],
    );
    if (existingLink.isEmpty) {
      await tx.insert('cached_links', link);
    } else {
      for (final key in ['shop_id', 'customer_user_id', 'owner_user_id']) {
        if (existingLink.single[key] != link[key]) {
          throw StateError('Link identity changed');
        }
      }
      await tx.update(
        'cached_links',
        link,
        where: 'id=?',
        whereArgs: [link['id']],
      );
    }
    final old = await tx.query(
      'cached_entries',
      where: 'link_id=? AND sync_status=?',
      whereArgs: [link['id'], 'synced'],
      orderBy: 'server_seq',
    );
    if (old.length > entries.length) {
      throw StateError('Snapshot moved backwards');
    }
    for (var i = 0; i < old.length; i++) {
      for (final field in entries[i].entries) {
        if (field.key != 'local_id' && old[i][field.key] != field.value) {
          throw StateError('Server history changed');
        }
      }
    }
    for (final entry in entries.skip(old.length)) {
      await tx.insert('cached_entries', entry);
    }
    await tx.insert('owner_ledger_snapshots', {
      'link_id': link['id'],
      'balance_paise': balance,
      'ledger_version': version,
      'server_seq': high,
      'snapshot_at_ms': snapshotAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final totals = (await tx.query(
      'cached_balances',
      where: 'link_id=?',
      whereArgs: [link['id']],
    )).single;
    final provisional =
        (totals['synced_paise'] as int) + (totals['pending_paise'] as int);
    if (provisional < 0 || provisional > maxSafeInteger) {
      throw StateError('Provisional balance out of range');
    }
  });

  Future<CachedOwnerLedger?> snapshot(String shopId, String linkId) =>
      database.transaction(accountId, (tx) async {
        final account = (await tx.query('local_account')).single;
        if (account['role'] != 'owner' ||
            account['last_verified_at_ms'] == null) {
          throw StateError('Verified owner required');
        }
        final links = await tx.query(
          'cached_links',
          where: 'id=? AND shop_id=? AND owner_user_id=? AND status=?',
          whereArgs: [linkId, shopId, accountId.value, 'active'],
        );
        final snapshots = await tx.query(
          'owner_ledger_snapshots',
          where: 'link_id=?',
          whereArgs: [linkId],
        );
        if (links.isEmpty || snapshots.isEmpty) return null;
        final entries = await tx.rawQuery(
          "SELECT * FROM cached_entries WHERE link_id=? ORDER BY CASE WHEN sync_status='synced' THEN 0 ELSE 1 END, server_seq, rowid",
          [linkId],
        );
        final totals = (await tx.query(
          'cached_balances',
          where: 'link_id=?',
          whereArgs: [linkId],
        )).single;
        return CachedOwnerLedger(
          links.single,
          entries,
          totals['synced_paise'] as int,
          totals['pending_paise'] as int,
          snapshots.single['snapshot_at_ms'] as int,
        );
      });

  Future<List<Map<String, Object?>>> links() => database.transaction(
    accountId,
    (tx) => tx.rawQuery(
      "SELECT l.* FROM cached_links l JOIN owner_ledger_snapshots s ON s.link_id=l.id WHERE l.owner_user_id=? AND l.status='active' ORDER BY l.display_name,l.id",
      [accountId.value],
    ),
  );

  Future<void> deny(String shopId, String linkId) => database.transaction(
    accountId,
    (tx) => tx.update(
      'cached_links',
      {'status': 'access_removed'},
      where: 'id=? AND shop_id=? AND owner_user_id=?',
      whereArgs: [linkId, shopId, accountId.value],
    ),
  );
}
