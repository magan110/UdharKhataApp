import '../auth/sign_out_button.dart';
import '../../app/status_page.dart';

import 'package:flutter/material.dart';

class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: const [SignOutButton()]),
    body: const StatusPage(
      title: 'Your shop',
      message: 'No shop is connected to this account.',
    ),
  );
}
