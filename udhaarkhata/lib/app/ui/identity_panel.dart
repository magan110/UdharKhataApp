import 'package:flutter/material.dart';

import '../app_strings.dart';
import 'app_tokens.dart';

class IdentityPanel extends StatelessWidget {
  const IdentityPanel({super.key, required this.displayName, this.nickname});
  final String displayName;
  final String? nickname;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTokens.tint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (nickname != null)
          Text(
            AppStrings.of(context)
                .format('Shop nickname: {name}', values: {'name': nickname!}),
          ),
      ],
    ),
  );
}
