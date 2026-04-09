import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';

/// A compact storage usage bar for the vault.
class VaultQuotaWidget extends StatelessWidget {
  final VaultQuota quota;

  const VaultQuotaWidget({required this.quota, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = quota.usagePercent > 0.9
        ? theme.colorScheme.error
        : quota.usagePercent > 0.7
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${quota.usedString} of ${quota.totalString} used',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                quota.tier.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: quota.usagePercent,
              backgroundColor: color.withAlpha(38),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
