import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import '../qr/owner_link_repository.dart';
import '../qr/owner_qr_model.dart';
import '../ledger/money.dart';
import '../ledger/ledger_repository.dart';
import '../ledger/device_ledger_repository.dart';
import '../ledger/history_page.dart';
import '../ledger/online_reads.dart';

class CustomerList extends StatelessWidget {
  const CustomerList({super.key, required this.shopId});
  final OpaqueId shopId;
  @override
  Widget build(BuildContext context) => OnlineRecordsView(
    path: '/v1/shops/${shopId.value}/customers',
    kind: OnlineReadKind.customers,
    shopId: shopId.value,
  );
}

class OwnerCustomerPage extends ConsumerStatefulWidget {
  const OwnerCustomerPage({
    super.key,
    required this.shopId,
    required this.linkId,
  });
  final OpaqueId shopId, linkId;
  @override
  ConsumerState<OwnerCustomerPage> createState() => _OwnerCustomerPageState();
}

class _OwnerCustomerPageState extends ConsumerState<OwnerCustomerPage> {
  OwnerLinkRepository? _repository;
  LedgerRepository? _ledger;
  int _generation = 0;
  CustomerLink? _link;
  Object? _error;
  bool _loading = true, _legacyCredit = false, _legacyPayment = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final repo = ref.read(ownerLinkRepositoryProvider),
        ledger = ref.read(ledgerRepositoryProvider);
    final generation = ++_generation;
    _ledger = ledger;
    _repository = repo;
    setState(() {
      _loading = true;
      _link = null;
      _error = null;
      _legacyCredit = false;
      _legacyPayment = false;
    });
    try {
      if (repo == null && ledger is! DeviceLedgerRepository) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final link = ledger is DeviceLedgerRepository
          ? await ledger.prepareCustomer(
              widget.shopId,
              widget.linkId,
              refresh: refresh,
            )
          : await repo!.customer(widget.shopId, widget.linkId);
      if (mounted &&
          generation == _generation &&
          identical(repo, ref.read(ownerLinkRepositoryProvider)) &&
          identical(ledger, ref.read(ledgerRepositoryProvider))) {
        ref.invalidate(savedCustomersProvider);
        setState(() => _link = link);
      }
    } catch (error) {
      if (error is AppFailure &&
          error.code == 'CACHE_TOO_LARGE' &&
          ledger is DeviceLedgerRepository) {
        final credit = await ledger.pending(widget.shopId, widget.linkId);
        final payment = await ledger.pendingPayment(
          widget.shopId,
          widget.linkId,
        );
        if (mounted &&
            generation == _generation &&
            identical(ledger, ref.read(ledgerRepositoryProvider))) {
          setState(() {
            _legacyCredit = credit != null;
            _legacyPayment = payment != null;
          });
        }
      }
      if (mounted &&
          generation == _generation &&
          identical(repo, ref.read(ownerLinkRepositoryProvider)) &&
          identical(ledger, ref.read(ledgerRepositoryProvider))) {
        setState(() => _error = error);
        if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
          ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
        }
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(ownerLinkRepositoryProvider), link = _link;
    return Scaffold(
      appBar: AppBar(title: const Text('Customer ledger')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!identical(current, _repository) ||
                  !identical(_ledger, ref.watch(ledgerRepositoryProvider)))
                const Text('Please sign in and open this customer again.')
              else if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Opening customer',
                  ),
                )
              else if (link == null) ...[
                Text(
                  errorMessage(
                    _error is AppFailure
                        ? (_error as AppFailure).messageKey
                        : 'link.failed',
                  ),
                ),
                FilledButton(onPressed: _load, child: const Text('Try again')),
                if (_error is AppFailure &&
                    (_error as AppFailure).code == 'CACHE_TOO_LARGE') ...[
                  TextButton(
                    onPressed: () => context.push(
                      '/owner/history/${widget.shopId.value}/${widget.linkId.value}?source=server',
                    ),
                    child: const Text('View confirmed server history'),
                  ),
                  if (_legacyCredit)
                    TextButton(
                      onPressed: () => context.push(
                        '/owner/credit/${widget.shopId.value}/${widget.linkId.value}',
                      ),
                      child: const Text('Check saved credit'),
                    ),
                  if (_legacyPayment)
                    TextButton(
                      onPressed: () => context.push(
                        '/owner/payment/${widget.shopId.value}/${widget.linkId.value}',
                      ),
                      child: const Text('Check saved payment'),
                    ),
                ],
              ] else ...[
                Semantics(
                  header: true,
                  child: Text(
                    link.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (link.nickname != null)
                  Text('Shop nickname: ${link.nickname}'),
                const SizedBox(height: 16),
                const Text(
                  'Customer linked to your shop. Scanning and adding a customer records no credit or payment.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Customer owes you ${formatPaise(link.balance.value)} ${ref.watch(ledgerRepositoryProvider) is DeviceLedgerRepository ? '(provisional, including Pending).' : '(last server read).'}',
                ),
                if (ref.watch(ledgerRepositoryProvider)
                    is DeviceLedgerRepository)
                  const Text(
                    'Pending entries are only on this device and are not backed up to the cloud.',
                  ),
                FilledButton(
                  onPressed: () async {
                    await context.push(
                      '/owner/credit/${widget.shopId.value}/${widget.linkId.value}',
                    );
                    if (mounted) {
                      await _load();
                    }
                  },
                  child: const Text('Record credit'),
                ),
                FilledButton(
                  onPressed: () async {
                    await context.push(
                      '/owner/payment/${widget.shopId.value}/${widget.linkId.value}',
                    );
                    if (mounted) await _load();
                  },
                  child: const Text('Record payment received'),
                ),
                TextButton(
                  onPressed: () => _load(refresh: true),
                  child: const Text('Refresh balance'),
                ),
                TextButton(
                  onPressed: () => context.push(
                    '/owner/history/${widget.shopId.value}/${widget.linkId.value}',
                  ),
                  child: const Text('View transaction history'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
