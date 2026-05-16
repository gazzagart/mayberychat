import 'package:fluffychat/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps workspace config into selectable homeserver data', () {
    const workspace = WorkspaceConfig(
      id: 'acme',
      slug: 'acme',
      displayName: 'Acme Ltd',
      homeserverUrl: 'https://acme.matrix.example',
      vaultApiUrl: 'https://acme.vault.example',
      isolationTier: WorkspaceIsolationTier.dedicated,
      securityMode: WorkspaceSecurityMode.easyE2ee,
      loginMethods: ['password'],
      branding: WorkspaceBranding(supportUrl: 'https://acme.example/help'),
      features: {'vault': true},
    );

    final data = PublicHomeserverData.fromWorkspace(workspace);

    expect(data.name, 'https://acme.matrix.example');
    expect(data.displayName, 'Acme Ltd');
    expect(data.homeserverLabel, 'acme.matrix.example');
    expect(data.website, 'https://acme.example/help');
    expect(data.features, contains(WorkspaceSecurityMode.easyE2ee));
    expect(data.features, contains('vault'));
    expect(data.workspace, workspace);
  });
}
