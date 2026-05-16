import 'package:fluffychat/pages/vault/vault_org_admin_panel.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty team state without create action for normal users', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultOrgAdminPanel(
            loading: false,
            error: null,
            organizations: const [],
            selectedOrganization: null,
            usage: null,
            canCreateTeam: false,
            onRefresh: _noop,
            onCreateOrganization: _noop,
            onAddMember: _noop,
            onRoleChanged: (_, _) => Future<void>.value(),
            onTierChanged: (_, _) => Future<void>.value(),
            onRemoveMember: (_) => Future<void>.value(),
          ),
        ),
      ),
    );

    expect(
      find.text('No team has been set up for this workspace yet.'),
      findsOneWidget,
    );
    expect(find.text('Set up team'), findsNothing);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('shows gated team setup action when allowed', (tester) async {
    var createTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultOrgAdminPanel(
            loading: false,
            error: null,
            organizations: const [],
            selectedOrganization: null,
            usage: null,
            canCreateTeam: true,
            onRefresh: _noop,
            onCreateOrganization: () {
              createTapped = true;
              return Future<void>.value();
            },
            onAddMember: _noop,
            onRoleChanged: (_, _) => Future<void>.value(),
            onTierChanged: (_, _) => Future<void>.value(),
            onRemoveMember: (_) => Future<void>.value(),
          ),
        ),
      ),
    );

    expect(find.text('Set up team'), findsOneWidget);
    await tester.tap(find.text('Set up team'));
    expect(createTapped, isTrue);
  });

  testWidgets('shows owner usage and member actions', (tester) async {
    var addTapped = false;
    String? changedTier;
    final org = _org(role: 'owner');
    final member = _member();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultOrgAdminPanel(
            loading: false,
            error: null,
            organizations: [org],
            selectedOrganization: org,
            usage: VaultOrganizationUsage(
              orgId: org.id,
              activeMembers: 1,
              assignedPlusSeats: 0,
              totalUsedBytes: 1024,
              totalQuotaBytes: 524288000,
              overQuotaMembers: 0,
              members: [member],
            ),
            canCreateTeam: true,
            onRefresh: _noop,
            onCreateOrganization: _noop,
            onAddMember: () {
              addTapped = true;
              return Future<void>.value();
            },
            onRoleChanged: (_, _) => Future<void>.value(),
            onTierChanged: (_, tier) {
              changedTier = tier;
              return Future<void>.value();
            },
            onRemoveMember: (_) => Future<void>.value(),
          ),
        ),
      ),
    );

    expect(find.text('Acme Team'), findsOneWidget);
    expect(find.text('Members'), findsWidgets);
    expect(find.text('@member:example.test'), findsOneWidget);

    await tester.tap(find.text('Add'));
    expect(addTapped, isTrue);

    await tester.tap(find.byTooltip('Member actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set Plus'));
    expect(changedTier, 'plus');
  });

  testWidgets('hides admin controls for plain members', (tester) async {
    final org = _org(role: 'member');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultOrgAdminPanel(
            loading: false,
            error: null,
            organizations: [org],
            selectedOrganization: org,
            usage: null,
            canCreateTeam: false,
            onRefresh: _noop,
            onCreateOrganization: _noop,
            onAddMember: _noop,
            onRoleChanged: (_, _) => Future<void>.value(),
            onTierChanged: (_, _) => Future<void>.value(),
            onRemoveMember: (_) => Future<void>.value(),
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Owners and admins can manage members'),
      findsOneWidget,
    );
    expect(find.text('Add'), findsNothing);
  });
}

Future<void> _noop() => Future<void>.value();

VaultOrganization _org({required String role}) => VaultOrganization(
  id: 'org-1',
  name: 'Acme Team',
  slug: 'acme-team',
  ownerUserId: '@owner:example.test',
  storagePlan: 'manual',
  seatLimit: 1,
  storageQuotaBytes: 0,
  role: role,
  status: 'active',
  assignedTier: 'free',
  createdAt: DateTime.utc(2026, 4, 28),
  updatedAt: DateTime.utc(2026, 4, 28),
);

VaultOrganizationMember _member() => VaultOrganizationMember(
  orgId: 'org-1',
  matrixUserId: '@member:example.test',
  role: 'member',
  status: 'active',
  assignedTier: 'free',
  usedBytes: 1024,
  quotaBytes: 524288000,
  vaultTier: 'free',
  limitLabel: '500 MB',
  isOverQuota: false,
  createdAt: DateTime.utc(2026, 4, 28),
);
