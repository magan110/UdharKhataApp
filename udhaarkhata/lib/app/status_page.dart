import 'app_strings.dart';

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
    appBar: AppBar(
      title: Text(AppStrings.of(context).translate('Udhaar Khata')),
    ),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                CircularProgressIndicator(
                  semanticsLabel: AppStrings.of(context)
                      .translate('Opening account'),
                ),
              SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(AppStrings.of(context).translate('Try again')),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
