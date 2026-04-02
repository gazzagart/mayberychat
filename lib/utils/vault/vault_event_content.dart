import 'package:fluffychat/config/vault_config.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:matrix/matrix.dart';

/// Helpers for creating and reading vault file share events.
///
/// Events are sent as standard `m.room.message` with
/// `msgtype: "com.letsyak.vault_file"` so other Matrix clients render
/// the body text as a fallback with the share URL.
class VaultEventContent {
  static const String msgtype = VaultConfig.vaultMsgtype;

  /// Build the content map for a vault file share event.
  static Map<String, dynamic> build({
    required VaultShare share,
    String? thumbnailMxc,
  }) {
    return {
      'body':
          '\u{1F4CE} ${share.fileName} (${share.sizeString}) \u{2014} ${share.vaultUrl}',
      'msgtype': msgtype,
      'share_id': share.shareId,
      'file_name': share.fileName,
      'file_size': share.fileSize,
      'mime_type': share.mimeType,
      'vault_url': share.vaultUrl,
      if (thumbnailMxc != null) 'thumbnail_mxc': thumbnailMxc,
      'owner': share.ownerUserId,
    };
  }

  /// Check whether a Matrix event is a vault file share.
  static bool isVaultFile(Event event) =>
      event.type == EventTypes.Message && event.content['msgtype'] == msgtype;

  /// Extract the share ID from a vault file event.
  static String? shareId(Event event) => event.content['share_id'] as String?;

  /// Extract the human-readable file name.
  static String fileName(Event event) =>
      event.content['file_name'] as String? ?? event.body;

  /// Extract file size in bytes.
  static int fileSize(Event event) => event.content['file_size'] as int? ?? 0;

  /// Formatted size string (e.g. "2.4 MB").
  static String fileSizeString(Event event) =>
      fileSize(event).toDouble().sizeString;

  /// Extract MIME type if present.
  static String? mimeType(Event event) => event.content['mime_type'] as String?;

  /// Extract the vault share URL.
  static String? vaultUrl(Event event) => event.content['vault_url'] as String?;

  /// Extract the owner's Matrix user ID.
  static String? owner(Event event) => event.content['owner'] as String?;

  /// Extract file extension from the file name.
  static String fileExtension(Event event) {
    final name = fileName(event);
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toUpperCase();
  }
}
