import 'contracts.dart';

class HistoryEntry {
  HistoryEntry(Object? value, String shopId, String linkId) {
    final row = jsonObject(value);
    id = OpaqueId.fromJson(row['id']).value;
    seq = timestampMs(row['serverSeq']);
    kind = jsonString(row['kind']);
    effect = MoneyPaise.fromJson(row['effectPaise']).value;
    occurredAtMs = timestampMs(row['occurredAtMs']);
    createdAtMs = timestampMs(row['createdAtMs']);
    OpaqueId.fromJson(row['createdByUserId']);
    revision = timestampMs(row['revision']);
    note = _nullableText(row['note'], 500);
    dueDate = _nullableText(row['dueDate'], 10);
    method = _nullableText(row['paymentMethod'], 4);
    reason = _nullableText(row['correctionReason'], 500);
    if (row['shopId'] != shopId ||
        row['linkId'] != linkId ||
        seq == 0 ||
        !validLedgerDate(dueDate)) {
      throw const FormatException('Wrong history scope');
    }
    if (kind == 'credit' || kind == 'payment') {
      amount = MoneyPaise.fromJson(row['amountPaise']).value;
      if (amount < 1 ||
          effect != (kind == 'credit' ? amount : -amount) ||
          row['targetAmountPaise'] != null ||
          row['correctsEntryId'] != null ||
          reason != null ||
          revision != 0 ||
          (kind == 'credit'
              ? method != null
              : !['cash', 'upi'].contains(method) || dueDate != null)) {
        throw const FormatException('Invalid original entry');
      }
    } else if (kind == 'correction') {
      amount = MoneyPaise.fromJson(row['targetAmountPaise']).value;
      targetId = OpaqueId.fromJson(row['correctsEntryId']).value;
      if (amount < 0 ||
          row['amountPaise'] != null ||
          method != null ||
          dueDate != null ||
          reason == null ||
          revision < 1) {
        throw const FormatException('Invalid correction');
      }
    } else {
      throw const FormatException('Invalid entry kind');
    }
  }
  late final String id, kind;
  late final int seq, amount, effect, occurredAtMs, createdAtMs, revision;
  late final String? note, dueDate, method, reason;
  String? targetId;
}

String? _nullableText(Object? value, int max) {
  if (value == null) return null;
  final text = jsonString(value);
  if (text.length > max) throw const FormatException('Oversized text');
  return text;
}

bool validLedgerDate(String? value) {
  if (value == null) return true;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final date = DateTime.tryParse(value);
  return date != null && date.toIso8601String().substring(0, 10) == value;
}
