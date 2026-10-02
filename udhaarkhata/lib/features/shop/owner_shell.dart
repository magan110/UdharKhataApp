import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'customer_list.dart';
import '../ledger/history_page.dart';
import '../ledger/online_reads.dart';
import '../ledger/local_ledger_view.dart';
import '../ledger/ledger_repository.dart';
import '../ledger/device_ledger_repository.dart';
import '../ledger/sync_status_view.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/sign_out_button.dart';
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
        title: Text(AppStrings.of(context).translate('Your shop')),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context)
                .translate('Settings and data controls'),
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings),
          ),
          SignOutButton(),
        ],
      ),
      body: shop.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: AppStrings.of(context).translate('Opening shop'),
          ),
        ),
        error: (error, _) => SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SyncStatusView(),
              Text(
                AppStrings.of(context).translate('Could not open your shop'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                errorMessage(
                  error is AppFailure ? error.messageKey : 'api.internalError',
                  languageCode: AppStrings.of(context).languageCode,
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(currentShopProvider),
                child: Text(AppStrings.of(context).translate('Try again')),
              ),
              if (error is AppFailure &&
                  (error.retryable || error.code == 'NETWORK_ERROR'))
                SavedCustomersView(),
            ],
          ),
        ),
        data: (value) => value == null
            ? ShopSetup()
            : SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SyncStatusView(),
                    Text(
                      value.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 24),
                    if (ref.watch(ledgerRepositoryProvider)
                        is DeviceLedgerRepository)
                      Text(
                        AppStrings.of(context).translate(
                          'Server totals include Synced entries only. Pending entries are only on this device.',
                        ),
                      ),
                    OnlineRecordsView(
                      path: '/v1/shops/${value.id.value}',
                      kind: OnlineReadKind.summary,
                      shopId: value.id.value,
                    ),
                    SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/owner/scan/${value.id.value}'),
                      icon: Icon(Icons.qr_code_scanner),
                      label: Text(
                        AppStrings.of(context).translate('Scan customer QR'),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push('/owner/disputes/${value.id.value}'),
                      child: Text(AppStrings.of(context).translate('Disputes')),
                    ),
                    SizedBox(height: 24),
                    Text(
                      AppStrings.of(context).translate('Customers'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    CustomerList(shopId: value.id),
                    SavedCustomersView(),
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
                  ? 'Enter your shop name.'
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
              child: Text(_saving ? 'Creating shop…' : 'Create shop'),
            ),
          ],
        ),
      ),
    ),
  );
}
