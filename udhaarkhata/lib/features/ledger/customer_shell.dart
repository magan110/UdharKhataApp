import '../auth/sign_out_button.dart';
import '../../app/status_page.dart';

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
      title: Text(_selected == 0 ? 'My QR' : 'My shops'),
      actions: const [SignOutButton()],
    ),
    body: _selected == 0
        ? const CustomerQrPage()
        : const StatusPage(
            title: 'Your shops',
            message: 'No shops are linked to this account.',
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: (value) => setState(() => _selected = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.qr_code), label: 'My QR'),
        NavigationDestination(icon: Icon(Icons.storefront), label: 'My shops'),
      ],
    ),
  );
}
