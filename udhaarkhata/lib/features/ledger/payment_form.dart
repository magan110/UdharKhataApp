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

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.shopId, required this.linkId});
  final OpaqueId shopId, linkId;
  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _form = GlobalKey<FormState>(), _amount = TextEditingController();
  PaymentRepository? _repo;
  CustomerLink? _customer;
  PendingPayment? _pending;
  CreditReceipt? _receipt;
  LedgerBalanceSnapshot? _rejectionBalance;
  Object? _error;
  String _method = 'cash';
  int? _reviewAmount, _localBalance;
  bool _savedLocal = false;
  bool _loading = true, _busy = false, _review = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool _current(PaymentRepository? repo) =>
      mounted && identical(repo, ref.read(paymentRepositoryProvider));
  void _authFailure(Object error) {
    if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
      ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(paymentRepositoryProvider),
        links = ref.read(ownerLinkRepositoryProvider);
    _repo = repo;
    setState(() {
      _loading = true;
      _error = null;
      _customer = null;
      _rejectionBalance = null;
    });
    try {
      if (repo == null || (links == null && repo is! DeviceLedgerRepository)) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final pending = await repo.pendingPayment(widget.shopId, widget.linkId);
      final customer = repo is DeviceLedgerRepository
          ? pending != null
                ? await repo.recoveryCustomer(widget.shopId, widget.linkId)
                : await repo.prepareCustomer(widget.shopId, widget.linkId)
          : await links!.customer(widget.shopId, widget.linkId);
      if (_current(repo)) {
        setState(() {
          _customer = customer;
          _pending = pending;
          _review = pending != null;
        });
      }
    } catch (error) {
      if (_current(repo)) {
        setState(() => _error = error);
        _authFailure(error);
      }
    } finally {
      if (_current(repo)) setState(() => _loading = false);
    }
  }

  void _preview() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _reviewAmount = parseCreditRupees(_amount.text);
      _review = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final repo = _repo, customer = _customer;
    if (_busy ||
        _receipt != null ||
        _savedLocal ||
        repo == null ||
        customer == null ||
        !_current(repo) ||
        _pending?.rejected == true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final isNew = _pending == null;
      final attempt =
          _pending?.attempt ??
          await repo.beginPayment(
            widget.shopId,
            widget.linkId,
            customer.displayName,
            _reviewAmount!,
            _method,
          );
      if (!_current(repo)) return;
      setState(() => _pending = PendingPayment(attempt, false));
      if (isNew && repo is DeviceLedgerRepository) {
        setState(() => _savedLocal = true);
        final snapshot = await repo.snapshot(widget.shopId, widget.linkId);
        if (_current(repo)) {
          setState(() => _localBalance = snapshot?.provisionalPaise);
        }
        return;
      }
      final receipt = await repo.submitPayment(widget.shopId, attempt);
      if (_current(repo)) {
        ref.invalidate(customerLinksProvider(widget.shopId.value));
        setState(() => _receipt = receipt);
      }
    } catch (error) {
      if (!_current(repo)) return;
      setState(() {
        _error = error;
        if (error is AppFailure && error.code == 'BALANCE_CONFLICT') {
          _rejectionBalance = error.balance;
        }
      });
      _authFailure(error);
      // Reload durable rejection state; storage failure never unlocks editing.
      try {
        final pending = await repo.pendingPayment(widget.shopId, widget.linkId);
        if (_current(repo)) setState(() => _pending = pending);
        if (pending?.rejected == true && _rejectionBalance == null) {
          final links = ref.read(ownerLinkRepositoryProvider);
          if (links != null) {
            final customer = await links.customer(widget.shopId, widget.linkId);
            if (_current(repo)) setState(() => _customer = customer);
          }
        }
      } catch (refreshError) {
        if (_current(repo)) {
          setState(() => _error = refreshError);
          _authFailure(refreshError);
        }
      }
    } finally {
      if (_current(repo)) setState(() => _busy = false);
    }
  }

  Future<void> _editRejected() async {
    final repo = _repo, pending = _pending;
    if (_busy ||
        repo == null ||
        pending == null ||
        !pending.rejected ||
        !_current(repo)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.reviewRejectedPayment(widget.shopId, widget.linkId);
      if (_current(repo)) {
        setState(() {
          _amount.text =
              '${pending.attempt.amountPaise ~/ 100}.${(pending.attempt.amountPaise % 100).toString().padLeft(2, '0')}';
          _method = pending.attempt.paymentMethod;
          _pending = null;
          _review = false;
          _error = null;
        });
      }
    } catch (error) {
      if (_current(repo)) {
        setState(() => _error = error);
        _authFailure(error);
      }
    } finally {
      if (_current(repo)) setState(() => _busy = false);
    }
  }

  String _displayTime(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}-${two(date.month)}-${date.year.toString().padLeft(4, '0')} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(paymentRepositoryProvider),
        customer = _customer,
        attempt = _pending?.attempt,
        receipt = _receipt;
    final amount = attempt?.amountPaise ?? _reviewAmount,
        method = attempt?.paymentMethod ?? _method;
    final snapshot = _rejectionBalance;
    final balanceText = snapshot == null
        ? 'Customer owes you ${formatPaise(customer?.balance.value ?? 0)} ${_repo is DeviceLedgerRepository ? '(provisional, including Pending).' : '(last server read).'}'
        : 'Customer owes you ${formatPaise(snapshot.balancePaise)} (server balance as of ${_displayTime(snapshot.asOfAtMs)}).';
    final message = errorMessage(
      _error is AppFailure
          ? (_error as AppFailure).messageKey
          : 'payment.failed',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Record payment received')),
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
                    semanticsLabel: 'Loading payment form',
                  ),
                )
              else if (customer == null) ...[
                Text(message),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ] else ...[
                Text(
                  customer.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (customer.nickname != null)
                  Text('Shop nickname: ${customer.nickname}'),
                const SizedBox(height: 16),
                const Text(
                  'Cash/UPI is manually recorded by you. This app does not verify a bank transfer.',
                ),
                const SizedBox(height: 16),
                if (_savedLocal) ...[
                  const Text('Payment saved · Pending'),
                  Text(
                    '${method == 'cash' ? 'Cash' : 'UPI'} received on this device: ${formatPaise(attempt!.amountPaise)}',
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
                  const Text('Payment acknowledged by server'),
                  Text(
                    '${method == 'cash' ? 'Cash' : 'UPI'} received: ${formatPaise(attempt!.amountPaise)}',
                  ),
                  Text(
                    'Balance when this payment was recorded: Customer owes you ${formatPaise(receipt.balancePaise)}',
                  ),
                  const Text(
                    'Refresh the customer ledger to see the latest balance.',
                  ),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to customer'),
                  ),
                ] else if (_review) ...[
                  Text(
                    '${method == 'cash' ? 'Cash' : 'UPI'} received: ${formatPaise(amount!)}',
                  ),
                  Text(balanceText),
                  if (_pending?.rejected == true) ...[
                    const Text('Payment rejected; no payment was recorded.'),
                    const Text(
                      'The saved amount exceeds the balance or the ledger limit was reached. Review the current balance and correct the amount yourself.',
                    ),
                    if (_error != null) Text(message),
                    FilledButton(
                      onPressed: _busy ? null : _editRejected,
                      child: const Text('Edit amount and method'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Refresh balance'),
                    ),
                  ] else ...[
                    if (attempt != null)
                      const Text(
                        'This saved payment is not confirmed. It may already have reached the server. Check the same payment; do not enter it again.',
                      ),
                    if (_error != null) Text(message),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Checking payment…'
                            : attempt == null
                            ? 'Confirm payment received'
                            : 'Check same payment',
                      ),
                    ),
                    if (attempt == null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _review = false),
                        child: const Text('Edit payment'),
                      ),
                    if (attempt == null &&
                        _error is AppFailure &&
                        (_error as AppFailure).code == 'CREDIT_PENDING')
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.push(
                                '/owner/credit/${widget.shopId.value}/${widget.linkId.value}',
                              ),
                        child: const Text('Check saved credit'),
                      ),
                    if (attempt == null && _error != null)
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Check saved request'),
                      ),
                  ],
                ] else
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(balanceText),
                        Text(
                          _repo is DeviceLedgerRepository
                              ? 'Review the customer, amount and method before confirming. Saved entries are Pending and only on this device until synced. Payments cannot exceed the locally known balance.'
                              : 'Internet is needed. Review the customer, amount and method before confirming payment received. The server checks the latest balance.',
                        ),
                        TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount received (₹)',
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
                        DropdownButtonFormField<String>(
                          initialValue: _method,
                          decoration: const InputDecoration(
                            labelText: 'Received by',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(value: 'upi', child: Text('UPI')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _method = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _preview,
                          child: const Text('Review payment'),
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
