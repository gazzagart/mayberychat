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

  IconData _icon() {
    if (file.isFolder) return Icons.folder_outlined;
    final mime = file.mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.video_file_outlined;
    if (mime.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.contains('zip') || mime.contains('archive')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: file.isFolder
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          _icon(),
          color: file.isFolder
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
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
