import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/network/app_failure.dart';
import 'resolve_controller.dart';

class LinkConfirmation extends StatefulWidget {
  const LinkConfirmation({super.key, required this.controller});
  final ResolveController controller;
  @override
  State<LinkConfirmation> createState() => _LinkConfirmationState();
}

class _LinkConfirmationState extends State<LinkConfirmation> {
  final _nickname = TextEditingController();
  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller,
        recovery = state.attempt != null,
        saving = state.stage == ScanStage.saving;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            recovery ? 'Check customer link' : 'Confirm customer',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              state.attempt?.displayName ?? state.customer!.displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            recovery
                ? 'Your previous confirmation may have succeeded. Connect to the internet and check the same request.'
                : 'Check that this is the customer in front of you. A copied QR does not prove identity. Adding a customer records no credit or payment.',
          ),
          const SizedBox(height: 24),
          if (!recovery)
            TextField(
              controller: _nickname,
              maxLength: 120,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Shop nickname (optional)',
              ),
            ),
          if (recovery && state.attempt!.nickname != null)
            Text('Shop nickname: ${state.attempt!.nickname}'),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  errorMessage(
                    state.error is AppFailure
                        ? (state.error as AppFailure).messageKey
                        : 'link.failed',
                  ),
                ),
              ),
            ),
          FilledButton(
            onPressed: saving ? null : () => state.confirm(_nickname.text),
            child: Text(
              saving
                  ? 'Checking customer link…'
                  : recovery
                  ? 'Check previous request'
                  : 'Add customer',
            ),
          ),
          if (!recovery)
            TextButton(
              onPressed: saving ? null : state.rescan,
              child: const Text('Cancel and scan again'),
            ),
        ],
      ),
    );
  }
}
