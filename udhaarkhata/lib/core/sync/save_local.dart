import '../db/repositories.dart';
import 'operation.dart';

final class SaveLocal {
  const SaveLocal(this.store);
  final LocalLedgerStore store;

  Future<void> call(String shopId, Map<String, Object?> body) async {
    final operation = LocalOperation(store.accountId.value, shopId, body);
    final payment = body['kind'] == 'payment';
    await store.savePending(
      {
        'local_id': body['clientOperationId'],
        'client_operation_id': body['clientOperationId'],
        'link_id': body['linkId'],
        'kind': body['kind'],
        'amount_paise': body['amountPaise'],
        'effect_paise': (body['amountPaise'] as int) * (payment ? -1 : 1),
        'note': body['note'],
        'due_date': body['dueDate'],
        'payment_method': body['paymentMethod'],
        'occurred_at_ms': body['occurredAtMs'],
        'sync_status': 'pending',
      },
      operation.payload,
      operation.hash,
      body['occurredAtMs'] as int,
      requireSnapshot: true,
      expectedShopId: shopId,
    );
  }
}
