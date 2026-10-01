import '../../core/network/contracts.dart';
import 'money.dart';

class CreditAttempt {
  const CreditAttempt(
    this.operationId,
    this.linkId,
    this.displayName,
    this.amountPaise,
    this.note,
    this.dueDate,
    this.occurredAtMs,
  );
  final String operationId, displayName;
  final OpaqueId linkId;
  final int amountPaise, occurredAtMs;
  final String? note, dueDate;
  Map<String, Object?> get body => {
    'clientOperationId': operationId,
    'linkId': linkId.value,
    'kind': 'credit',
    'amountPaise': amountPaise,
    'note': note,
    'dueDate': dueDate,
    'occurredAtMs': occurredAtMs,
  };
  factory CreditAttempt.fromJson(Object? value) {
    final row = jsonObject(value), op = jsonString(row['clientOperationId']);
    final amount = MoneyPaise.fromJson(row['amountPaise']).value,
        note = row['note'],
        due = row['dueDate'];
    if (op.length != 36 ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(op) ||
        row['kind'] != 'credit' ||
        amount < 1 ||
        amount > maxCreditPaise ||
        (note != null &&
            (note is! String || note.length > maxCreditNoteCharacters)) ||
        (due != null && due is! String) ||
        !validDueDate(due as String?)) {
      throw const FormatException('Invalid saved credit');
    }
    return CreditAttempt(
      op,
      OpaqueId.fromJson(row['linkId']),
      jsonString(row['customerDisplayName']),
      amount,
      note as String?,
      due,
      timestampMs(row['occurredAtMs']),
    );
  }
}

class CreditReceipt {
  const CreditReceipt(
    this.entryId,
    this.balancePaise,
    this.ledgerVersion,
    this.replayed,
  );
  final OpaqueId entryId;
  final int balancePaise, ledgerVersion;
  final bool replayed;
  factory CreditReceipt.fromJson(
    Object? value,
    OpaqueId shopId,
    CreditAttempt command,
  ) {
    final row = jsonObject(value),
        entry = jsonObject(row['entry']),
        balance = jsonObject(row['balance']);
    final amount = MoneyPaise.fromJson(entry['amountPaise']).value,
        effect = MoneyPaise.fromJson(entry['effectPaise']).value;
    final total = MoneyPaise.fromJson(balance['balancePaise']).value,
        version = timestampMs(balance['ledgerVersion']),
        seq = timestampMs(entry['serverSeq']);
    timestampMs(entry['createdAtMs']);
    timestampMs(balance['asOfAtMs']);
    if (entry['shopId'] != shopId.value ||
        entry['linkId'] != command.linkId.value ||
        entry['kind'] != 'credit' ||
        amount != command.amountPaise ||
        effect != amount ||
        entry['note'] != command.note ||
        entry['dueDate'] != command.dueDate ||
        entry['occurredAtMs'] != command.occurredAtMs ||
        total < 0 ||
        version < 1 ||
        seq < 1 ||
        balance['asOfServerSeq'] != seq ||
        row['replayed'] is! bool) {
      throw const FormatException('Unverified credit receipt');
    }
    return CreditReceipt(
      OpaqueId.fromJson(entry['id']),
      total,
      version,
      row['replayed'] as bool,
    );
  }
}
