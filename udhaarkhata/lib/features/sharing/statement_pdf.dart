import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ledger/money.dart';
import 'statement_service.dart';

Future<Uint8List> statementPdf(AuditedStatement s) async {
  final latin = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans.ttf'));
  final hindi = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'),
  );
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: 1000,
      theme: pw.ThemeData.withFont(base: latin, fontFallback: [hindi]),
      build: (_) => [
        pw.Text('Customer statement / ग्राहक विवरण'),
        pw.Text('${s.shopName}\n${s.customerName}'),
        pw.Text(
          'UTC posting period: ${s.from.toIso8601String().substring(0, 10)} – ${s.to.toIso8601String().substring(0, 10)}',
        ),
        pw.Text(
          'Snapshot UTC: ${DateTime.fromMillisecondsSinceEpoch(s.snapshotAtMs, isUtc: true).toIso8601String()}',
        ),
        pw.Text(
          'Acknowledged only. Device Pending excluded. / केवल क्लाउड में पुष्टि किए गए रिकॉर्ड।',
        ),
        pw.Text('Opening / शुरुआती बकाया: ${formatPaise(s.opening)}'),
        for (final e in s.entries)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Text(
              '#${e.seq} ${e.id}\nPosted UTC ${DateTime.fromMillisecondsSinceEpoch(e.createdAtMs, isUtc: true).toIso8601String()}\nOccurred UTC ${DateTime.fromMillisecondsSinceEpoch(e.occurredAtMs, isUtc: true).toIso8601String()}\n${e.kind}: ${formatPaise(e.effect)}${e.targetId == null ? '' : ' | corrects ${e.targetId}; target paise ${e.amount}'}\n${e.reason ?? e.note ?? ''}',
            ),
          ),
        pw.Text('Closing / अंतिम बकाया: ${formatPaise(s.closing)}'),
      ],
    ),
  );
  return doc.save();
}
