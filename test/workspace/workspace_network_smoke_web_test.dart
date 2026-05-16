import 'dart:convert';

import 'package:fluffychat/utils/workspace/workspace_api.dart';
import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const controlPlaneUrl = String.fromEnvironment(
  'CONTROL_PLANE_URL',
  defaultValue: 'http://127.0.0.1:18085',
);
const tenantAUser = String.fromEnvironment(
  'TENANT_A_USER',
  defaultValue: 'smoke_alice',
);
const tenantBUser = String.fromEnvironment(
  'TENANT_B_USER',
  defaultValue: 'smoke_bob',
);
const tenantPassword = String.fromEnvironment(
  'TENANT_PASSWORD',
  defaultValue: 'SmokePassw0rd!',
);

void main() {
  test('web can resolve and use two isolated tenant stacks', () async {
    final httpClient = http.Client();
    addTearDown(httpClient.close);

    final workspaceApi = WorkspaceApi(
      baseUrl: controlPlaneUrl,
      httpClient: httpClient,
    );

    final tenantA = await _resolveSingle(workspaceApi, 'local-a');
    final tenantB = await _resolveSingle(workspaceApi, 'local-b');

    expect(tenantA.homeserverUrl, contains(':18008'));
    expect(tenantA.vaultApiUrl, contains(':18090'));
    expect(tenantA.securityMode, WorkspaceSecurityMode.easyE2ee);
    expect(tenantB.homeserverUrl, contains(':18108'));
    expect(tenantB.vaultApiUrl, contains(':18190'));
    expect(tenantB.securityMode, WorkspaceSecurityMode.strict);

    final tenantAToken = await _login(
      httpClient,
      tenantA.homeserverUrl,
      tenantAUser,
    );
    final tenantBToken = await _login(
      httpClient,
      tenantB.homeserverUrl,
      tenantBUser,
    );

    await _expectVaultStatus(
      httpClient,
      tenantB.vaultApiUrl,
      tenantAToken,
      expectedStatus: 401,
      label: 'tenant A token must not work against tenant B Vault',
    );

    await _provisionVault(httpClient, tenantA.vaultApiUrl, tenantAToken);
    await _provisionVault(httpClient, tenantB.vaultApiUrl, tenantBToken);

    await _expectVaultStatus(
      httpClient,
      tenantA.vaultApiUrl,
      tenantAToken,
      expectedStatus: 200,
      label: 'tenant A quota after provisioning',
    );
    await _expectVaultStatus(
      httpClient,
      tenantB.vaultApiUrl,
      tenantBToken,
      expectedStatus: 200,
      label: 'tenant B quota after provisioning',
    );
  });
}

Future<WorkspaceConfig> _resolveSingle(
  WorkspaceApi workspaceApi,
  String slug,
) async {
  final workspaces = await workspaceApi.resolve(slug: slug);
  expect(workspaces, hasLength(1));
  expect(workspaces.single.slug, slug);
  return workspaces.single;
}

Future<String> _login(
  http.Client httpClient,
  String homeserverUrl,
  String username,
) async {
  final response = await httpClient.post(
    Uri.parse('$homeserverUrl/_matrix/client/v3/login'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'type': 'm.login.password',
      'identifier': {'type': 'm.id.user', 'user': username},
      'password': tenantPassword,
    }),
  );

  expect(response.statusCode, 200, reason: response.body);
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final token = data['access_token'] as String?;
  expect(token, isNotNull);
  expect(token, isNotEmpty);
  return token!;
}

Future<void> _provisionVault(
  http.Client httpClient,
  String vaultApiUrl,
  String token,
) async {
  final response = await httpClient.post(
    Uri.parse('$vaultApiUrl/api/v1/auth/provision'),
    headers: {'Authorization': 'Bearer $token'},
  );
  expect(response.statusCode, 200, reason: response.body);
}

Future<void> _expectVaultStatus(
  http.Client httpClient,
  String vaultApiUrl,
  String token, {
  required int expectedStatus,
  required String label,
}) async {
  final response = await httpClient.get(
    Uri.parse('$vaultApiUrl/api/v1/quota'),
    headers: {'Authorization': 'Bearer $token'},
  );
  expect(
    response.statusCode,
    expectedStatus,
    reason: '$label: ${response.body}',
  );
}
