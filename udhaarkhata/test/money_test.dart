import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/features/ledger/money.dart';

void main() {
  test('credit rupees parse exact integer paise and format without floats', () {
    expect(parseCreditRupees('500'), 50000);
    expect(parseCreditRupees('0.01'), 1);
    expect(parseCreditRupees('100000.00'), 10000000);
    expect(parseCreditRupees('12.3'), 1230);
    expect(formatPaise(50001), '₹500.01');
    for (final input in [
      '0',
      '-1',
      '1.001',
      '100000.01',
      '1e3',
      'NaN',
      '1,000',
      '',
      '9' * 50,
    ]) {
      expect(() => parseCreditRupees(input), throwsFormatException);
    }
  });
}
