import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/correction_form.dart';

class RecordingCorrections implements CorrectionRepository {
  int calls = 0;
  int? target;
  @override
  Future<void> saveCorrection(
    OpaqueId shop,
    OpaqueId link,
    String entry,
    int targetAmount,
    int revision,
    String reason,
  ) async {
    calls++;
    target = targetAmount;
    expect(revision, 0);
    expect(reason, 'Wrong amount');
  }
}

void main() {
  testWidgets(
    'Correction zero requires reason and explicit review confirmation',
    (tester) async {
      final repository = RecordingCorrections();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            correctionRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: CorrectionPage(
              shopId: 'shop',
              linkId: 'link',
              entryId: 'entry',
              effectiveAmountPaise: 10000,
              revision: 0,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.text('Review correction'));
      await tester.pump();
      expect(repository.calls, 0);
      expect(find.text('Enter a reason of 1–240 characters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Wrong amount');
      await tester.tap(find.text('Review correction'));
      await tester.pump();
      expect(repository.calls, 0);
      expect(find.text('Confirm correction'), findsOneWidget);
      await tester.tap(find.text('Confirm correction'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(repository.target, 0);
      expect(find.textContaining('Correction saved · Pending'), findsOneWidget);
    },
  );
}
