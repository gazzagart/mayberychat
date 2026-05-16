import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:fluffychat/utils/workspace/workspace_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores and loads workspace config per client name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferences.getInstance();

    const workspace = WorkspaceConfig(
      id: 'acme',
      slug: 'acme',
      displayName: 'Acme',
      homeserverUrl: 'https://acme.matrix.example',
      vaultApiUrl: 'https://acme.vault.example',
      isolationTier: WorkspaceIsolationTier.dedicated,
      securityMode: WorkspaceSecurityMode.easyE2ee,
      loginMethods: ['password'],
      branding: WorkspaceBranding(primaryColor: '#5625BA'),
      features: {'vault': true},
    );

    await WorkspaceSessionStore.set(store, 'client-a', workspace);

    final loaded = WorkspaceSessionStore.get(store, 'client-a');
    expect(loaded, isNotNull);
    expect(loaded!.slug, 'acme');
    expect(loaded.vaultApiUrl, 'https://acme.vault.example');
    expect(loaded.securityMode, WorkspaceSecurityMode.easyE2ee);
    expect(loaded.loginMethods, ['password']);
    expect(loaded.branding.primaryColor, '#5625BA');
    expect(loaded.features, {'vault': true});
    expect(WorkspaceSessionStore.get(store, 'client-b'), isNull);
  });

  test('remove clears workspace config for client name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferences.getInstance();

    const workspace = WorkspaceConfig(
      id: 'acme',
      slug: 'acme',
      displayName: 'Acme',
      homeserverUrl: 'https://acme.matrix.example',
      vaultApiUrl: 'https://acme.vault.example',
      isolationTier: WorkspaceIsolationTier.dedicated,
      securityMode: WorkspaceSecurityMode.strict,
      loginMethods: ['password'],
      branding: WorkspaceBranding(),
      features: {},
    );

    await WorkspaceSessionStore.set(store, 'client-a', workspace);
    await WorkspaceSessionStore.remove(store, 'client-a');

    expect(WorkspaceSessionStore.get(store, 'client-a'), isNull);
  });

  test('invalid stored JSON returns null', () async {
    SharedPreferences.setMockInitialValues({
      WorkspaceSessionStore.keyForClient('client-a'): 'not-json',
    });
    final store = await SharedPreferences.getInstance();

    expect(WorkspaceSessionStore.get(store, 'client-a'), isNull);
  });
}
