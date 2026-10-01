import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_strings.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import 'qr_repository.dart';

class CustomerQrPage extends ConsumerWidget {
  const CustomerQrPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(qrProvider, (_, next) {
      final error = next.error;
      if (error is AppFailure && error.code == 'AUTH_REQUIRED') {
        ref.read(sessionProvider.notifier).refreshAfterAuthFailure();
      }
    });
    final state = ref.watch(qrProvider);
    final account = ref.watch(sessionProvider).value;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Show this to the shopkeeper',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            state.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Checking your QR',
                ),
              ),
              error: (error, _) => Text(
                errorMessage(
                  error is AppFailure ? error.messageKey : 'api.internalError',
                ),
                textAlign: TextAlign.center,
              ),
              data: (value) => Column(
                children: [
                  Semantics(
                    label: 'Customer identification QR. Show this to the shopkeeper. It does not authorize a payment.',
                    child: ExcludeSemantics(
                      child: QrImageView(
                        data: value.record.qr.payload,
                        size: 256,
                        padding: const EdgeInsets.all(32),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (value.needsSignIn)
                    const Text(
                      'Sign in again to check or replace your QR. This saved code has not been verified online.',
                      textAlign: TextAlign.center,
                    ),
                  if (value.record.noticeKey != null)
                    Text(
                      value.record.noticeKey == 'qr.rotationRecovered'
                          ? errorMessage(value.record.noticeKey!)
                          : 'QR replacement failed. ${errorMessage(value.record.noticeKey!)}',
                      textAlign: TextAlign.center,
                    ),
                  Text(
                    account?.displayName ?? 'Your customer account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value.cached
                        ? 'Saved QR — not checked online. It may have changed on another phone.'
                        : 'QR checked online.',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Last checked: ${DateTime.fromMillisecondsSinceEpoch(value.record.checkedAtMs).toLocal().toString().split('.').first}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This QR identifies your account. The shopkeeper confirms your identity and enters the amount. It is not a payment QR.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.isLoading
                  ? null
                  : state.value?.needsSignIn == true
                  ? () => ref.invalidate(sessionProvider)
                  : () => ref.read(qrProvider.notifier).refresh(),
              child: Text(
                state.value?.needsSignIn == true
                    ? 'Sign in again'
                    : 'Refresh QR',
              ),
            ),
            OutlinedButton(
              onPressed:
                  state.isLoading ||
                      state.hasError ||
                      state.value?.needsSignIn == true
                  ? null
                  : () async {
                      final repo = ref.read(qrRepositoryProvider);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Replace your QR?'),
                          content: const Text(
                            'Internet is required. The old QR will stop working for new shop links. Your existing shop ledgers will remain.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Replace'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true &&
                          context.mounted &&
                          identical(repo, ref.read(qrRepositoryProvider))) {
                        await ref
                            .read(qrProvider.notifier)
                            .refresh(rotate: true);
                      }
                    },
              child: const Text('Replace QR'),
            ),
          ],
        ),
      ),
    );
  }
}
