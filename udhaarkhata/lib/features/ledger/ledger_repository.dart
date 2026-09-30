import '../../core/network/contracts.dart';

final class LedgerBalance {
  const LedgerBalance(this.amount, this.version);
  final MoneyPaise amount;
  final int version;
}

abstract interface class LedgerRepository {
  Future<LedgerBalance> acknowledgedBalance(OpaqueId linkId);
}
