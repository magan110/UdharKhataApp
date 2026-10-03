import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import '../ledger/local_ledger_view.dart';
import '../ledger/sync_status_view.dart';
import '../settings/more_page.dart';
import 'shop_repository.dart';
import 'owner_home_view.dart';
import 'owner_customers_view.dart';

class OwnerShell extends ConsumerWidget {
  const OwnerShell({super.key, this.tab = ''});
  final String tab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentShopProvider, (_, next) {
      final error = next.error;
      if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
    });
    final shop = ref.watch(currentShopProvider);
    final selected = tab == 'customers'
        ? 1
        : tab == 'more'
        ? 2
        : 0;
    final l = AppStrings.of(context);
    return PopScope(
      canPop: selected == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected != 0) context.go('/owner');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            selected == 0
                ? 'Udhaar Khata'
                : l.translate(selected == 1 ? 'Customers' : 'More'),
          ),
          actions: [
            IconButton(
              tooltip: l.translate('Settings and data controls'),
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: shop.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                semanticsLabel: l.translate('Opening shop'),
              ),
            ),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SyncStatusView(),
                Text(
                  l.translate('Could not open your shop'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  errorMessage(
                    error is AppFailure
                        ? error.messageKey
                        : 'api.internalError',
                    languageCode: l.languageCode,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(currentShopProvider),
                  child: Text(l.translate('Try again')),
                ),
                if (error is AppFailure &&
                    (error.retryable || error.code == 'NETWORK_ERROR'))
                  const SavedCustomersView(),
              ],
            ),
            data: (value) => value == null
                ? const ShopSetup()
                : switch (selected) {
                    1 => OwnerCustomersView(shop: value),
                    2 => MorePage(
                      role: AccountRole.owner,
                      shopId: value.id.value,
                    ),
                    _ => OwnerHomeView(
                      shop: value,
                      onViewAll: () => context.go('/owner?tab=customers'),
                      onSyncDetails: () => context.go('/owner?tab=more'),
                    ),
                  },
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => context.go(
            i == 0 ? '/owner' : '/owner?tab=${i == 1 ? 'customers' : 'more'}',
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l.translate('Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              label: l.translate('Customers'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz),
              label: l.translate('More'),
            ),
          ],
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
      padding: EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context).translate('Set up your shop'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              AppStrings.of(context).translate(
                'Your customers will see this name beside their ledger. One shop per owner in this version. Internet is needed for setup.',
              ),
            ),
            SizedBox(height: 24),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).translate('Shop name'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? AppStrings.of(context).translate('Enter your shop name.')
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  errorMessage(
                    _error is AppFailure
                        ? (_error as AppFailure).messageKey
                        : 'api.internalError',
                    languageCode: AppStrings.of(context).languageCode,
                  ),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(
                AppStrings.of(context)
                    .translate(_saving ? 'Creating shop…' : 'Create shop'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
