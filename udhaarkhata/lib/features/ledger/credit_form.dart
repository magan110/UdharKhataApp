import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../app/ui/identity_panel.dart';
import '../../app/ui/financial_panels.dart';
import '../../app/ui/money_format.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import '../qr/owner_link_repository.dart';
import '../qr/owner_qr_model.dart';
import 'entry_model.dart';
import 'device_ledger_repository.dart';
import 'ledger_repository.dart';
import 'money.dart';

class CreditPage extends ConsumerStatefulWidget {
  const CreditPage({super.key, required this.shopId, required this.linkId});
  final OpaqueId shopId, linkId;
  @override
  ConsumerState<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends ConsumerState<CreditPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _note = TextEditingController(),
      _date = TextEditingController();
  LedgerRepository? _repo;
  CustomerLink? _customer;
  CreditAttempt? _attempt;
  CreditReceipt? _receipt;
  Object? _error;
  bool _loading = true, _busy = false, _review = false;
  int? _reviewAmount, _localBalance;
  bool _savedLocal = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _date.dispose();
    super.dispose();
  }

  bool _current(LedgerRepository? repo) =>
      mounted && identical(repo, ref.read(ledgerRepositoryProvider));
  Future<void> _load() async {
    final repo = ref.read(ledgerRepositoryProvider),
        links = ref.read(ownerLinkRepositoryProvider);
    _repo = repo;
    setState(() {
      _loading = true;
      _error = null;
      _customer = null;
    });
    try {
      if (repo == null || (links == null && repo is! DeviceLedgerRepository)) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final pending = await repo.pending(widget.shopId, widget.linkId);
      final customer = repo is DeviceLedgerRepository
          ? pending != null
                ? await repo.recoveryCustomer(widget.shopId, widget.linkId)
                : await repo.prepareCustomer(widget.shopId, widget.linkId)
          : await links!.customer(widget.shopId, widget.linkId);
      if (_current(repo)) {
        setState(() {
          _customer = customer;
          _attempt = pending;
          _review = pending != null;
        });
      }
    } catch (error) {
      if (_current(repo)) setState(() => _error = error);
    } finally {
      if (_current(repo)) setState(() => _loading = false);
    }
  }

  String? _apiDueDate() {
    if (_date.text.isEmpty) return null;
    final parts = _date.text.split('-');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  String _displayDueDate(String iso) {
    final parts = iso.split('-');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _pickDueDate() async {
    FocusScope.of(context).unfocus();
    final date = await showDatePicker(
      context: context,
      locale: Locale(AppStrings.of(context).languageCode),
      initialDate: _date.text.isEmpty
          ? DateTime.now()
          : DateTime.parse(_apiDueDate()!),
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (!mounted || date == null) return;
    setState(
      () => _date.text =
          '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().padLeft(4, '0')}',
    );
  }

  void _preview() {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _reviewAmount = parseCreditRupees(_amount.text);
      _review = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _receipt != null || _savedLocal) return;
    final repo = _repo, customer = _customer;
    if (repo == null || customer == null || !_current(repo)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final isNew = _attempt == null;
      final attempt =
          _attempt ??
          await repo.begin(
            widget.shopId,
            widget.linkId,
            customer.displayName,
            _reviewAmount!,
            _note.text,
            _apiDueDate(),
          );
      if (!_current(repo)) return;
      setState(() => _attempt = attempt);
      if (isNew && repo is DeviceLedgerRepository) {
        setState(() => _savedLocal = true);
        final snapshot = await repo.snapshot(widget.shopId, widget.linkId);
        if (_current(repo)) {
          setState(() => _localBalance = snapshot?.provisionalPaise);
        }
        return;
      }
      final receipt = await repo.submit(widget.shopId, attempt);
      if (_current(repo)) {
        ref.invalidate(customerLinksProvider(widget.shopId.value));
        setState(() => _receipt = receipt);
      }
    } catch (error) {
      if (_current(repo)) {
        setState(() => _error = error);
        if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
          ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
        }
      }
    } finally {
      if (_current(repo)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final current = ref.watch(ledgerRepositoryProvider),
        customer = _customer,
        receipt = _receipt;
    final amount = _attempt?.amountPaise ?? _reviewAmount;
    final note = _attempt != null
        ? _attempt!.note
        : (_note.text.trim().isEmpty ? null : _note.text.trim());
    final due = _attempt != null ? _attempt!.dueDate : _apiDueDate();
    return Scaffold(
      appBar: AppBar(title: Text(strings.translate('Record credit'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!identical(current, _repo))
                Text(
                  strings.translate(
                    'Please sign in and open this customer again.',
                  ),
                )
              else if (_loading)
                Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: strings.translate('Loading credit form'),
                  ),
                )
              else if (customer == null) ...[
                Text(
                  errorMessage(
                    _error is AppFailure
                        ? (_error as AppFailure).messageKey
                        : 'credit.failed',
                    languageCode: strings.languageCode,
                  ),
                ),
                FilledButton(
                  onPressed: _load,
                  child: Text(strings.translate('Try again')),
                ),
              ] else ...[
                IdentityPanel(displayName: customer.displayName, nickname: customer.nickname),
                const SizedBox(height: 16),
                if (_savedLocal) ...[
                  SaveReceipt(title: strings.translate('Credit saved · Pending'), amountPaise: _attempt!.amountPaise, pending: true, details: [if (_localBalance != null) Text('${strings.text('owner.owes', values: {'amount': formatDisplayPaise(_localBalance!)})} ${strings.translate('(provisional, including Pending).')}')], onReturn: () => context.pop()),
                ] else if (receipt != null) ...[
                  SaveReceipt(title: strings.translate('Credit acknowledged by server'), amountPaise: _attempt!.amountPaise, pending: false, details: [Text(strings.format('Balance when this credit was recorded: {balance}', values: {'balance': strings.text('owner.owes', values: {'amount': formatDisplayPaise(receipt.balancePaise)})})), Text(strings.translate('Refresh the customer ledger to see the latest balance.'))], onReturn: () => context.pop()),
                ] else if (_review) ...[
                  Text(
                    strings.format(
                      'Credit amount: {amount}',
                      values: {'amount': formatDisplayPaise(amount!)},
                    ),
                  ),
                  Text(
                    _repo is DeviceLedgerRepository && _attempt == null
                        ? strings.format(
                            'Customer owes you {amount} more in the provisional balance after saving.',
                            values: {'amount': formatDisplayPaise(amount)},
                          )
                        : strings.format(
                            'Customer owes you {amount} more after this credit is acknowledged.',
                            values: {'amount': formatDisplayPaise(amount)},
                          ),
                  ),
                  if (note != null)
                    Text(
                      strings.format('Note: {note}', values: {'note': note}),
                    ),
                  if (due != null)
                    Text(
                      strings.format(
                        'Due date: {date}',
                        values: {'date': _displayDueDate(due)},
                      ),
                    ),
                  if (_attempt != null)
                    Text(
                      strings.translate(
                        'This saved credit is not confirmed. It may already have reached the server. Check the same credit; do not enter it again.',
                      ),
                    ),
                  if (_error != null)
                    Text(
                      errorMessage(
                        _error is AppFailure
                            ? (_error as AppFailure).messageKey
                            : 'credit.failed',
                        languageCode: strings.languageCode,
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      strings.translate(
                        _busy
                            ? 'Checking credit…'
                            : _attempt == null
                            ? 'Confirm credit'
                            : 'Check same credit',
                      ),
                    ),
                  ),
                  if (_attempt == null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _review = false),
                      child: Text(strings.translate('Edit credit')),
                    ),
                  if (_error != null && _attempt == null)
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text(strings.translate('Check saved request')),
                    ),
                ] else
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${strings.text('owner.owes', values: {'amount': formatDisplayPaise(customer.balance.value)})} ${strings.translate(_repo is DeviceLedgerRepository ? '(provisional, including Pending).' : '(last server read).')}',
                        ),
                        Text(
                          strings.translate(
                            _repo is DeviceLedgerRepository
                                ? 'Review the customer and amount before confirming. Saved entries are Pending and only on this device until synced.'
                                : 'Internet is needed. Review the customer and amount before confirming. No credit is posted until confirmation.',
                          ),
                        ),
                        TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: strings.translate('Amount (₹)'),
                          ),
                          validator: (value) {
                            try {
                              parseCreditRupees(value ?? '');
                              return null;
                            } on FormatException catch (error) {
                              return strings.translate(error.message);
                            }
                          },
                        ),
                        TextFormField(
                          controller: _note,
                          maxLength: maxCreditNoteCharacters,
                          decoration: InputDecoration(
                            labelText: strings.translate('Note (optional)'),
                          ),
                          validator: (value) =>
                              (value?.length ?? 0) > maxCreditNoteCharacters
                              ? strings.translate('Use at most 500 characters.')
                              : null,
                        ),
                        TextFormField(
                          controller: _date,
                          readOnly: true,
                          onTap: _pickDueDate,
                          decoration: InputDecoration(
                            labelText: strings.translate('Due date (optional)'),
                            hintText: strings.translate('DD-MM-YYYY'),
                            suffixIcon: _date.text.isEmpty
                                ? const Icon(Icons.calendar_month)
                                : IconButton(
                                    tooltip: strings.translate(
                                      'Clear due date',
                                    ),
                                    onPressed: () =>
                                        setState(() => _date.clear()),
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                          validator: (value) =>
                              value == null ||
                                  value.trim().isEmpty ||
                                  validDueDate(_apiDueDate())
                              ? null
                              : strings.translate(
                                  'Choose a valid date from the calendar.',
                                ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _preview,
                          child: Text(strings.translate('Review credit')),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
