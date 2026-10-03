import 'package:flutter/material.dart';
import '../app_strings.dart';
import 'identity_panel.dart';
import 'money_format.dart';
import 'status_chip.dart';

class FinancialReview extends StatelessWidget {
  const FinancialReview({super.key, required this.customerName, required this.actionLabel, required this.amountPaise, required this.details, required this.busy, required this.onSubmit, this.onEdit});
  final String customerName, actionLabel;
  final int amountPaise;
  final List<Widget> details;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [IdentityPanel(displayName: customerName), const SizedBox(height: 16), Text(formatDisplayPaise(amountPaise), style: Theme.of(context).textTheme.headlineSmall), ...details, const SizedBox(height: 16), FilledButton(onPressed: busy ? null : onSubmit, child: Text(actionLabel)), if (onEdit != null) TextButton(onPressed: busy ? null : onEdit, child: Text(AppStrings.of(context).translate('Edit')))]);
}
class SaveReceipt extends StatelessWidget {
  const SaveReceipt({super.key, required this.title, required this.amountPaise, required this.pending, required this.details, required this.onReturn});
  final String title;
  final int amountPaise;
  final bool pending;
  final List<Widget> details;
  final VoidCallback onReturn;
  @override
  Widget build(BuildContext context) => Semantics(liveRegion: true, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), Text(formatDisplayPaise(amountPaise), style: Theme.of(context).textTheme.headlineSmall), StatusChip(status: pending ? EntryDisplayStatus.pending : EntryDisplayStatus.synced), if (pending) Text(AppStrings.of(context).translate('Pending entries are only on this device. They are not backed up to the cloud.')), ...details, const SizedBox(height: 16), FilledButton(onPressed: onReturn, child: Text(AppStrings.of(context).translate('Back to customer')))]));
}
