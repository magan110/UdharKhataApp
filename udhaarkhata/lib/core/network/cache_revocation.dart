import '../auth/auth_repository.dart';

/// Account-scoped invalidation shared by all confirmed customer caches.
class CacheRevocation {
  static final _accounts = Expando<Map<String, CacheRevocation>>();
  static CacheRevocation forAccount(AuthRepository auth, String accountId) {
    final accounts = _accounts[auth] ??= {};
    return accounts.putIfAbsent(accountId, CacheRevocation.new);
  }

  final List<Future<void> Function()> _clearers = [];
  int generation = 0;
  void register(Future<void> Function() clear) => _clearers.add(clear);
  Future<void> revoke() async {
    generation++;
    await Future.wait(_clearers.map((clear) => clear()));
  }
}
