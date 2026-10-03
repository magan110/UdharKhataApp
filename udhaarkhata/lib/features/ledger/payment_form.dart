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
        throw AppFailure('AUTH_REQUIRED', 'auth.required');
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
    final strings = AppStrings.of(context);
    final current = ref.watch(paymentRepositoryProvider),
        customer = _customer,
        attempt = _pending?.attempt,
        receipt = _receipt;
    final amount = attempt?.amountPaise ?? _reviewAmount,
        method = attempt?.paymentMethod ?? _method;
    final snapshot = _rejectionBalance;
    final balanceText = snapshot == null
        ? '${strings.text('owner.owes', values: {'amount': formatDisplayPaise(customer?.balance.value ?? 0)})} ${strings.translate(_repo is DeviceLedgerRepository ? '(provisional, including Pending).' : '(last server read).')}'
        : '${strings.text('owner.owes', values: {'amount': formatDisplayPaise(snapshot.balancePaise)})} ${strings.format('(server balance as of {time}).', values: {'time': _displayTime(snapshot.asOfAtMs)})}';
    final message = errorMessage(
      _error is AppFailure
          ? (_error as AppFailure).messageKey
          : 'payment.failed',
      languageCode: AppStrings.of(context).languageCode,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.of(context).translate('Record payment received'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!identical(current, _repo))
                Text(
                  AppStrings.of(
                    context,
                  ).translate('Please sign in and open this customer again.'),
                )
              else if (_loading)
                Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: AppStrings.of(context)
                        .translate('Loading payment form'),
                  ),
                )
              else if (customer == null) ...[
                Text(message),
                FilledButton(
                  onPressed: _load,
                  child: Text(AppStrings.of(context).translate('Try again')),
                ),
              ] else ...[
                IdentityPanel(
                  displayName: customer.displayName,
                  nickname: customer.nickname,
                ),
                SizedBox(height: 16),
                Text(
                  AppStrings.of(context).translate(
                    'Cash/UPI is manually recorded by you. This app does not verify a bank transfer.',
                  ),
                ),
                SizedBox(height: 16),
                if (_savedLocal) ...[
                  SaveReceipt(
                    title: strings.translate('Payment saved · Pending'),
                    amountPaise: attempt!.amountPaise,
                    pending: true,
                    details: [
                      Text(
                        strings.format(
                          '{method} received on this device: {amount}',
                          values: {
                            'method': strings.translate(
                              method == 'cash' ? 'Cash' : 'UPI',
                            ),
                            'amount': formatDisplayPaise(attempt.amountPaise),
                          },
                        ),
                      ),
                      if (_localBalance != null)
                        Text(
                          '${strings.text('owner.owes', values: {'amount': formatDisplayPaise(_localBalance!)})} ${strings.translate('(provisional, including Pending).')}',
                        ),
                    ],
                    onReturn: () => context.pop(),
                  ),
                ] else if (receipt != null) ...[
                  SaveReceipt(
                    title: strings.translate('Payment acknowledged by server'),
                    amountPaise: attempt!.amountPaise,
                    pending: false,
                    details: [
                      Text(
                        strings.format(
                          '{method} received: {amount}',
                          values: {
                            'method': strings.translate(
                              method == 'cash' ? 'Cash' : 'UPI',
                            ),
                            'amount': formatDisplayPaise(attempt.amountPaise),
                          },
                        ),
                      ),
                      Text(
                        strings.format(
                          'Balance when this payment was recorded: Customer owes you {amount}',
                          values: {
                            'amount': formatDisplayPaise(receipt.balancePaise),
                          },
                        ),
                      ),
                      Text(
                        strings.translate(
                          'Refresh the customer ledger to see the latest balance.',
                        ),
                      ),
                    ],
                    onReturn: () => context.pop(),
                  ),
                ] else if (_review) ...[
                  Text(
                    strings.format(
                      '{method} received: {amount}',
                      values: {
                        'method': strings.translate(
                          method == 'cash' ? 'Cash' : 'UPI',
                        ),
                        'amount': formatDisplayPaise(amount!),
                      },
                    ),
                  ),
                  Text(balanceText),
                  if (_pending?.rejected == true) ...[
                    Text(
                      AppStrings.of(
                        context,
                      ).translate('Payment rejected; no payment was recorded.'),
                    ),
                    Text(
                      AppStrings.of(context).translate(
                        'The saved amount exceeds the balance or the ledger limit was reached. Review the current balance and correct the amount yourself.',
                      ),
                    ),
                    if (_error != null) Text(message),
                    FilledButton(
                      onPressed: _busy ? null : _editRejected,
                      child: Text(
                        AppStrings.of(context)
                            .translate('Edit amount and method'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text(
                        AppStrings.of(context).translate('Refresh balance'),
                      ),
                    ),
                  ] else ...[
                    if (attempt != null)
                      Text(
                        AppStrings.of(context).translate(
                          'This saved payment is not confirmed. It may already have reached the server. Check the same payment; do not enter it again.',
                        ),
                      ),
                    if (_error != null) Text(message),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        strings.translate(
                          _busy
                              ? 'Checking payment…'
                              : attempt == null
                              ? 'Confirm payment received'
                              : 'Check same payment',
                        ),
                      ),
                    ),
                    if (attempt == null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _review = false),
                        child: Text(
                          AppStrings.of(context).translate('Edit payment'),
                        ),
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
                        child: Text(
                          AppStrings.of(context)
                              .translate('Check saved credit'),
                        ),
                      ),
                    if (attempt == null && _error != null)
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: Text(
                          AppStrings.of(context)
                              .translate('Check saved request'),
                        ),
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
                          strings.translate(
                            _repo is DeviceLedgerRepository
                                ? 'Review the customer, amount and method before confirming. Saved entries are Pending and only on this device until synced. Payments cannot exceed the locally known balance.'
                                : 'Internet is needed. Review the customer, amount and method before confirming payment received. The server checks the latest balance.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amount,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppStrings.of(context)
                                .translate('Amount received (₹)'),
                          ),
                          validator: (value) {
                            try {
                              parseCreditRupees(value ?? '');
                              return null;
                            } on FormatException catch (error) {
                              return AppStrings.of(context)
                                  .translate(error.message);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _method,
                          decoration: InputDecoration(
                            labelText: AppStrings.of(context)
                                .translate('Received by'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(
                                AppStrings.of(context).translate('Cash'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'upi',
                              child: Text(
                                AppStrings.of(context).translate('UPI'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _method = value);
                          },
                        ),
                        SizedBox(height: 16),
                        FilledButton(
                          onPressed: _preview,
                          child: Text(
                            AppStrings.of(context).translate('Review payment'),
                          ),
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
