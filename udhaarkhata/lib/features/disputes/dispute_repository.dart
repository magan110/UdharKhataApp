import '../../core/network/contracts.dart';

enum DisputeStatus { open, resolved }

abstract interface class DisputeRepository {
  Future<DisputeStatus?> statusForEntry(OpaqueId entryId);
}
