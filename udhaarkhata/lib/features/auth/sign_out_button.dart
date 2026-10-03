import '../../app/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

class SignOutButton extends ConsumerStatefulWidget {
  const SignOutButton({super.key});
  @override
  ConsumerState<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<SignOutButton> {
  bool busy = false;
  Future<void> signOut() async {
    setState(() => busy = true);
    try {
      final count = await ref.read(authRepositoryProvider).pendingCount();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(AppStrings.of(context).translate('Sign out?')),
          content: Text(
            AppStrings.of(context).format(
              '{count} pending entries will stay on this phone, locked to this account. They are not backed up to the cloud.',
              values: {'count': '$count'},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.of(context).translate('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.of(context).translate('Sign out')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final messenger = ScaffoldMessenger.of(context),
          strings = AppStrings.of(context);
      final result = await ref.read(sessionProvider.notifier).signOut();
      if (!result.remoteRevoked) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              strings.translate(
                'Signed out on this phone. Cloud session revocation could not be confirmed.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context)
                  .translate('Could not sign out. Please try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy ? null : signOut,
    child: Text(AppStrings.of(context).translate('Sign out')),
  );
}
