import '../network/contracts.dart';

abstract interface class AccountDatabase {
  Future<void> openForAccount(OpaqueId accountId);
  Future<void> lock();
}
