import '../../app/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/contracts.dart';
import 'ledger_repository.dart';
import '../../app/ui/money_format.dart';
import 'money.dart' show parseCreditRupees;

abstract interface class CorrectionRepository {
  Future<void> saveCorrection(
    OpaqueId shopId,
    OpaqueId linkId,
    String entryId,
    int targetAmountPaise,
    int expectedRevision,
    String reason,
  );
}

final correctionRepositoryProvider = Provider<CorrectionRepository?>((ref) {
  final repository = ref.watch(ledgerRepositoryProvider);
  return repository is CorrectionRepository
      ? repository as CorrectionRepository
      : null;
});

class CorrectionPage extends ConsumerStatefulWidget {
  const CorrectionPage({
    super.key,
    required this.shopId,
    required this.linkId,
    required this.entryId,
    required this.effectiveAmountPaise,
    required this.revision,
  });
  final String shopId, linkId, entryId;
  final int effectiveAmountPaise, revision;
  @override
  ConsumerState<CorrectionPage> createState() => _CorrectionPageState();
}

class _CorrectionPageState extends ConsumerState<CorrectionPage> {
  final _amount = TextEditingController(), _reason = TextEditingController();
  bool _busy = false, _saved = false;
  String? _error;
  int? _target;
  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _review() {
    try {
      final text = _amount.text.trim();
      final amount = RegExp(r'^0(?:\.0{1,2})?$').hasMatch(text)
          ? 0
          : parseCreditRupees(text);
      if (_reason.text.trim().isEmpty || _reason.text.trim().length > 240) {
        throw const FormatException('Enter a reason of 1–240 characters.');
      }
      setState(() {
        _target = amount;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    final repo = ref.read(correctionRepositoryProvider);
    if (_busy || repo == null || _target == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.saveCorrection(
        OpaqueId.fromJson(widget.shopId),
        OpaqueId.fromJson(widget.linkId),
        widget.entryId,
        _target!,
        widget.revision,
        _reason.text.trim(),
      );
      if (mounted && identical(repo, ref.read(correctionRepositoryProvider))) {
        setState(() => _saved = true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Correction could not be saved. Refresh the ledger and review the original entry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppStrings.of(context).translate('Correct entry')),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${AppStrings.of(context).translate('Current acknowledged amount')}: ${formatDisplayPaise(widget.effectiveAmountPaise)}',
          ),
          Text(
            '${AppStrings.of(context).translate('Original entry')}: ${widget.entryId} · Revision ${widget.revision}',
          ),
          Text(
            AppStrings.of(context).translate(
              'The original entry is retained. A correction changes its effective amount.',
            ),
          ),
          if (_saved) ...[
            Text(
              AppStrings.of(context).translate(
                'Correction saved · Pending · Only on this device. It is not backed up to the cloud until synced.',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).translate('Back to ledger')),
            ),
          ] else if (_target != null) ...[
            Text(
              '${AppStrings.of(context).translate('Corrected amount')}: ${formatDisplayPaise(_target!)}',
            ),
            Text(
              '${AppStrings.of(context).translate('Reason')}: ${_reason.text.trim()}',
            ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                AppStrings.of(context).translate('Confirm correction'),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _target = null),
              child: Text(AppStrings.of(context).translate('Edit correction')),
            ),
          ] else ...[
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: AppStrings.of(context)
                    .translate('Corrected amount (₹, zero allowed)'),
              ),
            ),
            TextField(
              controller: _reason,
              maxLength: 240,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).translate('Reason'),
              ),
            ),
            FilledButton(
              onPressed: ref.watch(correctionRepositoryProvider) == null
                  ? null
                  : _review,
              child: Text(
                AppStrings.of(context).translate('Review correction'),
              ),
            ),
          ],
          if (_error != null) Text(AppStrings.of(context).translate(_error!)),
        ],
      ),
    ),
  );
}
