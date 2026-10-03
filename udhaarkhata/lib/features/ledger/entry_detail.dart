import '../../app/app_strings.dart';

import 'package:flutter/material.dart';

import 'correction_form.dart';
import 'history_page.dart' show historyDate;
import '../../app/ui/money_format.dart';

class EntryDetail extends StatelessWidget {
  const EntryDetail({
    super.key,
    required this.shopId,
    required this.linkId,
    required this.entry,
    required this.entries,
  });
  final String shopId, linkId;
  final Map<String, Object?> entry;
  final List<Map<String, Object?>> entries;
  @override
  Widget build(BuildContext context) {
    final id = entry['server_id'];
    final corrections =
        entries
            .where(
              (e) =>
                  id != null &&
                  e['kind'] == 'correction' &&
                  e['corrects_entry_id'] == id &&
                  e['sync_status'] == 'synced',
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['server_seq'] as int).compareTo(b['server_seq'] as int),
          );
    final amount = corrections.isEmpty
        ? entry['amount_paise'] as int
        : corrections.last['target_amount_paise'] as int;
    final pending = entries.any(
      (e) =>
          id != null &&
          e['kind'] == 'correction' &&
          e['corrects_entry_id'] == id &&
          e['sync_status'] != 'synced',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${AppStrings.of(context).translate('Original amount')}: ${formatDisplayPaise(entry['amount_paise'] as int)}',
        ),
        Text(
          '${AppStrings.of(context).translate('Effective acknowledged amount')}: ${formatDisplayPaise(amount)}',
        ),
        for (final correction in corrections)
          Text(
            '${AppStrings.of(context).translate('Correction')}: ${correction['correction_reason']} · ${historyDate(correction['created_at_ms'] as int)}',
          ),
        if (pending)
          Text(
            AppStrings.of(context).translate(
              'A correction is Pending or Needs attention. The effective acknowledged amount excludes it.',
            ),
          ),
        if (id is String && entry['sync_status'] == 'synced' && !pending)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CorrectionPage(
                  shopId: shopId,
                  linkId: linkId,
                  entryId: id,
                  effectiveAmountPaise: amount,
                  revision: corrections.length,
                ),
              ),
            ),
            child: Text(AppStrings.of(context).translate('Correct entry')),
          ),
      ],
    );
  }
}
