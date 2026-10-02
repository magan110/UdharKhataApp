import '../ledger/money.dart';
import 'statement_service.dart';

String csvCell(String value) {
  final safe = RegExp(r'^[\s\x00-\x20]*[=+@-]').hasMatch(value)
      ? "'$value"
      : value;
  return '"${safe.replaceAll('"', '""')}"';
}

String exportCsv(AuditedStatement s) {
  final rows = <List<String>>[
    ['Shop', s.shopName],
    ['Customer', s.customerName],
    [
      'Period (UTC posting dates)',
      s.from.toIso8601String().substring(0, 10),
      s.to.toIso8601String().substring(0, 10),
    ],
    [
      'Snapshot UTC',
      DateTime.fromMillisecondsSinceEpoch(
        s.snapshotAtMs,
        isUtc: true,
      ).toIso8601String(),
    ],
    ['Acknowledged only; device Pending excluded'],
    ['Opening balance', formatPaise(s.opening)],
    [
      'ID',
      'Server sequence',
      'Posted UTC',
      'Occurred UTC',
      'Kind',
      'Signed effect INR',
      'Corrects ID',
      'Target paise',
      'Note / reason',
    ],
    for (final e in s.entries)
      [
        e.id,
        '${e.seq}',
        DateTime.fromMillisecondsSinceEpoch(
          e.createdAtMs,
          isUtc: true,
        ).toIso8601String(),
        DateTime.fromMillisecondsSinceEpoch(
          e.occurredAtMs,
          isUtc: true,
        ).toIso8601String(),
        e.kind,
        formatPaise(e.effect),
        e.targetId ?? '',
        e.kind == 'correction' ? '${e.amount}' : '',
        e.reason ?? e.note ?? '',
      ],
    ['Closing balance', formatPaise(s.closing)],
  ];
  return '\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';
}
