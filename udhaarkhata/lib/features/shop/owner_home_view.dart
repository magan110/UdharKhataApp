import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_strings.dart';
import '../ledger/history_page.dart';
import '../ledger/online_reads.dart';
import '../ledger/sync_status_view.dart';
import 'shop_repository.dart';

class OwnerHomeView extends StatelessWidget {
  const OwnerHomeView({
    super.key,
    required this.shop,
    required this.onViewAll,
    required this.onSyncDetails,
  });
  final Shop shop;
  final VoidCallback onViewAll, onSyncDetails;
  @override
  Widget build(BuildContext context) {
    final l = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        OnlineRecordsView(
          path: '/v1/shops/${shop.id.value}',
          kind: OnlineReadKind.summary,
          shopId: shop.id.value,
        ),
        const SizedBox(height: 16),
        SyncStatusView(compact: true, onOpenDetails: onSyncDetails),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/owner/scan/${shop.id.value}'),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l.translate('Scan customer QR')),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l.translate('Customers'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(l.translate('View all')),
            ),
          ],
        ),
        OnlineRecordsView(
          path: '/v1/shops/${shop.id.value}/customers',
          kind: OnlineReadKind.customers,
          shopId: shop.id.value,
          previewLimit: 3,
          showControls: false,
        ),
      ],
    );
  }
}
