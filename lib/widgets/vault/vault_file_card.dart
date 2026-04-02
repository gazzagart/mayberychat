import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/utils/vault/vault_event_content.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// A chat bubble widget that renders a shared vault file.
///
/// Displays the file name, size, type, and a download button.
/// Tapping downloads the file via a presigned URL from the Vault API.
class VaultFileCard extends StatelessWidget {
  final Event event;
  final Color textColor;
  final Color linkColor;

  const VaultFileCard({
    required this.event,
    required this.textColor,
    required this.linkColor,
    super.key,
  });

  IconData _iconForMime(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.video_file_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('zip') || mimeType.contains('archive')) {
      return Icons.folder_zip_outlined;
    }
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _download(BuildContext context) async {
    final shareId = VaultEventContent.shareId(event);
    if (shareId == null) {
      final url = VaultEventContent.vaultUrl(event);
      if (url != null) {
        UrlLauncher(context, url).launchUrl();
      }
      return;
    }

    try {
      final client = Matrix.of(context).client;
      final api = VaultApi(matrixClient: client);
      final downloadUrl = await api.getShareDownloadUrl(shareId: shareId);
      if (!context.mounted) return;
      UrlLauncher(context, downloadUrl).launchUrl();
    } on VaultApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = VaultEventContent.fileName(event);
    final sizeString = VaultEventContent.fileSizeString(event);
    final ext = VaultEventContent.fileExtension(event);
    final mimeType = VaultEventContent.mimeType(event);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
        onTap: () => _download(context),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: textColor.withAlpha(32),
                child: Icon(_iconForMime(mimeType), color: textColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$sizeString${ext.isNotEmpty ? ' | $ext' : ''} | Vault',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withAlpha(178),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.cloud_download_outlined,
                color: textColor.withAlpha(178),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
