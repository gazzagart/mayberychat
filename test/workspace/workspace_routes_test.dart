import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:fluffychat/utils/workspace/workspace_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post-login route follows workspace security mode', () {
    const expectedRoutes = {
      WorkspaceSecurityMode.simple: WorkspaceRoutes.rooms,
      WorkspaceSecurityMode.easyE2ee: WorkspaceRoutes.rooms,
      WorkspaceSecurityMode.balanced: WorkspaceRoutes.rooms,
      WorkspaceSecurityMode.strict: WorkspaceRoutes.backup,
    };

    for (final entry in expectedRoutes.entries) {
      expect(
        postLoginRouteForWorkspace(_workspace(securityMode: entry.key)),
        entry.value,
        reason: '${entry.key} should route to ${entry.value}',
      );
    }
  });

  test('post-login route keeps backup fallback without workspace config', () {
    expect(postLoginRouteForWorkspace(null), WorkspaceRoutes.backup);
  });
}

WorkspaceConfig _workspace({required String securityMode}) {
  return WorkspaceConfig(
    id: securityMode,
    slug: securityMode,
    displayName: securityMode,
    homeserverUrl: 'https://$securityMode.matrix.example',
    vaultApiUrl: 'https://$securityMode.vault.example',
    isolationTier: WorkspaceIsolationTier.dedicated,
    securityMode: securityMode,
    loginMethods: const ['password'],
    branding: const WorkspaceBranding(),
    features: const {},
  );
}
