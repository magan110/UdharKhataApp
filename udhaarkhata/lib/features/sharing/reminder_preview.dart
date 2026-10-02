import '../../app/app_strings.dart';
import '../ledger/money.dart';
import 'statement_service.dart';

String reminderText(AuditedStatement statement, String languageCode) =>
    AppStrings(languageCode).text(
      'reminder.template',
      values: {
        'customer': statement.customerName,
        'shop': statement.shopName,
        'amount': formatPaise(statement.cloudBalance),
        'asOf': DateTime.fromMillisecondsSinceEpoch(
          statement.snapshotAtMs,
          isUtc: true,
        ).toIso8601String(),
      },
    );
