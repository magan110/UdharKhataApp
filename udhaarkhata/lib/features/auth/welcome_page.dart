import '../../app/app_strings.dart';

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
          padding: EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 24),
                Text(
                  AppStrings.of(context).translate('Udhaar Khata'),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 12),
                Text(
                  AppStrings.of(context)
                      .translate('A simple record of customer credit.'),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                SegmentedButton<AccountRole>(
                  segments: [
                    ButtonSegment(
                      value: AccountRole.owner,
                      label: Text(
                        AppStrings.of(context).translate('Shop owner'),
                      ),
                    ),
                    ButtonSegment(
                      value: AccountRole.customer,
                      label: Text(AppStrings.of(context).translate('Customer')),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (value) =>
                      setState(() => role = value.single),
                ),
                SizedBox(height: 16),
                FilledButton(
                  onPressed: ref.watch(authRepositoryProvider).canSignIn
                      ? () => ref.read(sessionProvider.notifier).signIn(role)
                      : null,
                  child: Text(
                    AppStrings.of(context).translate('Continue with Google'),
                  ),
                ),
                SizedBox(height: 12),
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
