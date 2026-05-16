import 'dart:convert';

import 'package:fluffychat/pages/sign_in/view_model/sign_in_view_model.dart';
import 'package:fluffychat/utils/workspace/workspace_api.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'resolveWorkspaceQuery resolves email and auto-selects single match',
    () async {
      late http.Request capturedRequest;
      final viewModel = _viewModel(
        WorkspaceApi(
          baseUrl: 'https://control.example',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'workspaces': [_workspaceJson(slug: 'acme')],
              }),
              200,
            );
          }),
        ),
      );

      await viewModel.resolveWorkspaceQuery(' alice@example.com ');

      expect(capturedRequest.url.queryParameters, {
        'email': 'alice@example.com',
      });
      expect(capturedRequest.url.queryParameters.containsKey('slug'), isFalse);
      expect(
        viewModel.value.publicHomeservers.connectionState,
        ConnectionState.done,
      );
      expect(viewModel.value.filteredPublicHomeservers, hasLength(1));
      expect(
        viewModel.value.selectedHomeserver,
        same(viewModel.value.filteredPublicHomeservers.single),
      );
      expect(viewModel.value.selectedHomeserver!.workspace!.slug, 'acme');
    },
  );

  test('resolveWorkspaceQuery resolves workspace slug', () async {
    late http.Request capturedRequest;
    final viewModel = _viewModel(
      WorkspaceApi(
        baseUrl: 'https://control.example',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'workspaces': [_workspaceJson(slug: 'local')],
            }),
            200,
          );
        }),
      ),
    );

    await viewModel.resolveWorkspaceQuery('local');

    expect(capturedRequest.url.queryParameters, {'slug': 'local'});
    expect(capturedRequest.url.queryParameters.containsKey('email'), isFalse);
    expect(viewModel.value.selectedHomeserver!.workspace!.slug, 'local');
  });

  test(
    'resolveWorkspaceQuery leaves multiple workspace matches unselected',
    () async {
      final viewModel = _viewModel(
        WorkspaceApi(
          baseUrl: 'https://control.example',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'workspaces': [
                  _workspaceJson(slug: 'acme'),
                  _workspaceJson(slug: 'support'),
                ],
              }),
              200,
            ),
          ),
        ),
      );

      await viewModel.resolveWorkspaceQuery('alice@example.com');

      expect(viewModel.value.filteredPublicHomeservers, hasLength(2));
      expect(viewModel.value.selectedHomeserver, isNull);
    },
  );

  test('resolveWorkspaceQuery falls back to manual homeserver entry', () async {
    final viewModel = _viewModel(
      WorkspaceApi(
        baseUrl: 'https://control.example',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'workspace unavailable'}),
            503,
          ),
        ),
      ),
    );

    await viewModel.resolveWorkspaceQuery('matrix.example.com');

    expect(viewModel.value.publicHomeservers.hasError, isFalse);
    expect(viewModel.value.filteredPublicHomeservers, hasLength(1));
    expect(viewModel.value.selectedHomeserver!.name, 'matrix.example.com');
    expect(viewModel.value.selectedHomeserver!.workspace, isNull);
  });

  test(
    'resolveWorkspaceQuery exposes discovery error when no fallback exists',
    () async {
      final viewModel = _viewModel(
        WorkspaceApi(
          baseUrl: 'https://control.example',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({'error': 'workspace unavailable'}),
              503,
            ),
          ),
        ),
      );

      await viewModel.resolveWorkspaceQuery('unknown');

      expect(viewModel.value.publicHomeservers.hasError, isTrue);
      expect(viewModel.value.filteredPublicHomeservers, isEmpty);
      expect(viewModel.value.selectedHomeserver, isNull);
    },
  );
}

SignInViewModel _viewModel(WorkspaceApi workspaceApi) {
  final viewModel = SignInViewModel(
    MatrixState(),
    signUp: false,
    workspaceApi: workspaceApi,
  );
  addTearDown(viewModel.dispose);
  return viewModel;
}

Map<String, dynamic> _workspaceJson({required String slug}) => {
  'id': slug,
  'slug': slug,
  'display_name': '$slug Workspace',
  'homeserver_url': 'https://$slug.matrix.example',
  'vault_api_url': 'https://$slug.vault.example',
  'isolation_tier': 'dedicated',
  'security_mode': 'easy_e2ee',
  'login_methods': ['password'],
  'branding': {'support_url': 'https://$slug.example/help'},
  'features': {'vault': true},
};
