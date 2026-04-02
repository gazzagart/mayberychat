abstract class VaultConfig {
  static const String vaultApiBaseUrl = 'https://vault.letsyak.com';
  static const String vaultMsgtype = 'com.letsyak.vault_file';
  static const int defaultQuotaBytes = 524288000; // 500 MB
  static const int presignedUrlExpirySeconds = 3600; // 1 hour
  static const int maxUploadSizeBytes = 524288000; // 500 MB
}
