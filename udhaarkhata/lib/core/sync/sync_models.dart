import '../network/contracts.dart';
import '../network/ledger_entry.dart';

final class SyncEntry {
  SyncEntry.fromJson(Object? value) {
    final data = jsonObject(value);
    shopId = OpaqueId.fromJson(data['shopId']).value;
    linkId = OpaqueId.fromJson(data['linkId']).value;
    operationId = jsonString(data['clientOperationId']);
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(operationId)) {
      throw const FormatException('Invalid operation identity');
    }
    ownerId = OpaqueId.fromJson(data['createdByUserId']).value;
    entry = HistoryEntry(data, shopId, linkId);
  }
  late final String shopId, linkId, operationId, ownerId;
  late final HistoryEntry entry;
  String get id => entry.id;
  int get seq => entry.seq;
  Map<String, Object?> get row => {
    'local_id': 'server_$id',
    'server_id': id,
    'server_seq': seq,
    'link_id': linkId,
    'client_operation_id': operationId,
    'kind': entry.kind,
    'amount_paise': entry.kind == 'correction' ? null : entry.amount,
    'target_amount_paise': entry.kind == 'correction' ? entry.amount : null,
    'effect_paise': entry.effect,
    'note': entry.note,
    'payment_method': entry.method,
    'due_date': entry.dueDate,
    'corrects_entry_id': entry.targetId,
    'expected_revision': entry.kind == 'correction' ? entry.revision - 1 : null,
    'correction_reason': entry.reason,
    'occurred_at_ms': entry.occurredAtMs,
    'created_at_ms': entry.createdAtMs,
    'sync_status': 'synced',
  };
  bool matchesBody(Map<String, Object?> body) =>
      operationId == body['clientOperationId'] &&
      linkId == body['linkId'] &&
      entry.kind == body['kind'] &&
      (entry.kind == 'correction'
          ? entry.amount == body['targetAmountPaise'] &&
                entry.targetId == body['correctsEntryId'] &&
                entry.revision == (body['expectedRevision'] as int) + 1 &&
                entry.reason == body['correctionReason']
          : entry.amount == body['amountPaise']) &&
      entry.note == body['note'] &&
      entry.method == body['paymentMethod'] &&
      entry.dueDate == body['dueDate'] &&
      entry.occurredAtMs == body['occurredAtMs'];
}

final class SyncPage {
  SyncPage.fromJson(Object? value) {
    final data = jsonObject(value);
    link = jsonObject(data['link']);
    for (final key in ['id', 'shopId', 'customerUserId', 'ownerUserId']) {
      OpaqueId.fromJson(link[key]);
    }
    if (link['status'] != 'active' ||
        jsonString(link['displayName']).length > 120 ||
        (link['nickname'] != null &&
            jsonString(link['nickname']).length > 120)) {
      throw const FormatException('Invalid link');
    }
    timestampMs(link['linkedAtMs']);
    final values = data['items'];
    if (values is! List) throw const FormatException('Invalid items');
    items = values.map(SyncEntry.fromJson).toList();
    if (items.length > 100) throw const FormatException('Oversized page');
    final more = data['hasMore'];
    if (more is! bool) throw const FormatException('Invalid page');
    hasMore = more;
    nextCursor = data['nextCursor'] == null
        ? null
        : PageCursor.fromJson(data['nextCursor']).value;
    snapshotAtMs = timestampMs(data['snapshotAtMs']);
    highWaterSeq = timestampMs(data['highWaterSeq']);
    appliedThroughSeq = timestampMs(data['appliedThroughSeq']);
    balance = LedgerBalanceSnapshot.fromJson(data['balance']);
    if (hasMore != (nextCursor != null) ||
        (hasMore && items.isEmpty) ||
        appliedThroughSeq > highWaterSeq ||
        balance.asOfServerSeq != highWaterSeq ||
        (items.isNotEmpty && items.last.seq != appliedThroughSeq)) {
      throw const FormatException('Invalid page boundary');
    }
    var previous = 0;
    for (final item in items) {
      if (item.seq <= previous ||
          item.seq > highWaterSeq ||
          item.linkId != link['id'] ||
          item.shopId != link['shopId'] ||
          item.ownerId != link['ownerUserId']) {
        throw const FormatException('Invalid page scope/order');
      }
      previous = item.seq;
    }
  }
  late final Map<String, Object?> link;
  late final List<SyncEntry> items;
  late final String? nextCursor;
  late final bool hasMore;
  late final int snapshotAtMs, highWaterSeq, appliedThroughSeq;
  late final LedgerBalanceSnapshot balance;
}
