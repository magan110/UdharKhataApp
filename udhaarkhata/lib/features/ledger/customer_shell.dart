import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../auth/sign_out_button.dart';
import 'customer_shops.dart';

import 'package:flutter/material.dart';

import '../qr/customer_qr_page.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        AppStrings.of(context).translate(_selected == 0 ? 'My QR' : 'My shops'),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          tooltip: AppStrings.of(context).translate('Settings'),
          icon: const Icon(Icons.settings),
        ),
        SignOutButton(),
      ],
    ),
    body: SafeArea(
      child: _selected == 0 ? CustomerQrPage() : CustomerShopsPage(),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: (value) => setState(() => _selected = value),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.qr_code),
          label: AppStrings.of(context).translate('My QR'),
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront),
          label: AppStrings.of(context).translate('My shops'),
        ),
      ],
    ),
  );
}
