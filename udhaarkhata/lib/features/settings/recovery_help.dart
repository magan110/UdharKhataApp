import '../../app/app_strings.dart';

import 'package:flutter/material.dart';

/// The recovery boundary is server acknowledgement, never device backup.
class RecoveryHelpPage extends StatelessWidget {
  const RecoveryHelpPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppStrings.of(context).translate('New phone and recovery')),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context).translate(
                'Sign in with the same Google account on your new phone while connected to the internet. Open your ledgers to download server-acknowledged records.',
              ),
            ),
            SizedBox(height: 16),
            Text(
              AppStrings.of(context).translate(
                'Pending entries exist only on the phone where they were saved. If that phone is lost, damaged, or its app data is cleared before sync, the server cannot restore those entries.',
              ),
            ),
            SizedBox(height: 16),
            Text(
              AppStrings.of(context).translate(
                'Before changing phones, connect the old phone, retry sync, and check that no entries remain Pending or Needs attention. Do not recreate uncertain entries without checking the confirmed history.',
              ),
            ),
            SizedBox(height: 16),
            Text(
              AppStrings.of(context).translate(
                'Offline customer views show the last successful server snapshot. Newer owner changes may be missing until you reconnect and refresh.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
