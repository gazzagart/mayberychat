import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';

/// Dialog for configuring share settings before sharing a vault file.
class VaultShareDialog extends StatefulWidget {
  final VaultFile file;
  final String? roomId;

  const VaultShareDialog({required this.file, this.roomId, super.key});

  @override
  State<VaultShareDialog> createState() => _VaultShareDialogState();
}

class _VaultShareDialogState extends State<VaultShareDialog> {
  bool _hasExpiry = false;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  bool _hasPassword = false;
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createShare() async {
    setState(() => _loading = true);
    try {
      final client = Matrix.of(context).client;
      final api = VaultApi(matrixClient: client);
      final share = await api.createShare(
        objectKey: widget.file.path,
        fileName: widget.file.name,
        fileSize: widget.file.size,
        mimeType: widget.file.mimeType,
        targetId: widget.roomId,
        shareType: widget.roomId != null ? 'room' : 'link',
        password: _hasPassword ? _passwordController.text : null,
        expiresAt: _hasExpiry ? _expiryDate : null,
      );
      if (mounted) {
        Navigator.of(context).pop(share);
      }
    } on VaultApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use AlertDialog (not .adaptive) so the content always has a Material
    // ancestor — required by ListTile and SwitchListTile.
    return AlertDialog(
      title: const Text('Share File'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(
                widget.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(widget.file.sizeString),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set expiry'),
              subtitle: _hasExpiry
                  ? Text(
                      'Expires ${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
                    )
                  : null,
              value: _hasExpiry,
              onChanged: (v) {
                setState(() => _hasExpiry = v);
                if (v) _pickExpiry();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Password protect'),
              value: _hasPassword,
              onChanged: (v) => setState(() => _hasPassword = v),
            ),
            if (_hasPassword)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _createShare,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Share'),
        ),
      ],
    );
  }
}
