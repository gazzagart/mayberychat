import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:fluffychat/config/vault_config.dart';
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

    // Pre-read all files to calculate total bytes for overall progress
    final allBytes = <Uint8List>[];
    var totalBytesAll = 0;
    for (final file in widget.files) {
      final bytes = await file.readAsBytes();
      allBytes.add(bytes);
      totalBytesAll += bytes.length;
    }
    var bytesSentAll = 0;

    try {
      for (var i = 0; i < total; i++) {
        final file = widget.files[i];
        final bytes = allBytes[i];

        if (bytes.length > VaultConfig.maxUploadSizeBytes) {
          throw VaultApiException(
            '${file.name} is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
            'Maximum upload size is ${VaultConfig.maxUploadSizeBytes ~/ 1024 ~/ 1024} MB.',
            413,
          );
        }

        final mimeType = file.mimeType ?? lookupMimeType(file.path);

        setState(() {
          _status = total == 1
              ? 'Uploading ${file.name}...'
              : 'Uploading ${i + 1} of $total: ${file.name}';
        });

        final uploadUrl = await api.getUploadUrl(
          path: widget.currentPath,
          fileName: file.name,
          fileSize: bytes.length,
          mimeType: mimeType,
        );

        // Upload with byte-level progress tracking
        final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
        request.contentLength = bytes.length;
        if (mimeType != null) {
          request.headers['Content-Type'] = mimeType;
        }

        // Feed bytes in chunks and update progress
        final fileBytes = bytes.length;
        var fileSent = 0;
        const chunkSize = 65536; // 64 KB

        () async {
          for (var offset = 0; offset < fileBytes; offset += chunkSize) {
            final end = (offset + chunkSize < fileBytes)
                ? offset + chunkSize
                : fileBytes;
            request.sink.add(Uint8List.sublistView(bytes, offset, end));
            fileSent = end;
            if (mounted) {
              setState(
                () => _progress = (bytesSentAll + fileSent) / totalBytesAll,
              );
            }
          }
          await request.sink.close();
        }();

        final streamedResponse = await request.send();
        final statusCode = streamedResponse.statusCode;
        if (statusCode < 200 || statusCode >= 300) {
          throw VaultApiException(
            'Upload failed: ${streamedResponse.reasonPhrase}',
            statusCode,
          );
        }

        bytesSentAll += bytes.length;
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
        _status = e is VaultApiException
            ? e.friendlyMessage
            : e.toLocalizedString(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog.adaptive(
      title: Text(_uploading ? 'Uploading to Vault' : 'Upload Failed'),
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _uploading ? null : theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        if (!_uploading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
