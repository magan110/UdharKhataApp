import '../../core/network/contracts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';

final class Shop {
  const Shop(this.id, this.name);
  final OpaqueId id;
  final String name;
}

abstract interface class ShopRepository {
  Future<Shop?> currentShop();
  Future<Shop> createShop(String name);
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final account = ref.watch(sessionProvider).value;
  return account == null
      ? const UnconfiguredShopRepository()
      : CloudShopRepository(ref.watch(authRepositoryProvider), account.id);
});
final currentShopProvider = FutureProvider.autoDispose<Shop?>(
  (ref) => ref.watch(shopRepositoryProvider).currentShop(),
  retry: (_, _) => null,
);

class UnconfiguredShopRepository implements ShopRepository {
  const UnconfiguredShopRepository();
  @override
  Future<Shop?> currentShop() async => null;
  @override
  Future<Shop> createShop(String name) =>
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
}

class CloudShopRepository implements ShopRepository {
  CloudShopRepository(this.auth, this.accountId);
  final AuthRepository auth;
  final OpaqueId accountId;
  Shop _decode(Object? value) {
    final row = jsonObject(value);
    if (row['status'] != 'active') throw const FormatException('Inactive shop');
    timestampMs(row['createdAtMs']);
    return Shop(OpaqueId.fromJson(row['id']), jsonString(row['name']));
  }

  @override
  Future<Shop?> currentShop() async {
    final profile = jsonObject(await auth.cloudRequest(accountId, '/v1/me'));
    if (!profile.containsKey('shop')) {
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
    }
    return profile['shop'] == null ? null : _decode(profile['shop']);
  }

  @override
  Future<Shop> createShop(String name) async => _decode(
    await auth.cloudRequest(accountId, '/v1/shops', body: {'name': name}),
  );
}
