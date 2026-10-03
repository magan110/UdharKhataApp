import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/ui/money_format.dart';

void main() {
  test('Indian grouping preserves integer paise and sign', () {
    const cases = {0: '₹0.00', -1: '-₹0.01', 99999: '₹999.99', 100000: '₹1,000.00', 9999999: '₹99,999.99', 10000000: '₹1,00,000.00', 1245000: '₹12,450.00', 124567890: '₹12,45,678.90', -124567890: '-₹12,45,678.90'};
    for (final e in cases.entries) { expect(formatDisplayPaise(e.key), e.value); }
  });
}
