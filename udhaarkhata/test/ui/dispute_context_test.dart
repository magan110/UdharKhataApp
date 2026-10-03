import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/disputes/dispute_page.dart';
import 'package:udhaarkhata/features/disputes/dispute_repository.dart';
import 'package:udhaarkhata/features/disputes/dispute_entry_context.dart';

import '../history_ui_test.dart' show HistoryAuth;
import '../auth_session_test.dart' show MemorySecureStorage;

class RecordingDisputes extends CloudDisputeRepository {
  RecordingDisputes()
    : super(
        HistoryAuth(AccountRole.owner),
        OpaqueId.fromJson('usr_synthetic'),
        storage: MemorySecureStorage(),
      );
  String? resolvedId, note;
  @override
  Future<DisputeSnapshot> load(String shopId, bool customer) async =>
      DisputeSnapshot([
        for (var i = 1; i <= 2; i++)
          Dispute({
            'id': 'dispute$i',
            'shopId': 'shop',
            'entryId': 'entry$i',
            'customerUserId': 'customer',
            'reason': 'Reason $i',
            'status': 'open',
            'createdAtMs': 1,
            'resolvedAtMs': null,
            'resolutionNote': null,
          }),
      ], false);
  @override
  Future<void> resolve(String shopId, String id, String text) async {
    resolvedId = id;
    note = text;
  }
}

void main() {
  testWidgets(
    'wrong context uses ID and response resolves selected second card',
    (tester) async {
      final repo = RecordingDisputes();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              HistoryAuth(AccountRole.owner),
            ),
            disputeRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: DisputePage(
              shopId: 'shop',
              customer: false,
              entryContext: DisputeEntryContext(
                accountId: 'another',
                shopId: 'shop',
                entryId: 'entry1',
                kind: 'credit',
                amountPaise: 1245000,
                occurredAtMs: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('₹12,450.00'), findsNothing);
      expect(find.textContaining('entry1'), findsWidgets);
      await tester.ensureVisible(find.text('Resolve').last);
      await tester.tap(find.text('Resolve').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Resolution note'),
        'Checked second entry',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Resolve dispute'));
      await tester.pumpAndSettle();
      expect(repo.resolvedId, 'dispute2');
      expect(repo.note, 'Checked second entry');
    },
  );
  test('context exact scope matching', () {
    const c = DisputeEntryContext(
      accountId: 'a',
      shopId: 's',
      entryId: 'e',
      kind: 'credit',
      amountPaise: 1,
      occurredAtMs: 1,
    );
    expect(c.matches(accountId: 'a', shopId: 's', entryId: 'e'), isTrue);
    expect(c.matches(accountId: 'b', shopId: 's', entryId: 'e'), isFalse);
  });
}
