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

class CustomerList extends ConsumerWidget {
  const CustomerList({super.key, required this.shopId});
  final OpaqueId shopId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = customerLinksProvider(shopId.value);
    ref.listen(provider, (_, next) {
      if (next.error case final AppFailure error
          when error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
    });
    final customers = ref.watch(provider);
    return customers.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading customers'),
      ),
      error: (error, _) => Column(
        children: [
          Text(
            errorMessage(
              error is AppFailure ? error.messageKey : 'link.failed',
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Refresh customers'),
          ),
        ],
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.customers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No customers yet. Scan a customer QR to add them.'),
            ),
          for (final customer in data.customers)
            ListTile(
              title: Text(customer.nickname ?? customer.displayName),
              subtitle: Text(
                customer.nickname == null
                    ? 'Customer owes you ${formatPaise(customer.balance.value)}'
                    : '${customer.displayName} — Customer owes you ${formatPaise(customer.balance.value)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/owner/customer/${shopId.value}/${customer.id.value}',
              ),
            ),
          if (data.hasMore)
            const Text(
              'Showing the first 100 customers. Scan a customer QR to open a customer outside this list.',
            ),
          TextButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Refresh customers'),
          ),
        ],
      ),
    );
  }
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
  CustomerLink? _link;
  Object? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(ownerLinkRepositoryProvider);
    _repository = repo;
    setState(() {
      _loading = true;
      _link = null;
      _error = null;
    });
    try {
      if (repo == null) {
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      final link = await repo.customer(widget.shopId, widget.linkId);
      if (mounted && identical(repo, ref.read(ownerLinkRepositoryProvider))) {
        setState(() => _link = link);
      }
    } catch (error) {
      if (mounted && identical(repo, ref.read(ownerLinkRepositoryProvider))) {
        setState(() => _error = error);
        if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
          ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
              if (!identical(current, _repository))
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
                  'Customer owes you ${formatPaise(link.balance.value)} (last server read).',
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
                  onPressed: _load,
                  child: const Text('Refresh balance'),
                ),
                const Text(
                  'Full transaction history will be available in D10.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
