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
  int? _reviewAmount;
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
      if (repo == null || links == null) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final customer = await links.customer(widget.shopId, widget.linkId);
      final pending = await repo.pending(widget.shopId, widget.linkId);
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

  void _preview() {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _reviewAmount = parseCreditRupees(_amount.text);
      _review = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _receipt != null) return;
    final repo = _repo, customer = _customer;
    if (repo == null || customer == null || !_current(repo)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt =
          _attempt ??
          await repo.begin(
            widget.shopId,
            widget.linkId,
            customer.displayName,
            _reviewAmount!,
            _note.text,
            _date.text.trim().isEmpty ? null : _date.text.trim(),
          );
      if (!_current(repo)) return;
      setState(() => _attempt = attempt);
      final receipt = await repo.submit(widget.shopId, attempt);
      if (_current(repo)) {
        ref.invalidate(customerLinksProvider(widget.shopId.value));
        setState(() => _receipt = receipt);
      }
    } catch (error) {
      if (_current(repo)) {
        setState(() => _error = error);
        if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
          ref.invalidate(sessionProvider);
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
    final due = _attempt != null
        ? _attempt!.dueDate
        : (_date.text.trim().isEmpty ? null : _date.text.trim());
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
                if (receipt != null) ...[
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
                    'Customer owes you ${formatPaise(amount)} more after this credit is acknowledged.',
                  ),
                  if (note != null) Text('Note: $note'),
                  if (due != null) Text('Due date: $due'),
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
                          'Customer owes you ${formatPaise(customer.balance.value)} (last server read).',
                        ),
                        const Text(
                          'Internet is needed. Review the customer and amount before confirming. No credit is posted until confirmation.',
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
                          decoration: const InputDecoration(
                            labelText: 'Due date (optional)',
                            hintText: 'YYYY-MM-DD',
                          ),
                          validator: (value) =>
                              value == null ||
                                  value.trim().isEmpty ||
                                  validDueDate(value.trim())
                              ? null
                              : 'Use a valid YYYY-MM-DD date.',
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
