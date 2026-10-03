import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_strings.dart';
import '../../core/auth/account.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import '../../app/ui/money_format.dart';
import '../../app/ui/identity_panel.dart';
import '../ledger/online_reads.dart';
import '../ledger/history_page.dart' show historyDate;
import 'statement_service.dart';
import 'statement_pdf.dart';
import 'export_csv.dart';
import 'reminder_preview.dart';
import 'share_controller.dart';

class StatementSharePage extends ConsumerStatefulWidget {
  const StatementSharePage({
    super.key,
    required this.shopId,
    required this.linkId,
  });
  final String shopId, linkId;
  @override
  ConsumerState<StatementSharePage> createState() => _StatementSharePageState();
}

class _StatementSharePageState extends ConsumerState<StatementSharePage> {
  DateTime from = statementDay(DateTime.now())
          .subtract(const Duration(days: 29)),
      to = statementDay(DateTime.now());
  AuditedStatement? statement;
  String? failure;
  bool busy = false;
  final reminder = TextEditingController();
  String? previewLanguage;
  OnlineReadRepository? preparedReader;
  int? preparedGeneration;
  @override
  void dispose() {
    reminder.dispose();
    super.dispose();
  }

  Future<void> prepare() async {
    final reader = ref.read(onlineReadRepositoryProvider);
    if (reader == null) return;
    final generation = reader.auth.sessionGeneration;
    setState(() {
      busy = true;
      failure = null;
      statement = null;
    });
    try {
      final result = await StatementRepository(reader)
          .load(widget.shopId, widget.linkId, from, to);
      if (mounted &&
          identical(reader, ref.read(onlineReadRepositoryProvider)) &&
          reader.auth.sessionGeneration == generation) {
        setState(() {
          preparedReader = reader;
          preparedGeneration = generation;
          statement = result;
          previewLanguage = AppStrings.of(context).languageCode;
          reminder.text = reminderText(result, previewLanguage!);
        });
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => failure = e.messageKey);
    } catch (_) {
      if (mounted) setState(() => failure = 'history.failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> share(String kind) async {
    final s = statement;
    if (s == null ||
        !identical(preparedReader, ref.read(onlineReadRepositoryProvider)) ||
        preparedReader?.auth.sessionGeneration != preparedGeneration) {
      return;
    }
    setState(() => busy = true);
    try {
      final reader = preparedReader!;
      final generation = reader.auth.sessionGeneration;
      bool canShare() =>
          mounted &&
          identical(reader, ref.read(onlineReadRepositoryProvider)) &&
          reader.auth.sessionGeneration == generation;
      final controller = ShareController(canShare: canShare);
      if (kind == 'reminder') {
        await controller.text(reminder.text);
      } else {
        await controller.file(
          kind == 'csv'
              ? Uint8List.fromList(utf8.encode(exportCsv(s)))
              : await statementPdf(s),
          kind,
        );
      }
    } catch (_) {
      if (mounted) setState(() => failure = 'error.generic');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(bool first) async {
    final value = await showDatePicker(
      context: context,
      initialDate: first ? from : to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (value != null) {
      setState(() {
        if (first) {
          from = statementDay(value);
        } else {
          to = statementDay(value);
        }
        statement = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppStrings.of(context), s = statement;
    if (ref.watch(sessionProvider).value?.role != AccountRole.owner) {
      return Scaffold(body: Center(child: Text(l.text('auth.forbidden'))));
    }
    // Switching the interface language intentionally rebuilds the template.
    if (s != null && previewLanguage != l.languageCode) {
      previewLanguage = l.languageCode;
      reminder.text = reminderText(s, l.languageCode);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.text('statement.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.text('statement.bounds')),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: busy ? null : () => pick(true),
                child: Text(
                  '${l.text('statement.from')}: ${from.toIso8601String().substring(0, 10)}',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: busy ? null : () => pick(false),
                child: Text(
                  '${l.text('statement.to')}: ${to.toIso8601String().substring(0, 10)}',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : prepare,
                child: Text(l.text('statement.load')),
              ),
              if (busy) const LinearProgressIndicator(),
              if (failure != null)
                Semantics(liveRegion: true, child: Text(l.text(failure!))),
              if (s != null) ...[
                IdentityPanel(displayName: s.customerName),
                const SizedBox(height: 12),
                Text('${l.translate('Shop')}: ${s.shopName}'),
                Text(
                  l.text(
                    'statement.period',
                    values: {
                      'from': s.from.toIso8601String().substring(0, 10),
                      'to': s.to.toIso8601String().substring(0, 10),
                    },
                  ),
                ),
                Text(
                  l.text(
                    'statement.opening',
                    values: {'amount': formatDisplayPaise(s.opening)},
                  ),
                ),
                Text(
                  l.text(
                    'statement.closing',
                    values: {'amount': formatDisplayPaise(s.closing)},
                  ),
                ),
                Text(
                  l.text(
                    'owner.owes',
                    values: {'amount': formatDisplayPaise(s.cloudBalance)},
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${l.translate('Server snapshot')}: ${historyDate(s.snapshotAtMs)}',
                ),
                const SizedBox(height: 12),
                Text(l.text('statement.sensitive')),
                const SizedBox(height: 16),
                TextField(
                  controller: reminder,
                  minLines: 4,
                  maxLines: 12,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l.text('reminder.label'),
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : () => share('reminder'),
                  child: Text(l.text('reminder.share')),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: busy ? null : () => share('csv'),
                  child: Text(l.text('statement.shareCsv')),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: busy ? null : () => share('pdf'),
                  child: Text(l.text('statement.sharePdf')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
