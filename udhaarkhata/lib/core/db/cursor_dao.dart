import '../network/contracts.dart';
import 'database.dart';

final class CursorDao {
  const CursorDao(this.database, this.accountId, this.generation);
  final SqliteAccountDatabase database;
  final OpaqueId accountId;
  final int generation;
  Future<int> sequence(String linkId) =>
      database.transaction(accountId, (tx) async {
        final rows = await tx.query(
          'sync_cursors',
          where: 'scope=?',
          whereArgs: [linkId],
        );
        return rows.isEmpty ? 0 : rows.single['sequence'] as int;
      }, expectedGeneration: generation);
}
