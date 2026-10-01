import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';

final customerShopsProvider = FutureProvider.autoDispose<CustomerShops>((
  ref,
) async {
  final account = await ref.watch(sessionProvider.future);
  if (account == null || account.role != AccountRole.customer) {
    throw const AppFailure('AUTH_REQUIRED', 'auth.required');
  }
  final profile = jsonObject(
    await ref.watch(authRepositoryProvider).cloudRequest(account.id, '/v1/me'),
  );
  final links = profile['links'];
  final hasMore = profile['linksHasMore'];
  if (links is! List || links.length > 100 || hasMore is! bool) {
    throw const FormatException('Invalid shop list');
  }
  return CustomerShops([
    for (final value in links) CustomerShop.fromJson(value),
  ], hasMore);
}, retry: (_, _) => null);

class CustomerShop {
  const CustomerShop(this.linkId, this.shopId, this.name);
  final OpaqueId linkId, shopId;
  final String name;
  factory CustomerShop.fromJson(Object? value) {
    final row = jsonObject(value);
    return CustomerShop(
      OpaqueId.fromJson(row['id']),
      OpaqueId.fromJson(row['shopId']),
      jsonString(row['shopName']),
    );
  }
}

class CustomerShops {
  const CustomerShops(this.shops, this.hasMore);
  final List<CustomerShop> shops;
  final bool hasMore;
}

class CustomerShopsPage extends ConsumerStatefulWidget {
  const CustomerShopsPage({super.key});
  @override
  ConsumerState<CustomerShopsPage> createState() => _CustomerShopsPageState();
}

class _CustomerShopsPageState extends ConsumerState<CustomerShopsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      ref.invalidate(customerShopsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(customerShopsProvider, (_, next) {
      if (next.error case final AppFailure error
          when error.code == 'AUTH_REQUIRED') {
        ref.invalidate(sessionProvider);
      }
    });
    return ref
        .watch(customerShopsProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading shops'),
          ),
          error: (error, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorMessage(
                    error is AppFailure ? error.messageKey : 'link.failed',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(customerShopsProvider),
                child: const Text('Refresh shops'),
              ),
            ],
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerShopsProvider);
              try {
                await ref.read(customerShopsProvider.future);
              } catch (_) {
                // The provider renders the failure; finish the refresh indicator.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (data.shops.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No shops are linked to this account.'),
                  ),
                for (final shop in data.shops)
                  ListTile(
                    leading: const Icon(Icons.storefront),
                    title: Text(shop.name),
                    subtitle: const Text('Linked shop'),
                  ),
                if (data.hasMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Showing the first 100 linked shops.'),
                  ),
                TextButton(
                  onPressed: () => ref.invalidate(customerShopsProvider),
                  child: const Text('Refresh shops'),
                ),
              ],
            ),
          ),
        );
  }
}
