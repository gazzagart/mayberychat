import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WorkspaceConfig parses tenant routing and easy E2EE defaults', () {
    final workspace = WorkspaceConfig.fromJson({
      'id': 'local',
      'slug': 'local',
      'display_name': 'LetsYak Local',
      'homeserver_url': 'http://localhost:8008',
      'vault_api_url': 'http://localhost:8090',
      'isolation_tier': 'dedicated',
      'security_mode': 'easy_e2ee',
      'login_methods': ['password'],
      'branding': {
        'logo_url': '',
        'primary_color': '#5625BA',
        'secondary_color': '#41A2BC',
      },
      'features': {'vault': true, 'organisation_admin': true},
    });

    expect(workspace.slug, 'local');
    expect(workspace.isDedicated, isTrue);
    expect(workspace.isEasyE2ee, isTrue);
    expect(workspace.shouldForceBackupAfterLogin, isFalse);
    expect(workspace.supportsPasswordLogin, isTrue);
    expect(workspace.hasVault, isTrue);
    expect(workspace.branding.logoUrl, isNull);
    expect(workspace.branding.primaryColor, '#5625BA');

    final roundTrip = WorkspaceConfig.fromJson(workspace.toJson());
    expect(roundTrip.slug, workspace.slug);
    expect(roundTrip.vaultApiUrl, workspace.vaultApiUrl);
    expect(roundTrip.securityMode, WorkspaceSecurityMode.easyE2ee);
    expect(roundTrip.branding.primaryColor, '#5625BA');
  });

  test('WorkspaceConfig marks strict tenants as backup gated', () {
    final workspace = WorkspaceConfig.fromJson({
      'id': 'legal',
      'slug': 'legal',
      'display_name': 'Legal Workspace',
      'homeserver_url': 'https://legal.matrix.letsyak.com',
      'vault_api_url': 'https://legal.vault.letsyak.com',
      'security_mode': 'strict',
    });

    expect(workspace.isStrictSecurity, isTrue);
    expect(workspace.shouldForceBackupAfterLogin, isTrue);
    expect(workspace.loginMethods, ['password']);
    expect(workspace.isDedicated, isTrue);
  });
}
