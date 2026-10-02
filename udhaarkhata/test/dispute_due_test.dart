import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/features/disputes/dispute_repository.dart';
import 'package:udhaarkhata/features/ledger/due_summary.dart';

void main() {
  final dispute = {
    'id': 'dispute',
    'shopId': 'shop',
    'entryId': 'entry',
    'customerUserId': 'customer',
    'status': 'open',
    'reason': 'Wrong amount',
    'resolutionNote': null,
    'createdAtMs': 1,
    'resolvedAtMs': null,
  };
  test('Dispute resolution requires note and timestamp and keeps financial fields absent', () {
    expect(Dispute(dispute).status, DisputeStatus.open);
    expect(
      () => Dispute({...dispute, 'status': 'resolved'}),
      throwsFormatException,
    );
    expect(
      Dispute({
        ...dispute,
        'status': 'resolved',
        'resolutionNote': 'Correction recorded',
        'resolvedAtMs': 2,
      }).status,
      DisputeStatus.resolved,
    );
    expect(() => Dispute({...dispute, 'reason': ''}), throwsFormatException);
  });
  test(
    'Due summary must match requested date and bounded acknowledged balances',
    () {
      final row = {
        'asOfDate': '2026-10-02',
        'balancePaise': 10000,
        'overduePaise': 5000,
        'asOfServerSeq': 2,
        'asOfMs': 3,
      };
      expect(DueSnapshot(row, '2026-10-02').overduePaise, 5000);
      expect(() => DueSnapshot(row, '2026-10-03'), throwsFormatException);
      expect(
        () => DueSnapshot({...row, 'overduePaise': 10001}, '2026-10-02'),
        throwsFormatException,
      );
      expect(
        () => DueSnapshot({...row, 'balancePaise': -1}, '2026-10-02'),
        throwsFormatException,
      );
    },
  );
}
