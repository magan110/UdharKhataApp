import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../settings/more_page.dart';
import '../qr/customer_qr_page.dart';
import 'customer_shops.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, this.tab = ''});
  final String tab;
  @override
  Widget build(BuildContext context) {
    final selected = tab == 'shops' ? 1 : tab == 'more' ? 2 : 0;
    final l = AppStrings.of(context);
    return PopScope(canPop: selected == 0, onPopInvokedWithResult: (didPop, result) { if (!didPop && selected != 0) context.go('/customer'); }, child: Scaffold(
      appBar: AppBar(title: Text(l.translate(selected == 0 ? 'My QR' : selected == 1 ? 'My shops' : 'More')), actions: [IconButton(onPressed: () => context.push('/settings'), tooltip: l.translate('Settings'), icon: const Icon(Icons.settings_outlined))]),
      body: SafeArea(child: switch (selected) {1 => const CustomerShopsPage(), 2 => const MorePage(role: AccountRole.customer), _ => const CustomerQrPage()}),
      bottomNavigationBar: NavigationBar(selectedIndex: selected, onDestinationSelected: (i) => context.go(i == 0 ? '/customer' : '/customer?tab=${i == 1 ? 'shops' : 'more'}'), destinations: [NavigationDestination(icon: const Icon(Icons.qr_code), label: l.translate('My QR')), NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: l.translate('My shops')), NavigationDestination(icon: const Icon(Icons.more_horiz), label: l.translate('More'))]),
    ));
  }
}
