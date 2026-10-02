// Maximum acknowledged entries in an automatic D11 offline bootstrap.
const maxOfflineCacheEntries = 10000;

const maxCreditPaise = 10000000;
const maxCreditNoteCharacters = 500;
int parseCreditRupees(String input) {
  final text = input.trim();
  if (text.length > 12 ||
      !RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(text)) {
    throw const FormatException(
      'Enter a positive INR amount with at most two decimals.',
    );
  }
  final parts = text.split('.');
  final paise =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (paise < 1 || paise > maxCreditPaise) {
    throw const FormatException('Use an amount from ₹0.01 to ₹1,00,000.00.');
  }
  return paise;
}

String formatPaise(int value) {
  final amount = value.abs();
  return '${value < 0 ? '-' : ''}₹${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
}

bool validDueDate(String? value) {
  if (value == null) return true;
  if (value.length != 10 || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final date = DateTime.tryParse(value);
  return date != null && date.toIso8601String().substring(0, 10) == value;
}
