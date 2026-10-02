import 'package:flutter/material.dart';

import 'history_page.dart';
import 'online_reads.dart';

class CustomerShopsPage extends StatelessWidget {
  const CustomerShopsPage({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: const OnlineRecordsView(
      path: '/v1/me/ledgers',
      kind: OnlineReadKind.shops,
    ),
  );
}
