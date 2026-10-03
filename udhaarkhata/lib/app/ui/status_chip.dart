import 'package:flutter/material.dart';

import '../app_strings.dart';
import 'app_tokens.dart';

enum EntryDisplayStatus { synced, pending, attention }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final EntryDisplayStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (status) {
      EntryDisplayStatus.synced => (
        'Synced',
        Icons.cloud_done_outlined,
        AppTokens.primary,
        AppTokens.tint,
      ),
      EntryDisplayStatus.pending => (
        'Pending · Waiting to sync · Only on this device',
        Icons.schedule,
        AppTokens.pending,
        AppTokens.pendingSurface,
      ),
      EntryDisplayStatus.attention => (
        'Needs attention',
        Icons.error_outline,
        AppTokens.attention,
        AppTokens.attentionSurface,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: foreground)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppStrings.of(context).translate(label),
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
