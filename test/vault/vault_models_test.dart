import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VaultQuota parses plan metadata and upgrade details', () {
    final quota = VaultQuota.fromJson({
      'used_bytes': 450000000,
      'total_bytes': 524288000,
      'remaining_bytes': 74288000,
      'is_over_quota': false,
      'tier': 'free',
      'tier_label': 'Free',
      'limit_label': '500 MB',
      'upgrade_available': true,
      'upgrade_tier': 'plus',
      'upgrade_tier_label': 'Plus',
      'upgrade_limit_bytes': 5368709120,
      'upgrade_limit_label': '5 GB',
    });

    expect(quota.planLabel, 'Free plan');
    expect(quota.displayLimitLabel, '500 MB');
    expect(quota.remainingBytes, 74288000);
    expect(quota.isNearLimit, isTrue);
    expect(quota.isAtLimit, isFalse);
    expect(quota.upgradeMessage, 'Plus includes 5 GB');
  });

  test('VaultQuota falls back for legacy quota responses', () {
    final quota = VaultQuota.fromJson({
      'used_bytes': 600,
      'total_bytes': 500,
      'tier': 'plus',
    });

    expect(quota.planLabel, 'Plus plan');
    expect(quota.remainingBytes, 0);
    expect(quota.isAtLimit, isTrue);
    expect(quota.upgradeMessage, isNull);
  });

  test('VaultShare parses and serializes object_key', () {
    final share = VaultShare.fromJson({
      'share_id': 'share-1',
      'object_key': '/documents/roadmap.pdf',
      'file_name': 'roadmap.pdf',
      'file_size': 12345,
      'mime_type': 'application/pdf',
      'vault_url': 'https://vault.example/share/share-1',
      'owner_user_id': '@owner:example.test',
      'target_id': '!room:example.test',
      'share_type': 'room',
      'expires_at': '2026-05-01T10:30:00Z',
      'download_count': 3,
      'is_revoked': false,
      'created_at': '2026-04-25T09:15:00Z',
    });

    expect(share.objectKey, '/documents/roadmap.pdf');
    expect(share.fileName, 'roadmap.pdf');
    expect(share.targetId, '!room:example.test');
    expect(share.shareType, 'room');
    expect(share.downloadCount, 3);
    expect(share.toJson()['object_key'], '/documents/roadmap.pdf');
  });
}
