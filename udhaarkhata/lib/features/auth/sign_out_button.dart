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
          title: const Text('Sign out?'),
          content: Text(
            '$count pending entries will stay on this phone, locked to this account. They are not backed up to the cloud.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final result = await ref.read(sessionProvider.notifier).signOut();
      if (!result.remoteRevoked) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Signed out on this phone. Cloud session revocation could not be confirmed.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
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
    child: const Text('Sign out'),
  );
}
