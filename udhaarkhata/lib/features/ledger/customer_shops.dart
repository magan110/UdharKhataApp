import 'package:flutter/material.dart';

import 'history_page.dart';
import 'online_reads.dart';

class CustomerShopsPage extends StatelessWidget {
  const CustomerShopsPage({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(24),
    child: OnlineRecordsView(
      path: '/v1/me/ledgers',
      kind: OnlineReadKind.shops,
    ),
  );
}
