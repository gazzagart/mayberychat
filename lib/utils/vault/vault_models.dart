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

  const VaultQuota({
    required this.usedBytes,
    required this.totalBytes,
    this.tier = 'free',
  });

  double get usagePercent =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get usedString => usedBytes.toDouble().sizeString;

  String get totalString => totalBytes.toDouble().sizeString;

  factory VaultQuota.fromJson(Map<String, dynamic> json) => VaultQuota(
    usedBytes: json['used_bytes'] as int? ?? 0,
    totalBytes: json['total_bytes'] as int? ?? 524288000,
    tier: json['tier'] as String? ?? 'free',
  );

  factory VaultQuota.empty() =>
      const VaultQuota(usedBytes: 0, totalBytes: 524288000);
}

class VaultShare {
  final String shareId;
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
