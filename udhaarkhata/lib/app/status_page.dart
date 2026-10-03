import 'app_strings.dart';
import 'ui/state_panel.dart';

import 'package:flutter/material.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppStrings.of(context).translate('Udhaar Khata'))),
    body: SafeArea(child: Center(child: SingleChildScrollView(child: StatePanel(title: title, message: message, loading: loading, actionLabel: onRetry == null ? null : AppStrings.of(context).translate('Try again'), onAction: onRetry)))),
  );
}
