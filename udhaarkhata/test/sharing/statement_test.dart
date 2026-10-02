import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/ledger_entry.dart';
import 'package:udhaarkhata/features/settings/settings_repository.dart';
import 'package:udhaarkhata/features/sharing/export_csv.dart';
import 'package:udhaarkhata/features/sharing/reminder_preview.dart';
import 'package:udhaarkhata/features/sharing/statement_pdf.dart';
import 'package:udhaarkhata/features/sharing/statement_service.dart';

HistoryEntry entry(String id, int seq, int effect, int day, {String? target}) =>
    HistoryEntry(
      {
        'id': id,
        'serverSeq': seq,
        'shopId': 'shop_1',
        'linkId': 'link_1',
        'kind': target == null
            ? (effect > 0 ? 'credit' : 'payment')
            : 'correction',
        'effectPaise': effect,
        'amountPaise': target == null ? effect.abs() : null,
        'targetAmountPaise': target == null ? null : 500,
        'correctsEntryId': target,
        'correctionReason': target == null ? null : 'सुधार = SUM(A1)',
        'occurredAtMs': DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
        'createdAtMs': DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
        'createdByUserId': 'user_1',
        'revision': target == null ? 0 : 1,
        'note': target == null ? '  =SUM(A1)\n"नाम"' : null,
        'paymentMethod': target == null && effect < 0 ? 'cash' : null,
        'dueDate': null,
      },
      'shop_1',
      'link_1',
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final history = [
    entry('entry_1', 1, 1000, 1),
    entry('entry_2', 3, -200, 2),
    entry('entry_3', 7, -500, 3, target: 'entry_1'),
  ];
  final balance = LedgerBalanceSnapshot.fromJson({
    'balancePaise': 300,
    'ledgerVersion': 3,
    'asOfServerSeq': 7,
    'asOfAtMs': 1,
  });
  AuditedStatement build(
    DateTime from,
    DateTime to, {
    List<HistoryEntry>? records,
  }) => reconcileStatement(
    completeHistory: records ?? history,
    balance: balance,
    shopName: 'किराना',
    customerName: 'सीमा',
    snapshotAtMs: DateTime.utc(2026, 1, 4).millisecondsSinceEpoch,
    from: from,
    to: to,
  );
  test('Complete acknowledged ledger reconciles corrections, gaps and empty periods', () {
    final s = build(DateTime.utc(2026, 1, 2), DateTime.utc(2026, 1, 3));
    expect(s.opening, 1000);
    expect(s.closing, 300);
    expect(
      s.opening + s.entries.fold<int>(0, (int total, e) => total + e.effect),
      s.closing,
    );
    final empty = build(DateTime.utc(2026, 2, 1), DateTime.utc(2026, 2, 1));
    expect(empty.entries, isEmpty);
    expect(empty.opening, 300);
    expect(empty.closing, 300);
    expect(
      () => build(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 4),
        records: history.sublist(1),
      ),
      throwsA(anything),
    );
  });
  test('Bounds and duplicate rows fail closed', () {
    expect(
      () => build(DateTime.utc(2026, 1, 1), DateTime.utc(2027, 1, 2)),
      throwsA(anything),
    );
    expect(
      () => build(DateTime.utc(2026, 1, 3), DateTime.utc(2026, 1, 1)),
      throwsA(anything),
    );
    expect(
      () => build(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 4),
        records: [...history, history.last],
      ),
      throwsA(anything),
    );
  });
  test('CSV shields formula triggers after whitespace and quotes Unicode multiline cells', () {
    for (final trigger in ['=', '+', '-', '@']) {
      expect(
        csvCell(
          ' \t$trigger'
          'SUM(A1)',
        ),
        startsWith('"\''),
      );
    }
    expect(csvCell('सीमा,"नाम"\nपंक्ति'), '"सीमा,""नाम""\nपंक्ति"');
    final csv = exportCsv(
      build(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 4)),
    );
    expect(csv, contains('किराना'));
    expect(csv, contains('"\'  =SUM(A1)'));
    expect(csv, contains('₹3.00'));
    expect(csv, contains('device Pending')); // heading case asserted below
  });
  test(
    'Hindi PDF includes valid document bytes without network fonts',
    () async {
      final pdf = await statementPdf(
        build(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 4)),
      );
      expect(utf8.decode(pdf.take(4).toList()), '%PDF');
      expect(pdf.length, greaterThan(1000));
      if (const bool.fromEnvironment('WRITE_HINDI_PDF')) {
        await File('/tmp/d21-hindi-statement.pdf').writeAsBytes(pdf);
      }
    },
  );
  test(
    'Reminder uses cloud balance, unambiguous customer debt and snapshot',
    () {
      final s = build(DateTime.utc(2026, 1, 2), DateTime.utc(2026, 1, 2));
      expect(s.closing, 800);
      final en = reminderText(s, 'en');
      expect(en, contains('owe ₹3.00'));
      expect(en, contains('device Pending'));
      expect(reminderText(s, 'hi'), contains('आपका बकाया ₹3.00'));
    },
  );
  test(
    'Language preference is isolated per account and falls back to device',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const first = DeviceSettingsRepository(
        FlutterSecureStorage(),
        accountId: 'owner1',
      );
      const second = DeviceSettingsRepository(
        FlutterSecureStorage(),
        accountId: 'owner2',
      );
      await first.setLanguageCode('hi');
      expect(await first.languageCode(), 'hi');
      await second.setLanguageCode('en');
      expect(await first.languageCode(), 'hi');
      expect(await second.languageCode(), 'en');
      expect(() => second.setLanguageCode('fr'), throwsArgumentError);
    },
  );
  testWidgets('Hindi debt direction renders at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: Text(
                AppStrings.of(context).text(
                  'customer.owes',
                  values: {'shop': 'किराना', 'amount': '₹3.00'},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('आपको किराना को ₹3.00 देना है'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
