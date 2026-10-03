/// Ephemeral presentation context from an already authorized loaded entry.
/// Never persisted or used for authorization or request bodies.
class DisputeEntryContext {
  const DisputeEntryContext({
    required this.accountId,
    required this.shopId,
    required this.entryId,
    required this.kind,
    required this.amountPaise,
    required this.occurredAtMs,
  });
  final String accountId, shopId, entryId, kind;
  final int amountPaise, occurredAtMs;
  bool matches({
    required String accountId,
    required String shopId,
    required String entryId,
  }) =>
      this.accountId == accountId &&
      this.shopId == shopId &&
      this.entryId == entryId;
}
