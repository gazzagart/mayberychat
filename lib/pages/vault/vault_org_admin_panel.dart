import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';

class VaultOrgAdminPanel extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<VaultOrganization> organizations;
  final VaultOrganization? selectedOrganization;
  final VaultOrganizationUsage? usage;
  final bool canCreateTeam;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreateOrganization;
  final Future<void> Function() onAddMember;
  final Future<void> Function(VaultOrganizationMember member, String role)
  onRoleChanged;
  final Future<void> Function(VaultOrganizationMember member, String tier)
  onTierChanged;
  final Future<void> Function(VaultOrganizationMember member) onRemoveMember;

  const VaultOrgAdminPanel({
    super.key,
    required this.loading,
    required this.error,
    required this.organizations,
    required this.selectedOrganization,
    required this.usage,
    required this.canCreateTeam,
    required this.onRefresh,
    required this.onCreateOrganization,
    required this.onAddMember,
    required this.onRoleChanged,
    required this.onTierChanged,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (error != null) {
      return _MessageState(
        icon: Icons.business_outlined,
        message: error!,
        action: FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (organizations.isEmpty) {
      return _MessageState(
        icon: Icons.admin_panel_settings_outlined,
        message: 'No team has been set up for this workspace yet.',
        action: canCreateTeam
            ? FilledButton.icon(
                onPressed: onCreateOrganization,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Set up team'),
              )
            : OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
      );
    }

    final org = selectedOrganization;
    if (org == null) {
      return _MessageState(
        icon: Icons.admin_panel_settings_outlined,
        message: 'Select a team to continue.',
        action: FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OrgHeader(
            org: org,
            canCreateTeam: canCreateTeam,
            onCreateOrganization: onCreateOrganization,
          ),
          const SizedBox(height: 16),
          if (!org.canManageOrganization)
            _InfoBox(
              icon: Icons.lock_outline,
              text:
                  'You are a ${org.roleLabel.toLowerCase()} in this workspace team. Owners and admins can manage members and usage.',
            )
          else ...[
            _UsageSummary(usage: usage),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddMember,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(usage?.members ?? const <VaultOrganizationMember>[]).map(
              (member) => _MemberTile(
                organization: org,
                member: member,
                onRoleChanged: onRoleChanged,
                onTierChanged: onTierChanged,
                onRemoveMember: onRemoveMember,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrgHeader extends StatelessWidget {
  final VaultOrganization org;
  final bool canCreateTeam;
  final Future<void> Function() onCreateOrganization;

  const _OrgHeader({
    required this.org,
    required this.canCreateTeam,
    required this.onCreateOrganization,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.admin_panel_settings_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(org.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${org.roleLabel} • ${org.slug}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (canCreateTeam)
          IconButton(
            onPressed: onCreateOrganization,
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Set up team',
          ),
      ],
    );
  }
}

class _UsageSummary extends StatelessWidget {
  final VaultOrganizationUsage? usage;

  const _UsageSummary({required this.usage});

  @override
  Widget build(BuildContext context) {
    final usage = this.usage;
    if (usage == null) {
      return const LinearProgressIndicator();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricTile(
          icon: Icons.group_outlined,
          label: 'Members',
          value: usage.activeMembers.toString(),
        ),
        _MetricTile(
          icon: Icons.workspace_premium_outlined,
          label: 'Plus seats',
          value: usage.assignedPlusSeats.toString(),
        ),
        _MetricTile(
          icon: Icons.cloud_outlined,
          label: 'Vault used',
          value: '${usage.totalUsedString} / ${usage.totalQuotaString}',
        ),
        _MetricTile(
          icon: Icons.warning_amber_outlined,
          label: 'Over quota',
          value: usage.overQuotaMembers.toString(),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final VaultOrganization organization;
  final VaultOrganizationMember member;
  final Future<void> Function(VaultOrganizationMember member, String role)
  onRoleChanged;
  final Future<void> Function(VaultOrganizationMember member, String tier)
  onTierChanged;
  final Future<void> Function(VaultOrganizationMember member) onRemoveMember;

  const _MemberTile({
    required this.organization,
    required this.member,
    required this.onRoleChanged,
    required this.onTierChanged,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final canManageMember = organization.isOwner || member.role == 'member';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(member.matrixUserId.substring(1, 2))),
      title: Text(member.matrixUserId, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${member.roleLabel} • ${member.planLabel} • ${member.usedString} of ${member.displayLimitLabel}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: canManageMember
          ? PopupMenuButton<_MemberAction>(
              tooltip: 'Member actions',
              onSelected: (action) => _handleAction(action, context),
              itemBuilder: (context) => [
                if (organization.isOwner)
                  const PopupMenuItem(
                    value: _MemberAction.makeOwner,
                    child: Text('Make owner'),
                  ),
                if (organization.isOwner)
                  const PopupMenuItem(
                    value: _MemberAction.makeAdmin,
                    child: Text('Make admin'),
                  ),
                if (organization.isOwner)
                  const PopupMenuItem(
                    value: _MemberAction.makeMember,
                    child: Text('Make member'),
                  ),
                const PopupMenuItem(
                  value: _MemberAction.freeTier,
                  child: Text('Set Free'),
                ),
                const PopupMenuItem(
                  value: _MemberAction.plusTier,
                  child: Text('Set Plus'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text('Remove'),
                ),
              ],
            )
          : null,
    );
  }

  void _handleAction(_MemberAction action, BuildContext context) {
    switch (action) {
      case _MemberAction.makeOwner:
        onRoleChanged(member, 'owner');
        break;
      case _MemberAction.makeAdmin:
        onRoleChanged(member, 'admin');
        break;
      case _MemberAction.makeMember:
        onRoleChanged(member, 'member');
        break;
      case _MemberAction.freeTier:
        onTierChanged(member, 'free');
        break;
      case _MemberAction.plusTier:
        onTierChanged(member, 'plus');
        break;
      case _MemberAction.remove:
        onRemoveMember(member);
        break;
    }
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget action;

  const _MessageState({
    required this.icon,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}

enum _MemberAction {
  makeOwner,
  makeAdmin,
  makeMember,
  freeTier,
  plusTier,
  remove,
}
