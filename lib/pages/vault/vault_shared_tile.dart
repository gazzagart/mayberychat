import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';

/// A list tile representing a file shared with the current user by someone else.
class VaultSharedTile extends StatelessWidget {
  final VaultShare share;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const VaultSharedTile({
    required this.share,
    required this.onTap,
    required this.onDownload,
    super.key,
  });

  IconData _icon() {
    final mime = share.mimeType ?? _mimeFromExtension();
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.video_file_outlined;
    if (mime.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.contains('zip') ||
        mime.contains('archive') ||
        mime.contains('x-tar'))
      return Icons.folder_zip_outlined;
    if (mime.contains('word') || mime.contains('document')) {
      return Icons.description_outlined;
    }
    if (mime.contains('sheet') || mime.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _mimeFromExtension() {
    final ext = share.fileName.contains('.')
        ? share.fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image/';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return 'video/';
      case 'mp3':
      case 'm4a':
      case 'wav':
      case 'ogg':
        return 'audio/';
      case 'pdf':
        return 'application/pdf';
      case 'zip':
      case 'tar':
      case 'gz':
        return 'application/zip';
    }
    return '';
  }

  Color _avatarColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mime = share.mimeType ?? _mimeFromExtension();
    if (mime.startsWith('image/')) {
      return isDark ? Colors.blue.shade900 : Colors.blue.shade100;
    }
    if (mime.startsWith('video/')) {
      return isDark ? Colors.purple.shade900 : Colors.purple.shade100;
    }
    if (mime.startsWith('audio/')) {
      return isDark ? Colors.green.shade900 : Colors.green.shade100;
    }
    if (mime.contains('pdf')) {
      return isDark ? Colors.red.shade900 : Colors.red.shade100;
    }
    if (mime.contains('zip') || mime.contains('archive')) {
      return isDark ? Colors.amber.shade900 : Colors.amber.shade100;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _iconColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mime = share.mimeType ?? _mimeFromExtension();
    if (mime.startsWith('image/')) {
      return isDark ? Colors.blue.shade200 : Colors.blue.shade700;
    }
    if (mime.startsWith('video/')) {
      return isDark ? Colors.purple.shade200 : Colors.purple.shade700;
    }
    if (mime.startsWith('audio/')) {
      return isDark ? Colors.green.shade200 : Colors.green.shade700;
    }
    if (mime.contains('pdf')) {
      return isDark ? Colors.red.shade200 : Colors.red.shade700;
    }
    if (mime.contains('zip') || mime.contains('archive')) {
      return isDark ? Colors.amber.shade200 : Colors.amber.shade700;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String get _ownerName {
    final id = share.ownerUserId;
    if (id.startsWith('@') && id.contains(':')) {
      return id.substring(1, id.indexOf(':'));
    }
    return id;
  }

  String get _expiryLabel {
    if (share.expiresAt == null) return '';
    final d = share.expiresAt!;
    return 'Expires ${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _avatarColor(context),
        child: Icon(_icon(), color: _iconColor(context)),
      ),
      title: Text(share.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          'From $_ownerName',
          share.sizeString,
          if (share.expiresAt != null) _expiryLabel,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Download',
        onPressed: onDownload,
      ),
    );
  }
}
