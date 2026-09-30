import '../../app/status_page.dart';

import 'package:flutter/material.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key});
  @override
  Widget build(BuildContext context) => const StatusPage(
    title: 'Your shops',
    message: 'No shops are linked to this account.',
  );
}
