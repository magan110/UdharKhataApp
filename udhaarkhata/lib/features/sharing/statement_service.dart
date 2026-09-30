import '../../core/network/contracts.dart';

abstract interface class StatementService {
  Future<void> shareStatement(OpaqueId linkId, DateTime from, DateTime to);
}
