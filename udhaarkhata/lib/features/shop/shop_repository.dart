import '../../core/network/contracts.dart';

final class Shop {
  const Shop(this.id, this.name);
  final OpaqueId id;
  final String name;
}

abstract interface class ShopRepository {
  Future<Shop?> currentShop();
}
