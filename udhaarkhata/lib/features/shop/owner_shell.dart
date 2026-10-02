import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'customer_list.dart';
import '../ledger/history_page.dart';
import '../ledger/online_reads.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/sign_out_button.dart';
import '../../app/status_page.dart';
import '../../app/app_strings.dart';
import '../../core/network/app_failure.dart';
import 'shop_repository.dart';
import '../auth/session_controller.dart';

class OwnerShell extends ConsumerWidget {
  const OwnerShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentShopProvider, (_, next) {
      final error = next.error;
      if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
    });
    final shop = ref.watch(currentShopProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your shop'),
        actions: const [SignOutButton()],
      ),
      body: shop.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Opening shop'),
        ),
        error: (error, _) => StatusPage(
          title: 'Could not open your shop',
          message: errorMessage(
            error is AppFailure ? error.messageKey : 'api.internalError',
          ),
          onRetry: () => ref.invalidate(currentShopProvider),
        ),
        data: (value) => value == null
            ? const ShopSetup()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      value.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    OnlineRecordsView(
                      path: '/v1/shops/${value.id.value}',
                      kind: OnlineReadKind.summary,
                      shopId: value.id.value,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/owner/scan/${value.id.value}'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan customer QR'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Customers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    CustomerList(shopId: value.id),
                  ],
                ),
              ),
      ),
    );
  }
}

class ShopSetup extends ConsumerStatefulWidget {
  const ShopSetup({super.key});
  @override
  ConsumerState<ShopSetup> createState() => _ShopSetupState();
}

class _ShopSetupState extends ConsumerState<ShopSetup> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  Object? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || !_form.currentState!.validate()) return;
    final repository = ref.read(shopRepositoryProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repository.createShop(_name.text);
      if (mounted && identical(repository, ref.read(shopRepositoryProvider))) {
        ref.invalidate(currentShopProvider);
      }
    } catch (error) {
      if (mounted && error is AppFailure && error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set up your shop',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your customers will see this name beside their ledger. One shop per owner in this version. Internet is needed for setup.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Shop name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your shop name.'
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  errorMessage(
                    _error is AppFailure
                        ? (_error as AppFailure).messageKey
                        : 'api.internalError',
                  ),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? 'Creating shop…' : 'Create shop'),
            ),
          ],
        ),
      ),
    ),
  );
}
