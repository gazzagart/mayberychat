import 'package:fluffychat/config/setting_keys.dart';

abstract class VaultConfig {
  static String get vaultApiBaseUrl => AppSettings.vaultApiBaseUrl.value;
  static const String vaultMsgtype = 'com.letsyak.vault_file';
  static const int defaultQuotaBytes = 524288000; // 500 MB
  static const int presignedUrlExpirySeconds = 3600; // 1 hour
  static const int maxUploadSizeBytes =
      104857600; // 100 MB (Cloudflare free tier limit)
}
