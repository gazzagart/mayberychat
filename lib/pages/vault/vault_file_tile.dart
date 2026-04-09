import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';

/// A list tile representing a file or folder in the vault browser.
class VaultFileTile extends StatelessWidget {
  final VaultFile file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const VaultFileTile({
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  // Returns the effective MIME category from the stored type or the extension.
  String _mimeCategory() {
    final mime = file.mimeType ?? '';
    if (mime.isNotEmpty) {
      if (mime.startsWith('image/')) return 'image';
      if (mime.startsWith('video/')) return 'video';
      if (mime.startsWith('audio/')) return 'audio';
      if (mime.contains('pdf')) return 'pdf';
      if (mime.contains('zip') ||
          mime.contains('archive') ||
          mime.contains('x-tar') ||
          mime.contains('gzip'))
        return 'archive';
      if (mime.contains('word') || mime.contains('document')) return 'document';
      if (mime.contains('sheet') || mime.contains('excel')) return 'sheet';
      if (mime.contains('presentation') || mime.contains('powerpoint')) {
        return 'presentation';
      }
    }
    // Fall back to extension when mime_type is absent.
    switch (file.extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
      case 'm4v':
        return 'video';
      case 'mp3':
      case 'm4a':
      case 'ogg':
      case 'wav':
      case 'flac':
      case 'aac':
        return 'audio';
      case 'pdf':
        return 'pdf';
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return 'archive';
      case 'doc':
      case 'docx':
        return 'document';
      case 'xls':
      case 'xlsx':
        return 'sheet';
      case 'ppt':
      case 'pptx':
        return 'presentation';
    }
    return 'other';
  }

  IconData _icon() {
    if (file.isFolder) return Icons.folder_outlined;
    switch (_mimeCategory()) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.video_file_outlined;
      case 'audio':
        return Icons.audio_file_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'archive':
        return Icons.folder_zip_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'sheet':
        return Icons.table_chart_outlined;
      case 'presentation':
        return Icons.slideshow_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _avatarColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    if (file.isFolder) return Theme.of(context).colorScheme.primaryContainer;
    switch (_mimeCategory()) {
      case 'image':
        return isDark ? Colors.blue.shade900 : Colors.blue.shade100;
      case 'video':
        return isDark ? Colors.purple.shade900 : Colors.purple.shade100;
      case 'audio':
        return isDark ? Colors.green.shade900 : Colors.green.shade100;
      case 'pdf':
        return isDark ? Colors.red.shade900 : Colors.red.shade100;
      case 'archive':
        return isDark ? Colors.amber.shade900 : Colors.amber.shade100;
      case 'document':
        return isDark ? Colors.indigo.shade900 : Colors.indigo.shade100;
      case 'sheet':
        return isDark ? Colors.teal.shade900 : Colors.teal.shade100;
      case 'presentation':
        return isDark ? Colors.orange.shade900 : Colors.orange.shade100;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  Color _iconColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    if (file.isFolder) {
      return Theme.of(context).colorScheme.onPrimaryContainer;
    }
    switch (_mimeCategory()) {
      case 'image':
        return isDark ? Colors.blue.shade200 : Colors.blue.shade700;
      case 'video':
        return isDark ? Colors.purple.shade200 : Colors.purple.shade700;
      case 'audio':
        return isDark ? Colors.green.shade200 : Colors.green.shade700;
      case 'pdf':
        return isDark ? Colors.red.shade200 : Colors.red.shade700;
      case 'archive':
        return isDark ? Colors.amber.shade200 : Colors.amber.shade700;
      case 'document':
        return isDark ? Colors.indigo.shade200 : Colors.indigo.shade700;
      case 'sheet':
        return isDark ? Colors.teal.shade200 : Colors.teal.shade700;
      case 'presentation':
        return isDark ? Colors.orange.shade200 : Colors.orange.shade700;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
      leading: selected
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.check, color: theme.colorScheme.onPrimary),
            )
          : CircleAvatar(
              backgroundColor: _avatarColor(context),
              child: Icon(_icon(), color: _iconColor(context)),
            ),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        file.isFolder
            ? file.lastModified.localizedTime(context)
            : '${file.sizeString} \u00B7 ${file.lastModified.localizedTime(context)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
