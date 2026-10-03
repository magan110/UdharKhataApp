import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../ledger/sync_status_view.dart';
import '../auth/sign_out_button.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.role, this.shopId});
  final AccountRole role;
  final String? shopId;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    if (role == AccountRole.owner) ...[Text(AppStrings.of(context).translate('Sync and saved entries'), style: Theme.of(context).textTheme.titleLarge), const SyncStatusView(), if (shopId != null) ListTile(leading: const Icon(Icons.chat_bubble_outline), title: Text(AppStrings.of(context).translate('Disputes')), onTap: () => context.push('/owner/disputes/$shopId'))],
    ListTile(leading: const Icon(Icons.settings_outlined), title: Text(AppStrings.of(context).translate('Settings and data controls')), onTap: () => context.push('/settings')),
    ListTile(leading: const Icon(Icons.help_outline), title: Text(AppStrings.of(context).text('help')), onTap: () => context.push('/recovery')),
    const SignOutButton(),
  ]);
}
