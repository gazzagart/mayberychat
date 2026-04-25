import 'dart:convert';

import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../utils/test_client.dart';

void main() {
  test('getQuota parses enriched quota response and forwards auth', () async {
    final matrixClient = await prepareTestClient(loggedIn: true);
    late http.Request capturedRequest;
    final api = VaultApi(
      matrixClient: matrixClient,
      baseUrl: 'https://vault.example',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'used_bytes': 200000000,
            'total_bytes': 524288000,
            'remaining_bytes': 324288000,
            'usage_percent': 0.381,
            'is_over_quota': false,
            'tier': 'free',
            'tier_label': 'Free',
            'limit_label': '500 MB',
            'upgrade_available': true,
            'upgrade_tier': 'plus',
            'upgrade_tier_label': 'Plus',
            'upgrade_limit_bytes': 5368709120,
            'upgrade_limit_label': '5 GB',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final quota = await api.getQuota();

    expect(capturedRequest.method, 'GET');
    expect(
      capturedRequest.url.toString(),
      'https://vault.example/api/v1/quota',
    );
    expect(
      capturedRequest.headers['Authorization'],
      'Bearer ${matrixClient.accessToken}',
    );
    expect(quota.tier, 'free');
    expect(quota.planLabel, 'Free plan');
    expect(quota.remainingBytes, 324288000);
    expect(quota.displayLimitLabel, '500 MB');
    expect(quota.upgradeMessage, 'Plus includes 5 GB');
  });

  test('quota exceeded backend errors expose friendly message', () {
    const error = VaultApiException('storage quota exceeded', 403);

    expect(error.isQuotaExceeded, isTrue);
    expect(
      error.friendlyMessage,
      'Your Vault is full. Delete files or upgrade to Plus for 5 GB.',
    );
  });

  test(
    'listSharedWithMe calls aggregation endpoint and parses shares',
    () async {
      final matrixClient = await prepareTestClient(loggedIn: true);
      late http.Request capturedRequest;
      final api = VaultApi(
        matrixClient: matrixClient,
        baseUrl: 'https://vault.example',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode([
              {
                'share_id': 'share-1',
                'object_key': '/team/notes.txt',
                'file_name': 'notes.txt',
                'file_size': 512,
                'mime_type': 'text/plain',
                'vault_url': 'https://vault.example/share/share-1',
                'owner_user_id': '@owner:example.test',
                'target_id': '!room:example.test',
                'share_type': 'room',
                'expires_at': null,
                'download_count': 2,
                'is_revoked': false,
                'created_at': '2026-04-25T09:15:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final shares = await api.listSharedWithMe();

      expect(capturedRequest.method, 'GET');
      expect(
        capturedRequest.url.toString(),
        'https://vault.example/api/v1/shares/shared-with-me',
      );
      expect(
        capturedRequest.headers['Authorization'],
        'Bearer ${matrixClient.accessToken}',
      );
      expect(shares, hasLength(1));
      expect(shares.single.shareId, 'share-1');
      expect(shares.single.objectKey, '/team/notes.txt');
      expect(shares.single.targetId, '!room:example.test');
    },
  );

  test('listSharedWithMe maps backend errors to VaultApiException', () async {
    final matrixClient = await prepareTestClient(loggedIn: true);
    final api = VaultApi(
      matrixClient: matrixClient,
      baseUrl: 'https://vault.example',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'joined-room lookup failed'}),
          502,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.listSharedWithMe(),
      throwsA(
        isA<VaultApiException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.message,
              'message',
              'joined-room lookup failed',
            ),
      ),
    );
  });
}
