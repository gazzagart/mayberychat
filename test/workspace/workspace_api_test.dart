import 'dart:convert';

import 'package:fluffychat/utils/workspace/workspace_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolve by slug calls control-plane and parses workspaces', () async {
    late http.Request capturedRequest;
    final api = WorkspaceApi(
      baseUrl: 'https://control.example',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'workspaces': [
              {
                'id': 'acme',
                'slug': 'acme',
                'display_name': 'Acme',
                'homeserver_url': 'https://acme.matrix.example',
                'vault_api_url': 'https://acme.vault.example',
                'isolation_tier': 'dedicated',
                'security_mode': 'easy_e2ee',
                'login_methods': ['password', 'sso'],
                'branding': {'primary_color': '#123456'},
                'features': {'vault': true},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final workspaces = await api.resolve(slug: 'acme');

    expect(capturedRequest.method, 'GET');
    expect(
      capturedRequest.url.toString(),
      'https://control.example/api/v1/workspaces/resolve?slug=acme',
    );
    expect(capturedRequest.headers['Accept'], 'application/json');
    expect(workspaces, hasLength(1));
    expect(workspaces.single.slug, 'acme');
    expect(workspaces.single.supportsSsoLogin, isTrue);
    expect(workspaces.single.hasVault, isTrue);
  });

  test('resolve by email encodes query and supports multiple matches', () async {
    late http.Request capturedRequest;
    final api = WorkspaceApi(
      baseUrl: 'https://control.example',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'workspaces': [
              {
                'id': 'acme',
                'slug': 'acme',
                'display_name': 'Acme',
                'homeserver_url': 'https://acme.matrix.example',
                'vault_api_url': 'https://acme.vault.example',
              },
              {
                'id': 'support',
                'slug': 'support',
                'display_name': 'Support',
                'homeserver_url': 'https://support.matrix.example',
                'vault_api_url': 'https://support.vault.example',
              },
            ],
          }),
          200,
        );
      }),
    );

    final workspaces = await api.resolve(email: 'alice@example.com');

    expect(
      capturedRequest.url.toString(),
      'https://control.example/api/v1/workspaces/resolve?email=alice%40example.com',
    );
    expect(workspaces.map((workspace) => workspace.slug), ['acme', 'support']);
  });

  test('resolve maps control-plane errors', () async {
    final api = WorkspaceApi(
      baseUrl: 'https://control.example',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'email or slug is required'}),
          400,
        ),
      ),
    );

    await expectLater(
      api.resolve(email: 'bad'),
      throwsA(
        isA<WorkspaceApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              'email or slug is required',
            ),
      ),
    );
  });

  test('resolve requires email or slug locally', () {
    final api = WorkspaceApi(baseUrl: 'https://control.example');

    expect(api.resolve, throwsArgumentError);
  });
}
