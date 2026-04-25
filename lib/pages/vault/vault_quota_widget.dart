import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';

/// A compact storage usage bar for the vault.
class VaultQuotaWidget extends StatelessWidget {
  final VaultQuota quota;

  const VaultQuotaWidget({required this.quota, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = quota.isAtLimit
        ? theme.colorScheme.error
        : quota.isNearLimit
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final statusText = quota.isAtLimit
        ? 'Storage full'
        : '${quota.remainingString} remaining';
    final upgradeMessage = quota.upgradeMessage;

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
                quota.planLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                statusText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
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
          const SizedBox(height: 6),
          Text(
            '${quota.usedString} of ${quota.displayLimitLabel} used',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (upgradeMessage != null) ...[
            const SizedBox(height: 2),
            Text(
              upgradeMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
