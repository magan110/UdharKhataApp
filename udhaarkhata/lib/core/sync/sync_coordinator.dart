enum SyncStatus { pending, synced, needsAttention }

abstract interface class SyncCoordinator {
  Future<void> synchronize();
}
