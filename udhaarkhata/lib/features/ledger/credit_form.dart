import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
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
    final current = ref.watch(ledgerRepositoryProvider),
        customer = _customer,
        receipt = _receipt;
    final amount = _attempt?.amountPaise ?? _reviewAmount;
    final note = _attempt != null
        ? _attempt!.note
        : (_note.text.trim().isEmpty ? null : _note.text.trim());
    final due = _attempt != null ? _attempt!.dueDate : _apiDueDate();
    return Scaffold(
      appBar: AppBar(title: const Text('Record credit')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!identical(current, _repo))
                const Text('Please sign in and open this customer again.')
              else if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading credit form',
                  ),
                )
              else if (customer == null) ...[
                Text(
                  errorMessage(
                    _error is AppFailure
                        ? (_error as AppFailure).messageKey
                        : 'credit.failed',
                  ),
                ),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ] else ...[
                Text(
                  customer.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (customer.nickname != null)
                  Text('Shop nickname: ${customer.nickname}'),
                const SizedBox(height: 16),
                if (_savedLocal) ...[
                  const Text('Credit saved · Pending'),
                  Text(
                    'Credit recorded on this device: ${formatPaise(_attempt!.amountPaise)}',
                  ),
                  if (_localBalance != null)
                    Text(
                      'Customer owes you ${formatPaise(_localBalance!)} (provisional, including Pending).',
                    ),
                  const Text(
                    'Pending entries are only on this device. They are not backed up to the cloud.',
                  ),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to customer'),
                  ),
                ] else if (receipt != null) ...[
                  const Text('Credit acknowledged by server'),
                  Text(
                    'Credit recorded: ${formatPaise(_attempt!.amountPaise)}',
                  ),
                  Text(
                    'Balance when this credit was recorded: Customer owes you ${formatPaise(receipt.balancePaise)}',
                  ),
                  const Text(
                    'Refresh the customer ledger to see the latest balance.',
                  ),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to customer'),
                  ),
                ] else if (_review) ...[
                  Text('Credit amount: ${formatPaise(amount!)}'),
                  Text(
                    _repo is DeviceLedgerRepository && _attempt == null
                        ? 'Customer owes you ${formatPaise(amount)} more in the provisional balance after saving.'
                        : 'Customer owes you ${formatPaise(amount)} more after this credit is acknowledged.',
                  ),
                  if (note != null) Text('Note: $note'),
                  if (due != null) Text('Due date: ${_displayDueDate(due)}'),
                  if (_attempt != null)
                    const Text(
                      'This saved credit is not confirmed. It may already have reached the server. Check the same credit; do not enter it again.',
                    ),
                  if (_error != null)
                    Text(
                      errorMessage(
                        _error is AppFailure
                            ? (_error as AppFailure).messageKey
                            : 'credit.failed',
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Checking credit…'
                          : _attempt == null
                          ? 'Confirm credit'
                          : 'Check same credit',
                    ),
                  ),
                  if (_attempt == null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _review = false),
                      child: const Text('Edit credit'),
                    ),
                  if (_error != null && _attempt == null)
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Check saved request'),
                    ),
                ] else
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Customer owes you ${formatPaise(customer.balance.value)} ${_repo is DeviceLedgerRepository ? '(provisional, including Pending).' : '(last server read).'}',
                        ),
                        Text(
                          _repo is DeviceLedgerRepository
                              ? 'Review the customer and amount before confirming. Saved entries are Pending and only on this device until synced.'
                              : 'Internet is needed. Review the customer and amount before confirming. No credit is posted until confirmation.',
                        ),
                        TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                          ),
                          validator: (value) {
                            try {
                              parseCreditRupees(value ?? '');
                              return null;
                            } on FormatException catch (error) {
                              return error.message;
                            }
                          },
                        ),
                        TextFormField(
                          controller: _note,
                          maxLength: maxCreditNoteCharacters,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                          ),
                          validator: (value) =>
                              (value?.length ?? 0) > maxCreditNoteCharacters
                              ? 'Use at most 500 characters.'
                              : null,
                        ),
                        TextFormField(
                          controller: _date,
                          readOnly: true,
                          onTap: _pickDueDate,
                          decoration: InputDecoration(
                            labelText: 'Due date (optional)',
                            hintText: 'DD-MM-YYYY',
                            suffixIcon: _date.text.isEmpty
                                ? const Icon(Icons.calendar_month)
                                : IconButton(
                                    tooltip: 'Clear due date',
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
                              : 'Choose a valid date from the calendar.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _preview,
                          child: const Text('Review credit'),
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
