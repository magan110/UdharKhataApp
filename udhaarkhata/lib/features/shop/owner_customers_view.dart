import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_strings.dart';
import '../ledger/local_ledger_view.dart';
import 'customer_list.dart';
import 'shop_repository.dart';

class OwnerCustomersView extends StatelessWidget {
  const OwnerCustomersView({super.key, required this.shop});
  final Shop shop;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    FilledButton.icon(onPressed: () => context.push('/owner/scan/${shop.id.value}'), icon: const Icon(Icons.qr_code_scanner), label: Text(AppStrings.of(context).translate('Scan customer QR'))),
    const SizedBox(height: 16), CustomerList(shopId: shop.id), const SizedBox(height: 16), const SavedCustomersView(),
  ]);
}
