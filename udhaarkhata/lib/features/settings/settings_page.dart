import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../../app/localization.dart';
import '../../core/auth/account.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import '../shop/shop_repository.dart';
import '../ledger/online_reads.dart';
import '../ledger/device_ledger_repository.dart';
import '../ledger/ledger_repository.dart';
import '../ledger/history_page.dart' show historyDate;
import '../sharing/share_controller.dart';
import 'privacy_repository.dart';
import '../disputes/dispute_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        AppStrings.of(context).translate('Settings and data controls'),
      ),
    ),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SettingsBody(),
      ),
    ),
  );
}

class SettingsBody extends ConsumerStatefulWidget {
  const SettingsBody({super.key});
  @override
  ConsumerState<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<SettingsBody> {
  List<DataRequest> _requests = [];
  Object? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    ref.listenManual(privacyRepositoryProvider, (previous, next) {
      setState(() {
        _requests = [];
        _error = null;
        _busy = false;
      });
      if (next != null) Future.microtask(_load);
    }, fireImmediately: true);
  }

  Future<void> _load() async {
    final repo = ref.read(privacyRepositoryProvider);
    if (repo == null) return;
    setState(() => _busy = true);
    try {
      final result = await repo.list();
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        setState(() {
          _requests = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit(String kind, {String? shopId}) async {
    final strings = AppStrings.of(context),
        repo = ref.read(privacyRepositoryProvider);
    if (repo == null || _busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(strings.translate('Submit data request?')),
        content: Text(
          strings.translate(
            'A request is tracked for review. It does not immediately delete your account or financial history.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.translate('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.translate('Submit request')),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !mounted ||
        !identical(repo, ref.read(privacyRepositoryProvider))) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.submit(kind, shopId: shopId);
      await _load();
    } catch (error) {
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _shareDeviceCopy() async {
    final ledger = ref.read(ledgerRepositoryProvider);
    if (ledger is! DeviceLedgerRepository) return;
    final generation = ledger.auth.sessionGeneration;
    final rows = await ledger.outbox();
    if (!mounted || !identical(ledger, ref.read(ledgerRepositoryProvider))) {
      return;
    }
    final strings = AppStrings.of(context);
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(strings.translate('Share device-only entries?')),
        content: Text(
          strings.translate(
            'This copy contains private financial data and original Pending or Needs attention requests. It is not proof of a server balance. Choose a trusted recipient. Keep this app data until all entries are resolved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.translate('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.translate('Share reviewed copy')),
          ),
        ],
      ),
    );
    if (accept != true ||
        !mounted ||
        !identical(ledger, ref.read(ledgerRepositoryProvider))) {
      return;
    }
    try {
      await ShareController(
        canShare: () =>
            mounted &&
            identical(ledger, ref.read(ledgerRepositoryProvider)) &&
            generation == ledger.auth.sessionGeneration,
      ).text(
        jsonEncode({
          'type': 'device-only-unacknowledged-requests',
          'cloudBackedUp': false,
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
          'requests': [
            for (final row in rows)
              if (row['state'] != 'synced')
                {
                  'operationId': row['operation_id'],
                  'state': row['state'],
                  'createdAtMs': row['created_at_ms'],
                  'originalPayload': row['payload'],
                  'errorCode': row['error_code'],
                },
          ],
        }),
      );
    } catch (error) {
      if (mounted && identical(ledger, ref.read(ledgerRepositoryProvider))) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context),
        account = ref.watch(sessionProvider).asData?.value;
    final shop = account?.role == AccountRole.owner
        ? ref.watch(currentShopProvider).asData?.value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.text('language'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        DropdownButtonFormField<String>(
          initialValue: strings.languageCode,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(localeProvider.notifier).setLanguageCode(value);
            }
          },
        ),
        TextButton(
          onPressed: () => context.push('/recovery'),
          child: Text(strings.text('help')),
        ),
        Text(
          strings.translate(
            'Pending entries are only on this device and are not backed up to the cloud.',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          strings.translate('Data requests'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          strings.translate(
            'Requests are reviewed. Historical financial records are retained until the approved privacy policy and operator process permit deletion. This test version does not perform destructive deletion.',
          ),
        ),
        if (account?.role == AccountRole.owner && shop != null) ...[
          TextButton(
            onPressed: _busy
                ? null
                : () => _submit('export', shopId: shop.id.value),
            child: Text(strings.translate('Request shop data export')),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _submit('shop_deletion', shopId: shop.id.value),
            child: Text(strings.translate('Request shop deletion')),
          ),
          TextButton(
            onPressed: _busy ? null : _shareDeviceCopy,
            child: Text(strings.translate('Export device-only requests')),
          ),
        ],
        TextButton(
          onPressed: _busy ? null : () => _submit('account_deletion'),
          child: Text(strings.translate('Request account deletion')),
        ),
        TextButton(
          onPressed: _busy ? null : _load,
          child: Text(strings.translate('Refresh request status')),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              errorMessage(
                _error is AppFailure
                    ? (_error as AppFailure).messageKey
                    : 'api.internalError',
                languageCode: strings.languageCode,
              ),
            ),
          ),
        if (ref.watch(privacyRepositoryProvider)?.latestListIncomplete == true)
          Text(
            strings.translate(
              'More requests exist. This list shows the latest 100.',
            ),
          ),
        for (final item in _requests)
          ListTile(
            title: Text(
              strings.translate(switch (item.kind) {
                'export' => 'Data export',
                'shop_deletion' => 'Shop deletion',
                'account_deletion' => 'Account deletion',
                _ => 'Shop access removal',
              }),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${strings.translate(switch (item.status) {
                    'submitted' => 'Submitted',
                    'in_review' => 'Under review',
                    'completed' => 'Completed',
                    _ => 'Denied',
                  })} · ${historyDate(item.createdAtMs)}',
                ),
                Text(strings.translate('Request ID')),
                SelectableText(item.id),
              ],
            ),
          ),
      ],
    );
  }
}

class AccessRemovalButton extends ConsumerStatefulWidget {
  const AccessRemovalButton({super.key, required this.shopId});
  final String shopId;
  @override
  ConsumerState<AccessRemovalButton> createState() => _AccessRemovalState();
}

class _AccessRemovalState extends ConsumerState<AccessRemovalButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: _busy ? null : _remove,
    child: Text(
      AppStrings.of(context).translate('Remove my access to this shop'),
    ),
  );
  Future<void> _remove() async {
    final strings = AppStrings.of(context),
        repo = ref.read(privacyRepositoryProvider);
    if (repo == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(strings.translate('Remove shop access?')),
        content: Text(
          strings.translate(
            'You will no longer see this shop ledger. The owner keeps the original financial history. Relinking is unavailable until the privacy policy is reviewed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.translate('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.translate('Remove access')),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !mounted ||
        !identical(repo, ref.read(privacyRepositoryProvider))) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.removeAccess(widget.shopId);
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        ref.invalidate(disputeRepositoryProvider);
        ref.invalidate(onlineReadRepositoryProvider);
        context.go('/customer');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage(
                error is AppFailure ? error.messageKey : 'api.internalError',
                languageCode: strings.languageCode,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && identical(repo, ref.read(privacyRepositoryProvider))) {
        setState(() => _busy = false);
      }
    }
  }
}
