import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../ledger/sync_status_view.dart';
import '../auth/sign_out_button.dart';
import 'settings_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.role, this.shopId});
  final AccountRole role;
  final String? shopId;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (role == AccountRole.owner) ...[
          Text(
            AppStrings.of(context).translate('Sync and saved entries'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SyncStatusView(),
          if (shopId != null)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(AppStrings.of(context).translate('Disputes')),
              onTap: () => context.push('/owner/disputes/$shopId'),
            ),
        ],
        const SizedBox(height: 24),
        const SettingsBody(),
        const SizedBox(height: 24),
        const SignOutButton(),
      ],
    ),
  );
}
