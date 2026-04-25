import 'package:fluffychat/utils/size_string.dart';

class VaultFile {
  final String name;
  final String path;
  final int size;
  final String? mimeType;
  final DateTime lastModified;
  final bool isFolder;

  const VaultFile({
    required this.name,
    required this.path,
    required this.size,
    this.mimeType,
    required this.lastModified,
    this.isFolder = false,
  });

  String get sizeString => size.toDouble().sizeString;

  String get extension {
    if (isFolder) return '';
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toUpperCase();
  }

  factory VaultFile.fromJson(Map<String, dynamic> json) => VaultFile(
    name: json['name'] as String,
    path: json['path'] as String,
    size: json['size'] as int? ?? 0,
    mimeType: json['mime_type'] as String?,
    lastModified: DateTime.parse(
      json['last_modified'] as String? ?? DateTime.now().toIso8601String(),
    ),
    isFolder: json['is_folder'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'size': size,
    'mime_type': mimeType,
    'last_modified': lastModified.toIso8601String(),
    'is_folder': isFolder,
  };
}

class VaultQuota {
  final int usedBytes;
  final int totalBytes;
  final String tier;
  final String? tierLabel;
  final String? limitLabel;
  final int remainingBytes;
  final bool isOverQuota;
  final bool upgradeAvailable;
  final String? upgradeTier;
  final String? upgradeTierLabel;
  final int? upgradeLimitBytes;
  final String? upgradeLimitLabel;

  const VaultQuota({
    required this.usedBytes,
    required this.totalBytes,
    this.tier = 'free',
    this.tierLabel,
    this.limitLabel,
    required this.remainingBytes,
    this.isOverQuota = false,
    this.upgradeAvailable = false,
    this.upgradeTier,
    this.upgradeTierLabel,
    this.upgradeLimitBytes,
    this.upgradeLimitLabel,
  });

  double get usagePercent =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isFree => tier.toLowerCase() == 'free';

  bool get isAtLimit => isOverQuota || usedBytes >= totalBytes;

  bool get isNearLimit => !isAtLimit && usagePercent >= 0.8;

  String get planLabel => '${tierLabel ?? _titleCase(tier)} plan';

  String get usedString => usedBytes.toDouble().sizeString;

  String get totalString => totalBytes.toDouble().sizeString;

  String get remainingString => remainingBytes.toDouble().sizeString;

  String get displayLimitLabel => limitLabel ?? totalString;

  String? get upgradeMessage {
    if (!upgradeAvailable) return null;

    final label = upgradeTierLabel ?? _titleCase(upgradeTier ?? 'plus');
    final limit = upgradeLimitLabel ?? upgradeLimitBytes?.toDouble().sizeString;
    if (limit == null) return '$label has more Vault storage';
    return '$label includes $limit';
  }

  factory VaultQuota.fromJson(Map<String, dynamic> json) {
    final usedBytes = _intFromJson(json['used_bytes'], 0);
    final totalBytes = _intFromJson(json['total_bytes'], 524288000);
    final defaultRemainingBytes = totalBytes > usedBytes
        ? totalBytes - usedBytes
        : 0;
    final remainingBytes = _intFromJson(
      json['remaining_bytes'],
      defaultRemainingBytes,
    );

    return VaultQuota(
      usedBytes: usedBytes,
      totalBytes: totalBytes,
      tier: json['tier'] as String? ?? 'free',
      tierLabel: json['tier_label'] as String?,
      limitLabel: json['limit_label'] as String?,
      remainingBytes: remainingBytes,
      isOverQuota: json['is_over_quota'] as bool? ?? usedBytes > totalBytes,
      upgradeAvailable: json['upgrade_available'] as bool? ?? false,
      upgradeTier: json['upgrade_tier'] as String?,
      upgradeTierLabel: json['upgrade_tier_label'] as String?,
      upgradeLimitBytes: _nullableIntFromJson(json['upgrade_limit_bytes']),
      upgradeLimitLabel: json['upgrade_limit_label'] as String?,
    );
  }

  factory VaultQuota.empty() => const VaultQuota(
    usedBytes: 0,
    totalBytes: 524288000,
    remainingBytes: 524288000,
  );
}

int _intFromJson(Object? value, int fallback) => switch (value) {
  int() => value,
  num() => value.toInt(),
  _ => fallback,
};

int? _nullableIntFromJson(Object? value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  _ => null,
};

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value.substring(0, 1).toUpperCase() + value.substring(1);
}

class VaultShare {
  final String shareId;
  final String? objectKey;
  final String fileName;
  final int fileSize;
  final String? mimeType;
  final String vaultUrl;
  final String ownerUserId;
  final String? targetId;
  final String shareType;
  final DateTime? expiresAt;
  final int downloadCount;
  final bool isRevoked;
  final DateTime createdAt;

  const VaultShare({
    required this.shareId,
    this.objectKey,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
    required this.vaultUrl,
    required this.ownerUserId,
    this.targetId,
    this.shareType = 'room',
    this.expiresAt,
    this.downloadCount = 0,
    this.isRevoked = false,
    required this.createdAt,
  });

  String get sizeString => fileSize.toDouble().sizeString;

  factory VaultShare.fromJson(Map<String, dynamic> json) => VaultShare(
    shareId: json['share_id'] as String,
    objectKey: json['object_key'] as String?,
    fileName: json['file_name'] as String,
    fileSize: json['file_size'] as int? ?? 0,
    mimeType: json['mime_type'] as String?,
    vaultUrl: json['vault_url'] as String,
    ownerUserId: json['owner_user_id'] as String,
    targetId: json['target_id'] as String?,
    shareType: json['share_type'] as String? ?? 'room',
    expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String)
        : null,
    downloadCount: json['download_count'] as int? ?? 0,
    isRevoked: json['is_revoked'] as bool? ?? false,
    createdAt: DateTime.parse(
      json['created_at'] as String? ?? DateTime.now().toIso8601String(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'share_id': shareId,
    'object_key': objectKey,
    'file_name': fileName,
    'file_size': fileSize,
    'mime_type': mimeType,
    'vault_url': vaultUrl,
    'owner_user_id': ownerUserId,
    'target_id': targetId,
    'share_type': shareType,
    'expires_at': expiresAt?.toIso8601String(),
    'download_count': downloadCount,
    'is_revoked': isRevoked,
    'created_at': createdAt.toIso8601String(),
  };
}
