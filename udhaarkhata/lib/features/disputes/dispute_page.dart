import '../../app/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/app_failure.dart';
import '../ledger/history_page.dart' show historyDate;
import 'dispute_repository.dart';

class DisputePage extends ConsumerStatefulWidget {
  const DisputePage({
    super.key,
    required this.shopId,
    required this.customer,
    this.entryId,
  });
  final String shopId;
  final bool customer;
  final String? entryId;
  @override
  ConsumerState<DisputePage> createState() => _DisputePageState();
}

class _DisputePageState extends ConsumerState<DisputePage> {
  final _text = TextEditingController();
  DisputeSnapshot? _snapshot;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(disputeRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _snapshot = null;
    });
    try {
      final snapshot = await repo.load(widget.shopId, widget.customer);
      if (mounted && identical(repo, ref.read(disputeRepositoryProvider))) {
        setState(() => _snapshot = snapshot);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is AppFailure && error.code == 'DISPUTE_LIST_INCOMPLETE'
              ? 'The complete dispute list exceeds this device limit. No partial list is shown.'
              : 'Disputes could not be loaded.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act([Dispute? dispute]) async {
    final repo = ref.read(disputeRepositoryProvider);
    if (_busy || repo == null || _snapshot?.offline != false) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (dispute == null) {
        await repo.create(widget.shopId, widget.entryId!, _text.text);
      } else {
        await repo.resolve(widget.shopId, dispute.id, _text.text);
      }
      _text.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Request not confirmed. Refresh status before trying again. Use a reason or resolution note of 1–240 characters.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(disputeRepositoryProvider, (_, _) {
      if (mounted) setState(() => _snapshot = null);
    });
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context).translate('Disputes'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context).translate(
                'Disputes do not change the balance. The owner records any financial correction separately.',
              ),
            ),
            if (snapshot?.offline == true)
              Text(
                AppStrings.of(context).translate(
                  'Offline · Cached status · Read only. Refresh online for newer changes.',
                ),
              ),
            if (snapshot != null) ...[
              for (final d in snapshot.items.where(
                (d) =>
                    d.shopId == widget.shopId &&
                    (widget.entryId == null || d.entryId == widget.entryId),
              ))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${AppStrings.of(context).translate(d.status.name)} · ${AppStrings.of(context).translate('Entry')} ${d.entryId}',
                        ),
                        Text(d.reason),
                        Text(
                          '${AppStrings.of(context).translate('Created')}: ${historyDate(d.createdAtMs)}',
                        ),
                        if (d.resolutionNote != null)
                          Text(
                            '${AppStrings.of(context).translate('Resolution')}: ${d.resolutionNote} · ${historyDate(d.resolvedAtMs!)}',
                          ),
                        if (!widget.customer &&
                            !snapshot.offline &&
                            d.status == DisputeStatus.open)
                          FilledButton(
                            onPressed: _busy ? null : () => _act(d),
                            child: Text(
                              AppStrings.of(context)
                                  .translate('Resolve with note below'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (!snapshot.offline)
                TextField(
                  controller: _text,
                  maxLength: 240,
                  decoration: InputDecoration(
                    labelText: widget.customer
                        ? AppStrings.of(context).translate('Dispute reason')
                        : AppStrings.of(context).translate('Resolution note'),
                  ),
                ),
              if (widget.customer &&
                  widget.entryId != null &&
                  !snapshot.offline)
                FilledButton(
                  onPressed: _busy ? null : () => _act(),
                  child: Text(
                    AppStrings.of(context).translate('Raise dispute'),
                  ),
                ),
            ],
            if (_error != null) Text(AppStrings.of(context).translate(_error!)),
            if (_busy) const Center(child: CircularProgressIndicator()),
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(AppStrings.of(context).translate('Refresh disputes')),
            ),
          ],
        ),
      ),
    );
  }
}
