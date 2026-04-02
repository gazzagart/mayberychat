import 'package:cross_file/cross_file.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

/// Dialog that uploads one or more files to the user's vault.
class VaultUploadDialog extends StatefulWidget {
  final List<XFile> files;
  final String currentPath;
  final VoidCallback onComplete;

  const VaultUploadDialog({
    required this.files,
    required this.currentPath,
    required this.onComplete,
    super.key,
  });

  @override
  State<VaultUploadDialog> createState() => _VaultUploadDialogState();
}

class _VaultUploadDialogState extends State<VaultUploadDialog> {
  double _progress = 0;
  String _status = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  Future<void> _startUpload() async {
    setState(() => _uploading = true);
    final client = Matrix.of(context).client;
    final api = VaultApi(matrixClient: client);
    final total = widget.files.length;

    try {
      for (var i = 0; i < total; i++) {
        final file = widget.files[i];
        final bytes = await file.readAsBytes();
        final mimeType = file.mimeType ?? lookupMimeType(file.path);
        final targetPath = widget.currentPath.endsWith('/')
            ? '${widget.currentPath}${file.name}'
            : '${widget.currentPath}/${file.name}';

        setState(() {
          _status = total == 1
              ? 'Uploading ${file.name}...'
              : 'Uploading ${i + 1} of $total: ${file.name}';
          _progress = i / total;
        });

        final uploadUrl = await api.getUploadUrl(
          path: targetPath,
          fileName: file.name,
          fileSize: bytes.length,
          mimeType: mimeType,
        );

        // Upload directly to MinIO via presigned URL
        final response = await http.put(
          Uri.parse(uploadUrl),
          headers: {if (mimeType != null) 'Content-Type': mimeType},
          body: bytes,
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw VaultApiException(
            'Upload failed: ${response.reasonPhrase}',
            response.statusCode,
          );
        }
      }

      setState(() {
        _progress = 1.0;
        _status = 'Upload complete';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog.adaptive(
      title: const Text('Uploading to Vault'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_uploading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
            ],
            Text(
              _status,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
