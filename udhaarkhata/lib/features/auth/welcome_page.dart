import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/account.dart';
import 'session_controller.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  AccountRole role = AccountRole.owner;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Udhaar Khata',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'A simple record of customer credit.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SegmentedButton<AccountRole>(
                  segments: const [
                    ButtonSegment(
                      value: AccountRole.owner,
                      label: Text('Shop owner'),
                    ),
                    ButtonSegment(
                      value: AccountRole.customer,
                      label: Text('Customer'),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (value) =>
                      setState(() => role = value.single),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: ref.watch(authRepositoryProvider).canSignIn
                      ? () => ref.read(sessionProvider.notifier).signIn(role)
                      : null,
                  child: const Text('Continue with Google'),
                ),
                const SizedBox(height: 12),
                Text(
                  ref.watch(authRepositoryProvider).canSignIn
                      ? 'Your account role is fixed when you first register.'
                      : 'Sign-in needs the approved Google configuration.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
